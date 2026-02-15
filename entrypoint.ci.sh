#!/bin/bash
set -e

# ========== 配置区域 ==========
INIT_MARKER="/var/opt/mssql/.initialized"          # 初始化标记文件
SQL_SCRIPT="/tmp/learnsite.sql"                    # 下载的 SQL 脚本临时存放路径
SQL_URL="https://raw.githubusercontent.com/RealKiro/learnsite/refs/heads/main/sql/learnsite.sql"
MSSQL_SA_PASSWORD=${MSSQL_SA_PASSWORD}             # 从环境变量获取密码
# ==============================

# 启动 SQL Server 后台进程
echo "🚀 Starting SQL Server in background..."
/opt/mssql/bin/sqlservr &
SQL_PID=$!

# 等待 SQL Server 完全启动（循环测试连接）
echo "⏳ Waiting for SQL Server to be ready..."
RETRIES=30
while ! /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1; do
    RETRIES=$((RETRIES - 1))
    if [ $RETRIES -le 0 ]; then
        echo "❌ SQL Server did not start in time. Exiting."
        exit 1
    fi
    sleep 2
done
echo "✅ SQL Server is ready."

# 如果尚未初始化，执行初始化流程
if [ ! -f "$INIT_MARKER" ]; then
    echo "🔍 First run detected. Downloading learnsite.sql..."

    # 下载 SQL 文件
    if command -v curl >/dev/null 2>&1; then
        curl -f -sSL -o "$SQL_SCRIPT" "$SQL_URL" || { echo "❌ Download failed"; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$SQL_SCRIPT" "$SQL_URL" || { echo "❌ Download failed"; exit 1; }
    else
        echo "❌ Neither curl nor wget found. Cannot download SQL file."
        exit 1
    fi
    echo "✅ learnsite.sql downloaded."

    # 确保 learnsite 数据库存在（如果脚本中未包含创建数据库语句）
    echo "📦 Ensuring database 'learnsite' exists..."
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" \
        -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'learnsite') CREATE DATABASE learnsite;"

    # 执行初始化脚本
    echo "⚙️ Running initialization script..."
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d learnsite -i "$SQL_SCRIPT"; then
        touch "$INIT_MARKER"
        rm -f "$SQL_SCRIPT"   # 清理下载的临时文件
        echo "✅ Database initialization completed."
    else
        echo "❌ Database initialization failed."
        exit 1
    fi
else
    echo "⏭️ Database already initialized. Skipping."
fi

# 将控制权交还给 SQL Server 前台进程（保持容器运行）
echo "🔄 SQL Server is now running. Handing over control..."
wait $SQL_PID