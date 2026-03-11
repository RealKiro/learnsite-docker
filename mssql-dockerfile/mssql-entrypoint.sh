#!/bin/bash
set -e

# 将所有输出重定向到控制台（便于 Docker 日志捕获）
exec > /proc/1/fd/1 2>&1

# ========== 新增：切换到持久化数据目录 ==========
# 确保工作目录为 /var/opt/mssql，避免在根目录创建 .system 等临时文件
cd /var/opt/mssql || exit 1
# ===============================================

# ========== 环境变量默认值（可通过 docker-compose 覆盖）==========
: "${PRIMARY_SQL_URL:=https://raw.githubusercontent.com/RealKiro/learnsite/refs/heads/main/sql/learnsite.sql}"
: "${FALLBACK_SQL_URL:=https://gitee.com/realiy/learnsite/raw/main/sql/learnsite.sql}"

INIT_MARKER="/var/opt/mssql/db_initialized"          # 标记文件，防止重复初始化
SQL_SCRIPT="/tmp/learnsite.sql"                       # 临时 SQL 文件路径
SQLCMD="/opt/mssql-tools/bin/sqlcmd"                   # Azure SQL Edge 的 sqlcmd 路径

echo "🚀 Starting SQL Server..."
/opt/mssql/bin/sqlservr &
SQL_PID=$!

# 等待 SQL Server 完全启动（最多 60 秒）
echo "⏳ Waiting for SQL Server to be ready..."
for i in {1..60}; do
    if $SQLCMD -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1; then
        echo "✅ SQL Server is ready."
        break
    fi
    echo "Attempt $i: Not ready yet..."
    sleep 1
    if [ $i -eq 60 ]; then
        echo "❌ SQL Server did not start in time."
        exit 1
    fi
done

# 首次运行时初始化数据库
if [ ! -f "$INIT_MARKER" ]; then
    echo "🔍 First run detected. Downloading learnsite.sql..."

    # 尝试从主地址下载
    echo "Trying primary URL: $PRIMARY_SQL_URL"
    if curl -f -sSL -o "$SQL_SCRIPT" "$PRIMARY_SQL_URL" 2>/dev/null; then
        echo "✅ Downloaded from primary URL."
    else
        echo "⚠️ Primary download failed, trying fallback URL: $FALLBACK_SQL_URL"
        if curl -f -sSL -o "$SQL_SCRIPT" "$FALLBACK_SQL_URL"; then
            echo "✅ Downloaded from fallback URL."
        else
            echo "❌ Failed to download learnsite.sql from both URLs."
            exit 1
        fi
    fi

    # 确保 learnsite 数据库存在（如果脚本中未包含创建语句）
    echo "📦 Ensuring database 'learnsite' exists..."
    $SQLCMD -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'learnsite') CREATE DATABASE learnsite;"

    # 执行初始化脚本
    echo "⚙️ Running initialization script..."
    if $SQLCMD -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -d learnsite -i "$SQL_SCRIPT"; then
        touch "$INIT_MARKER"
        rm -f "$SQL_SCRIPT"
        echo "✅ Database initialized."
    else
        echo "❌ Database initialization failed."
        exit 1
    fi
else
    echo "⏭️ Database already initialized. Skipping."
fi

# 保持容器前台运行，等待 SQL Server 进程结束
wait $SQL_PID