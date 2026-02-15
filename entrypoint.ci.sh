#!/bin/bash
set -e

# ========== 配置区域 ==========
INIT_MARKER="/var/opt/mssql/db_initialized"          # 标记文件，用于判断是否已初始化
SQL_URL="https://raw.githubusercontent.com/RealKiro/learnsite/refs/heads/main/sql/learnsite.sql"  # SQL 文件下载地址
SQL_SCRIPT="/tmp/learnsite.sql"                       # 临时存放路径
# ==============================

# 启动 SQL Server 后台进程
echo "🚀 Starting SQL Server in background..."
/opt/mssql/bin/sqlservr &
SQL_PID=$!

# 等待 SQL Server 完全启动（使用 localhost 连接，密码从环境变量获取）
echo "⏳ Waiting for SQL Server to be ready..."
for i in {1..60}; do
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1; then
        echo "✅ SQL Server is ready."
        break
    fi
    echo "Attempt $i: Not ready yet..."
    sleep 1
    if [ $i -eq 60 ]; then
        echo "❌ SQL Server did not start in time. Exiting."
        exit 1
    fi
done

# 执行初始化（仅在首次运行时）
if [ ! -f "$INIT_MARKER" ]; then
    echo "🔍 First run detected. Downloading learnsite.sql..."
    # 下载 SQL 文件（优先使用 curl）
    if command -v curl >/dev/null 2>&1; then
        curl -f -sSL -o "$SQL_SCRIPT" "$SQL_URL" || { echo "❌ Download failed"; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$SQL_SCRIPT" "$SQL_URL" || { echo "❌ Download failed"; exit 1; }
    else
        echo "❌ Neither curl nor wget found. Cannot download SQL file."
        exit 1
    fi
    echo "✅ learnsite.sql downloaded."

    # 执行初始化脚本（使用 master 数据库，因为 learnsite 可能还未创建）
    echo "⚙️ Running initialization script..."
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -d master -i "$SQL_SCRIPT"; then
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