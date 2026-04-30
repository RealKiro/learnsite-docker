#!/bin/bash

# LearnSite 一键部署脚本
# 适用于 Linux 环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 函数：检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_info "需要root权限，正在请求sudo..."
        if [ -n "$SUDO_USER" ]; then
            print_warning "检测到已使用sudo执行，但可能未正确切换到root环境"
            print_info "请输入密码以获取root权限："
            sudo "$0" "$@"
            exit $?
        else
            print_info "请输入密码以获取root权限："
            exec sudo "$0" "$@"
        fi
    fi
    print_success "已获取root权限"
}

# 函数：创建目录结构
create_directories() {
    local target_dir="/docker/learnsite"
    
    if [ -d "$target_dir" ]; then
        print_warning "目录 $target_dir 已存在，跳过创建"
    else
        print_info "正在创建目录 $target_dir..."
        mkdir -p "$target_dir/app" "$target_dir/data"
        print_success "目录创建完成"
    fi
    
    cd "$target_dir"
    print_success "已切换到目录 $target_dir"
}

# 函数：下载docker-compose.yml
download_compose_file() {
    local compose_file="docker-compose.yml"
    local gitee_url="https://gitee.com/realiy/learnsite-docker/raw/main/docker-compose.yml"
    
    if [ -f "$compose_file" ]; then
        print_warning "$compose_file 已存在，跳过下载"
        return 0
    fi
    
    print_info "正在从Gitee下载 $compose_file..."
    
    if command -v curl &> /dev/null; then
        curl -L -o "$compose_file" "$gitee_url"
    elif command -v wget &> /dev/null; then
        wget -O "$compose_file" "$gitee_url"
    else
        print_error "未找到curl或wget，请先安装其中一个工具"
        exit 1
    fi
    
    if [ -f "$compose_file" ]; then
        print_success "$compose_file 下载完成"
    else
        print_error "$compose_file 下载失败"
        exit 1
    fi
}

# 函数：获取用户输入密码
get_password() {
    local default_password="YourStrong@Passw0rd123"
    
    echo
    print_info "请配置数据库密码（环境变量DB_PASSWORD和MSSQL_SA_PASSWORD使用相同密码）"
    echo -n "请输入密码（直接回车使用默认密码 $default_password）："
    read -s user_password
    echo
    
    if [ -z "$user_password" ]; then
        user_password="$default_password"
        print_info "使用默认密码"
    else
        echo -n "请再次输入密码确认："
        read -s confirm_password
        echo
        
        if [ "$user_password" != "$confirm_password" ]; then
            print_error "两次输入的密码不一致，请重新运行脚本"
            exit 1
        fi
    fi
    
    print_success "密码已配置"
}

# 函数：获取端口配置
get_ports() {
    local default_web_port="8080"
    local default_db_port="1433"
    local user_web_port=""
    local user_db_port=""
    
    echo
    print_info "请配置端口映射（直接回车使用默认端口）"
    
    echo -n "Web服务端口（默认 $default_web_port）："
    read user_web_port
    web_port="${user_web_port:-$default_web_port}"
    
    echo -n "数据库端口（默认 $default_db_port）："
    read user_db_port
    db_port="${user_db_port:-$default_db_port}"
    
    print_success "端口配置：Web服务 $web_port，数据库 $db_port"
}

# 函数：修改docker-compose.yml配置
update_compose_config() {
    local compose_file="docker-compose.yml"
    local password="$1"
    local web_port="$2"
    local db_port="$3"
    
    print_info "正在更新配置..."
    
    # 备份原文件
    if [ ! -f "${compose_file}.bak" ]; then
        cp "$compose_file" "${compose_file}.bak"
    fi
    
    # 修改密码
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$password/" "$compose_file"
    sed -i "s/MSSQL_SA_PASSWORD=.*/MSSQL_SA_PASSWORD=$password/" "$compose_file"
    
    # 修改端口
    sed -i "s/- \"8080:8080\"/- \"$web_port:8080\"/" "$compose_file"
    sed -i "s/- \"1433:1433\"/- \"$db_port:1433\"/" "$compose_file"
    
    print_success "配置更新完成"
}

# 函数：部署Docker Compose
deploy_docker() {
    local compose_file="docker-compose.yml"
    
    echo
    print_info "开始部署..."
    
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        print_error "未找到docker compose，请先安装Docker Compose"
        exit 1
    fi
    
    # 停止已运行的容器
    if docker compose -f "$compose_file" ps | grep -q -E 'learnsite|mssql' 2>/dev/null || \
       docker-compose -f "$compose_file" ps | grep -q -E 'learnsite|mssql' 2>/dev/null; then
        print_warning "检测到已运行的容器，正在停止..."
        if command -v docker compose &> /dev/null; then
            docker compose -f "$compose_file" down
        else
            docker-compose -f "$compose_file" down
        fi
    fi
    
    # 启动服务
    if command -v docker compose &> /dev/null; then
        docker compose -f "$compose_file" up -d
    else
        docker-compose -f "$compose_file" up -d
    fi
    
    print_success "部署完成！"
    echo
    print_info "访问地址：http://localhost:$web_port"
    print_info "查看日志：cd /docker/learnsite && docker compose -f docker-compose.yml logs -f"
    print_info "停止服务：cd /docker/learnsite && docker compose -f docker-compose.yml down"
}

# 主函数
main() {
    clear
    echo "=========================================="
    echo "     LearnSite 一键部署脚本"
    echo "=========================================="
    echo
    
    # 步骤1：获取root权限
    check_root "$@"
    
    # 步骤2：创建目录结构
    create_directories
    
    # 步骤3：下载docker-compose.yml
    download_compose_file
    
    # 步骤4：获取密码配置
    get_password
    
    # 步骤5：获取端口配置
    get_ports
    
    # 步骤6：修改配置文件
    update_compose_config "$user_password" "$web_port" "$db_port"
    
    # 步骤7：部署
    deploy_docker
    
    echo
    echo "=========================================="
    print_success "部署脚本执行完成！"
    echo "=========================================="
}

# 执行主函数
main "$@"