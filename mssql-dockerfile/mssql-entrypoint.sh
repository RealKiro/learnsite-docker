#!/bin/bash
set -e

# 将所有输出重定向到控制台（便于 Docker 日志捕获）
exec > /proc/1/fd/1 2>&1

# ========== 创建 /.system 目录以解决权限问题 ==========
if [ ! -d "/.system" ]; then
    echo "Creating /.system directory..."
    mkdir -p /.system
fi

# ========== 环境变量默认值（可通过 docker-compose 覆盖）==========
: "${BRANCH:=master}"
: "${PRIMARY_REPO_URL:=https://gitee.com/nylon26/openlearnsite/raw}"
: "${FALLBACK_REPO_URL:=}"

INIT_MARKER="/var/opt/mssql/db_initialized"
SQL_DIR="/tmp/sql"
SQLCMD="/opt/mssql-tools/bin/sqlcmd"

# ========== 启动 SQL Server（以 root 运行）==========
echo "🚀 Starting SQL Server..."
/opt/mssql/bin/sqlservr &
SQL_PID=$!

# ========== 等待 SQL Server 完全启动 ==========
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

# ========== 首次运行时初始化数据库 ==========
if [ ! -f "$INIT_MARKER" ]; then
    echo "🔍 First run detected. Preparing SQL scripts..."

    # 创建SQL目录
    mkdir -p "$SQL_DIR"
    
    # 下载整个sql目录作为zip文件
    echo "📥 Downloading SQL directory..."
    PRIMARY_ZIP_URL="$PRIMARY_REPO_URL/$BRANCH/sql.zip"
    
    if curl -f -sSL -o "$SQL_DIR/sql.zip" "$PRIMARY_ZIP_URL" 2>/dev/null; then
        echo "✅ Downloaded SQL directory from primary URL."
    else
        echo "⚠️ Primary download failed."
        if [ -n "${FALLBACK_REPO_URL}" ] && [ "${FALLBACK_REPO_URL}" != "" ]; then
            FALLBACK_ZIP_URL="$FALLBACK_REPO_URL/$BRANCH/sql.zip"
            echo "Trying fallback URL for SQL directory..."
            if curl -f -sSL -o "$SQL_DIR/sql.zip" "$FALLBACK_ZIP_URL"; then
                echo "✅ Downloaded SQL directory from fallback URL."
            else
                echo "⚠️ Failed to download SQL directory as zip, trying alternative method..."
                
                # 备选方案：尝试直接下载learnsite.sql
                echo "📥 Downloading learnsite.sql..."
                PRIMARY_SQL_URL="$PRIMARY_REPO_URL/$BRANCH/sql/learnsite.sql"
                FALLBACK_SQL_URL="$FALLBACK_REPO_URL/$BRANCH/sql/learnsite.sql"
                
                if curl -f -sSL -o "$SQL_DIR/learnsite.sql" "$PRIMARY_SQL_URL" 2>/dev/null; then
                    echo "✅ Downloaded learnsite.sql from primary URL."
                else
                    echo "⚠️ Primary download failed, trying fallback URL for learnsite.sql"
                    if curl -f -sSL -o "$SQL_DIR/learnsite.sql" "$FALLBACK_SQL_URL"; then
                        echo "✅ Downloaded learnsite.sql from fallback URL."
                    else
                        echo "❌ Failed to download any SQL scripts."
                        exit 1
                    fi
                fi
            fi
        else
            echo "⚠️ Fallback repository is not configured. Trying alternative method..."
            
            # 备选方案：尝试直接下载learnsite.sql
            echo "📥 Downloading learnsite.sql..."
            PRIMARY_SQL_URL="$PRIMARY_REPO_URL/$BRANCH/sql/learnsite.sql"
            
            if curl -f -sSL -o "$SQL_DIR/learnsite.sql" "$PRIMARY_SQL_URL" 2>/dev/null; then
                echo "✅ Downloaded learnsite.sql from primary URL."
            else
                echo "❌ Failed to download learnsite.sql. Please check your repository URL configuration."
                exit 1
            fi
        fi
    fi
    
    # 解压zip文件（如果存在）
    if [ -f "$SQL_DIR/sql.zip" ]; then
        echo "📦 Extracting SQL scripts..."
        unzip -q "$SQL_DIR/sql.zip" -d "$SQL_DIR"
        rm -f "$SQL_DIR/sql.zip"
    fi
    
    # 获取所有SQL脚本文件（按文件名排序）
    SQL_SCRIPTS=($(find "$SQL_DIR" -name "*.sql" | sort))
    
    # 如果没有找到SQL脚本，检查是否有learnsite.sql
    if [ ${#SQL_SCRIPTS[@]} -eq 0 ]; then
        if [ -f "$SQL_DIR/learnsite.sql" ]; then
            SQL_SCRIPTS=($SQL_DIR/learnsite.sql)
        else
            echo "❌ No SQL scripts found."
            exit 1
        fi
    fi
    
    echo "📋 Found ${#SQL_SCRIPTS[@]} SQL scripts to execute:"
    for script in "${SQL_SCRIPTS[@]}"; do
        echo "- $(basename "$script")"
    done

    # 确保 learnsite 数据库存在
    echo "📦 Ensuring database 'learnsite' exists..."
    $SQLCMD -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'learnsite') CREATE DATABASE learnsite;"

    # 执行SQL脚本
    echo "⚙️ Running initialization scripts..."
    for script in "${SQL_SCRIPTS[@]}"; do
        script_name=$(basename "$script")
        if [ -f "$script" ]; then
            echo "Executing $script_name..."
            if $SQLCMD -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -d learnsite -i "$script"; then
                echo "✅ $script_name executed successfully."
            else
                echo "⚠️ $script_name execution failed, continuing..."
            fi
        else
            echo "⏭️ $script_name not found, skipping..."
        fi
    done

    # 标记初始化完成
    touch "$INIT_MARKER"
    rm -rf "$SQL_DIR"
    echo "✅ Database initialization completed."
else
    echo "⏭️ Database already initialized. Skipping."
fi

# ========== 保持容器前台运行 ==========
wait $SQL_PID