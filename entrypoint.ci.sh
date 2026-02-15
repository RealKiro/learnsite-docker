#!/bin/bash
set -e

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
    if command -v curl >/dev/null 2>&1; then
        curl -f -sSL -o "$SQL_SCRIPT" "$SQL_URL" || { echo "❌ Download failed (curl)"; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$SQL_SCRIPT" "$SQL_URL" || { echo "❌ Download failed (wget)"; exit 1; }
    else
        echo "❌ Neither curl nor wget found. Cannot download SQL file."
        exit 1
    fi
    echo "✅ learnsite.sql downloaded."

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