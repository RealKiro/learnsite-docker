#!/bin/bash
# LearnSite 一键部署脚本 (Linux/Mac)
# 使用方法: ./deploy.sh 或 ./deploy.sh --reset

set -e

# 配置变量
DB_PASSWORD="LearnSite!2025StrongPwd"
DB_NAME="learnsite"
CONTAINER_DB="learnsite2025-9-19-db-1"
CONTAINER_WEB="learnsite2025-9-19-web-1"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
RESET=false

# 解析参数
if [ "$1" == "--reset" ] || [ "$1" == "-r" ] || [ "$1" == "reset" ]; then
    RESET=true
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}    LearnSite 一键部署脚本${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 函数：执行SQL命令
run_sql() {
    local query=$1
    local db=${2:-master}
    docker exec $CONTAINER_DB $SQLCMD -S localhost -U sa -P "$DB_PASSWORD" -C -d "$db" -Q "$query" 2>/dev/null
}

# 函数：等待SQL Server就绪
wait_for_sql() {
    echo -e "${YELLOW}[2/5] 等待 SQL Server 启动...${NC}"
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        if docker exec $CONTAINER_DB $SQLCMD -S localhost -U sa -P "$DB_PASSWORD" -C -Q "SELECT 1" &>/dev/null; then
            echo -e "${GREEN}      SQL Server 已就绪!${NC}"
            return 0
        fi
        echo -e "${GRAY}      等待中... ($attempt/$max_attempts)${NC}"
        sleep 2
    done
    
    echo -e "${RED}      SQL Server 启动超时!${NC}"
    return 1
}

# 步骤1: 启动 Docker Compose
echo -e "${YELLOW}[1/5] 启动 Docker 容器...${NC}"

if [ "$RESET" = true ]; then
    echo -e "${MAGENTA}      重置模式: 停止并删除现有容器...${NC}"
    docker-compose down -v 2>/dev/null || true
fi

docker-compose up -d
echo -e "${GREEN}      Docker 容器已启动!${NC}"

# 步骤2: 等待SQL Server就绪
wait_for_sql || exit 1

# 步骤3: 检查并创建数据库
echo -e "${YELLOW}[3/5] 检查数据库...${NC}"

db_exists=$(run_sql "SELECT COUNT(*) FROM sys.databases WHERE name = '$DB_NAME'" | grep -o '[0-9]' | head -1)

if [ "$db_exists" = "1" ] && [ "$RESET" = false ]; then
    echo -e "${GREEN}      数据库 '$DB_NAME' 已存在，跳过创建${NC}"
else
    echo -e "${YELLOW}      正在创建数据库 '$DB_NAME'...${NC}"
    
    # 如果数据库存在则先删除
    if [ "$db_exists" = "1" ]; then
        run_sql "ALTER DATABASE $DB_NAME SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE $DB_NAME;" >/dev/null
    fi
    
    # 创建新数据库
    run_sql "CREATE DATABASE $DB_NAME;" >/dev/null
    echo -e "${GREEN}      数据库创建成功!${NC}"
fi

# 步骤4: 导入数据库脚本
echo -e "${YELLOW}[4/5] 导入数据库脚本...${NC}"

table_count=$(run_sql "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'" "$DB_NAME" | grep -o '[0-9]\+' | head -1)

if [ "$table_count" = "54" ] && [ "$RESET" = false ]; then
    echo -e "${GREEN}      数据表已完整 (54个表)，跳过导入${NC}"
else
    echo -e "${YELLOW}      正在导入 learnsite.sql ...${NC}"
    docker exec $CONTAINER_DB $SQLCMD -S localhost -U sa -P "$DB_PASSWORD" -C -d "$DB_NAME" -i /sql_scripts/learnsite.sql >/dev/null 2>&1
    
    # 验证导入结果
    table_count=$(run_sql "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'" "$DB_NAME" | grep -o '[0-9]\+' | head -1)
    echo -e "${GREEN}      导入完成! 共创建 ${table_count} 个数据表${NC}"
fi

# 步骤5: 验证部署
echo -e "${YELLOW}[5/5] 验证部署...${NC}"

web_status=$(docker inspect -f '{{.State.Status}}' $CONTAINER_WEB 2>/dev/null || echo "unknown")
if [ "$web_status" = "running" ]; then
    echo -e "${GREEN}      Web 服务运行正常!${NC}"
else
    echo -e "${RED}      Web 服务状态: $web_status${NC}"
fi

if run_sql "SELECT 1" "$DB_NAME" | grep -q "1"; then
    echo -e "${GREEN}      数据库连接正常!${NC}"
else
    echo -e "${RED}      数据库连接失败!${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}    部署完成!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "访问地址: ${CYAN}http://localhost:8888${NC}"
echo ""
echo -e "${GRAY}常用命令:${NC}"
echo -e "${GRAY}  查看日志:     docker-compose logs -f${NC}"
echo -e "${GRAY}  停止服务:     docker-compose down${NC}"
echo -e "${GRAY}  重启服务:     docker-compose restart${NC}"
echo -e "${GRAY}  重置部署:     ./deploy.sh --reset${NC}"
echo ""
