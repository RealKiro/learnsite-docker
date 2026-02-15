#!/bin/bash
set -e

# 将所有输出重定向到控制台（便于 Docker 日志捕获）
exec > /proc/1/fd/1 2>&1

INIT_MARKER="/var/opt/mssql/db_initialized"
SQL_URL="https://raw.githubusercontent.com/RealKiro/learnsite/refs/heads/main/sql/learnsite.sql"
SQL_SCRIPT="/tmp/learnsite.sql"

echo "🚀 Starting SQL Server..."
/opt/mssql/bin/sqlservr &
SQL_PID=$!

echo "⏳ Waiting for SQL Server to be ready..."
for i in {1..60}; do
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" > /dev/null 2>&1; then
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

if [ ! -f "$INIT_MARKER" ]; then
    echo "🔍 First run detected. Downloading learnsite.sql..."
    curl -f -sSL -o "$SQL_SCRIPT" "$SQL_URL" || { echo "❌ Download failed"; exit 1; }
    echo "✅ learnsite.sql downloaded."

    # 确保数据库存在
    echo "📦 Ensuring database 'learnsite' exists..."
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'learnsite') CREATE DATABASE learnsite;"

    echo "⚙️ Running initialization script..."
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -d learnsite -i "$SQL_SCRIPT"; then
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

wait $SQL_PID