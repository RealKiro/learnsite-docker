#!/bin/bash

# LearnSite 一键部署脚本
# 适用于 Linux 环境
# 
# 使用方式：
#   交互式部署：bash <(curl -L https://gitee.com/realiy/learnsite-docker/raw/main/deploy.sh)
#   快速部署（默认配置）：bash <(curl -L https://gitee.com/realiy/learnsite-docker/raw/main/deploy.sh) --quick
#   自定义部署：bash <(curl -L https://gitee.com/realiy/learnsite-docker/raw/main/deploy.sh) -p <密码> -w <Web端口> -d <数据库端口>
# 
# 参数说明：
#   -q, --quick      快速部署，使用默认配置，无需交互
#   -p, --password   指定数据库密码
#   -w, --web-port   指定Web服务端口（默认：8080）
#   -d, --db-port    指定数据库端口（默认：1433）
#   -h, --help       显示帮助信息

set -e

# 默认配置
DEFAULT_PASSWORD="YourStrong@Passw0rd123"
DEFAULT_WEB_PORT="8080"
DEFAULT_DB_PORT="1433"

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

# 函数：显示帮助信息
show_help() {
    echo "LearnSite 一键部署脚本"
    echo
    echo "用法："
    echo "  $0 [选项]"
    echo
    echo "选项："
    echo "  -q, --quick              快速部署，使用默认配置，无需交互"
    echo "  -p, --password <密码>    指定数据库密码"
    echo "  -w, --web-port <端口>    指定Web服务端口（默认：$DEFAULT_WEB_PORT）"
    echo "  -d, --db-port <端口>     指定数据库端口（默认：$DEFAULT_DB_PORT）"
    echo "  -h, --help               显示此帮助信息"
    echo
    echo "示例："
    echo "  交互式部署：              $0"
    echo "  快速部署：                $0 --quick"
    echo "  自定义密码：              $0 -p MySecret123"
    echo "  自定义端口：              $0 -w 80 -d 1433"
    echo "  完全自定义：              $0 -p MySecret123 -w 80 -d 1433"
    exit 0
}

# 函数：解析命令行参数
parse_args() {
    # 初始化变量
    quick_mode=false
    user_password=""
    web_port=""
    db_port=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -p|--password)
                if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
                    print_error "--password 参数需要一个值"
                    show_help
                fi
                user_password="$2"
                shift 2
                ;;
            -w|--web-port)
                if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
                    print_error "--web-port 参数需要一个值"
                    show_help
                fi
                web_port="$2"
                shift 2
                ;;
            -d|--db-port)
                if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
                    print_error "--db-port 参数需要一个值"
                    show_help
                fi
                db_port="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                ;;
        esac
    done
    
    # 设置默认值
    if [[ -z "$user_password" ]]; then
        user_password="$DEFAULT_PASSWORD"
    fi
    if [[ -z "$web_port" ]]; then
        web_port="$DEFAULT_WEB_PORT"
    fi
    if [[ -z "$db_port" ]]; then
        db_port="$DEFAULT_DB_PORT"
    fi
}

# 函数：检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_info "需要root权限，正在请求sudo..."
        if [ -n "$SUDO_USER" ]; then
            sudo "$0" "$@"
            exit $?
        else
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

# 函数：获取用户输入密码（交互式）
get_password_interactive() {
    echo
    print_info "请配置数据库密码（环境变量DB_PASSWORD和MSSQL_SA_PASSWORD使用相同密码）"
    echo -n "请输入密码（直接回车使用默认密码 $DEFAULT_PASSWORD）："
    read -s input_password
    echo
    
    if [ -z "$input_password" ]; then
        user_password="$DEFAULT_PASSWORD"
        print_info "使用默认密码"
    else
        echo -n "请再次输入密码确认："
        read -s confirm_password
        echo
        
        if [ "$input_password" != "$confirm_password" ]; then
            print_error "两次输入的密码不一致，请重新运行脚本"
            exit 1
        fi
        user_password="$input_password"
    fi
    
    print_success "密码已配置"
}

# 函数：获取端口配置（交互式）
get_ports_interactive() {
    local input_web_port=""
    local input_db_port=""
    
    echo
    print_info "请配置端口映射（直接回车使用默认端口）"
    
    echo -n "Web服务端口（默认 $DEFAULT_WEB_PORT）："
    read input_web_port
    web_port="${input_web_port:-$DEFAULT_WEB_PORT}"
    
    echo -n "数据库端口（默认 $DEFAULT_DB_PORT）："
    read input_db_port
    db_port="${input_db_port:-$DEFAULT_DB_PORT}"
    
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
    # 解析命令行参数
    parse_args "$@"
    
    clear
    echo "=========================================="
    echo "     LearnSite 一键部署脚本"
    echo "=========================================="
    echo
    
    if [ "$quick_mode" = true ]; then
        print_info "快速模式：使用默认配置"
        print_info "密码：$DEFAULT_PASSWORD"
        print_info "Web端口：$DEFAULT_WEB_PORT"
        print_info "数据库端口：$DEFAULT_DB_PORT"
        echo
    fi
    
    # 步骤1：获取root权限
    check_root "$@"
    
    # 步骤2：创建目录结构
    create_directories
    
    # 步骤3：下载docker-compose.yml
    download_compose_file
    
    # 步骤4：获取配置（交互式或使用命令行参数）
    if [ "$quick_mode" = false ]; then
        if [ -z "${user_password:-}" ] || [ "$user_password" = "$DEFAULT_PASSWORD" ]; then
            get_password_interactive
        else
            print_success "使用命令行指定的密码"
        fi
        if [ -z "${web_port:-}" ] || [ -z "${db_port:-}" ] || \
           [ "$web_port" = "$DEFAULT_WEB_PORT" ] || [ "$db_port" = "$DEFAULT_DB_PORT" ]; then
            get_ports_interactive
        else
            print_success "使用命令行指定的端口配置：Web服务 $web_port，数据库 $db_port"
        fi
    fi
    
    # 步骤5：修改配置文件
    update_compose_config "$user_password" "$web_port" "$db_port"
    
    # 步骤6：部署
    deploy_docker
    
    echo
    echo "=========================================="
    print_success "部署脚本执行完成！"
    echo "=========================================="
}

# 执行主函数
main "$@"