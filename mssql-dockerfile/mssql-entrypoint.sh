#!/bin/bash
set -e

# 将所有输出重定向到控制台（便于 Docker 日志捕获）
exec > /proc/1/fd/1 2>&1

# ========== PUID/PGID 权限处理（自动修复宿主机目录权限）==========
# 从环境变量获取 PUID 和 PGID，如果未设置则使用默认值 1000
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "--- 正在设置用户和组，UID:GID = $PUID:$PGID ---"

# 检查组是否存在，若不存在则创建
if ! getent group appgroup > /dev/null 2>&1; then
    groupadd -g $PGID appgroup
else
    # 如果组存在但 GID 不匹配，修改它
    groupmod -g $PGID appgroup 2>/dev/null || true
fi

# 检查用户是否存在，若不存在则创建
if ! getent passwd appuser > /dev/null 2>&1; then
    useradd -u $PUID -g $PGID -m appuser
else
    usermod -u $PUID -g $PGID appuser 2>/dev/null || true
fi

# 关键步骤：将整个数据目录的权限更改为新创建的用户
# 这解决了即使宿主机目录权限不对，容器启动时也能自动修复
echo "--- 调整 /var/opt/mssql 目录的所有权为 $PUID:$PGID ---"
chown -R $PUID:$PGID /var/opt/mssql

# ========== 环境变量默认值（可通过 docker-compose 覆盖）==========
: "${PRIMARY_SQL_URL:=https://raw.githubusercontent.com/RealKiro/learnsite/refs/heads/main/sql/learnsite.sql}"
: "${FALLBACK_SQL_URL:=https://gitee.com/realiy/learnsite/raw/main/sql/learnsite.sql}"

INIT_MARKER="/var/opt/mssql/db_initialized"
SQL_SCRIPT="/tmp/learnsite.sql"
SQLCMD="/opt/mssql-tools/bin/sqlcmd"

# ========== 以 appuser 用户启动 SQL Server（使用 gosu 降权）==========
echo "🚀 以用户 appuser (UID:$PUID) 启动 SQL Server..."
exec gosu appuser /opt/mssql/bin/sqlservr &
SQL_PID=$!

# ========== 等待 SQL Server 完全启动 ==========
echo "⏳ 等待 SQL Server 就绪..."
for i in {1..60}; do
    if $SQLCMD -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1; then
        echo "✅ SQL Server 已就绪."
        break
    fi
    echo "尝试 $i: 尚未就绪..."
    sleep 1
    if [ $i -eq 60 ]; then
        echo "❌ SQL Server 启动超时."
        exit 1
    fi
done

# ========== 首次运行时初始化数据库 ==========
if [ ! -f "$INIT_MARKER" ]; then
    echo "🔍 首次运行，下载 learnsite.sql..."

    # 尝试从主地址下载
    echo "尝试主地址: $PRIMARY_SQL_URL"
    if curl -f -sSL -o "$SQL_SCRIPT" "$PRIMARY_SQL_URL" 2>/dev/null; then
        echo "✅ 从主地址下载成功."
    else
        echo "⚠️ 主地址下载失败，尝试备用地址: $FALLBACK_SQL_URL"
        if curl -f -sSL -o "$SQL_SCRIPT" "$FALLBACK_SQL_URL"; then
            echo "✅ 从备用地址下载成功."
        else
            echo "❌ 所有地址下载失败."
            exit 1
        fi
    fi

    # 确保 learnsite 数据库存在（如果脚本中未包含创建语句）
    echo "📦 确保数据库 'learnsite' 存在..."
    $SQLCMD -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'learnsite') CREATE DATABASE learnsite;"

    # 执行初始化脚本
    echo "⚙️ 执行初始化脚本..."
    if $SQLCMD -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -d learnsite -i "$SQL_SCRIPT"; then
        touch "$INIT_MARKER"
        rm -f "$SQL_SCRIPT"
        echo "✅ 数据库初始化完成."
    else
        echo "❌ 数据库初始化失败."
        exit 1
    fi
else
    echo "⏭️ 数据库已初始化，跳过."
fi

# ========== 保持容器前台运行，等待 SQL Server 进程结束 ==========
wait $SQL_PID