#!/bin/bash

# Museum Seek 一键部署脚本
# 版本: 2.1.0
# 许可证: Apache 2.0
# 支持通过环境变量动态配置所有服务

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 显示banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║   Museum Seek - 博物馆打卡系统部署工具        ║"
    echo "║   Version: 2.1.0                               ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 选择配置文件
select_config() {
    # 扫描用户可用的配置文件（排除模板和备份文件）
    local user_configs=()
    while IFS= read -r -d '' file; do
        # 只包含非模板、非备份的 env 文件
        if [[ "$file" != *.backup ]] && [[ "$file" != *.example ]]; then
            user_configs+=("$file")
        fi
    done < <(find "$DEPLOY_DIR/config" -name "*.env*" -type f -print0)
    local user_config_count=${#user_configs[@]}

    # 检查是否已有配置文件
    if [ -f "$DEPLOY_DIR/config/env.config" ]; then
        # 有现有配置，显示可切换的配置文件
        if [ "$user_config_count" -gt 0 ]; then
            log_info "检测到现有配置: config/env.config"
            echo "可用配置文件:"
            for i in "${!user_configs[@]}"; do
                local filename=$(basename "${user_configs[$i]}")
                echo "  $((i+1))) $filename"
            done
            echo "  0) 继续使用当前配置"

            read -p "请选择配置文件 [0-$user_config_count, 默认0]: " choice
            choice=${choice:-0}

            if [ "$choice" = "0" ]; then
                # 继续使用当前配置
                return
            elif [ "$choice" -ge 1 ] && [ "$choice" -le "$user_config_count" ]; then
                local selected_file="${user_configs[$((choice-1))]}"
                cp "$selected_file" "$DEPLOY_DIR/config/env.config"
                log_success "已切换到配置: $(basename "$selected_file")"
            else
                log_error "无效选择，使用当前配置"
            fi
        else
            log_info "检测到现有配置: config/env.config (无可切换配置)"
        fi
        return
    fi

    # 没有现有配置
    if [ "$user_config_count" -eq 1 ]; then
        # 只有一个用户配置文件，直接使用
        cp "${user_configs[0]}" "$DEPLOY_DIR/config/env.config"
        log_info "已加载配置: $(basename "${user_configs[0]}")"
    elif [ "$user_config_count" -gt 1 ]; then
        # 多个用户配置文件，让用户选择
        echo "请选择配置文件:"
        for i in "${!user_configs[@]}"; do
            local filename=$(basename "${user_configs[$i]}")
            echo "  $((i+1))) $filename"
        done

        read -p "请选择配置文件 [1-$user_config_count, 默认1]: " choice
        choice=${choice:-1}

        if [ "$choice" -ge 1 ] && [ "$choice" -le "$user_config_count" ]; then
            local selected_file="${user_configs[$((choice-1))]}"
            cp "$selected_file" "$DEPLOY_DIR/config/env.config"
            log_success "已加载配置: $(basename "$selected_file")"
        else
            # 默认使用第一个
            cp "${user_configs[0]}" "$DEPLOY_DIR/config/env.config"
            log_info "已加载默认配置: $(basename "${user_configs[0]}")"
        fi
    else
        # 没有用户配置文件，检查是否有模板
        local template_files=()
        while IFS= read -r -d '' file; do
            if [[ "$file" == *.example ]]; then
                template_files+=("$file")
            fi
        done < <(find "$DEPLOY_DIR/config" -name "*.env*" -type f -print0)

        if [ ${#template_files[@]} -gt 0 ]; then
            echo "🎯 欢迎使用 Museum Seek 部署工具！"
            echo
            echo "❌ 未检测到配置文件"
            echo
            echo "📝 请按以下步骤创建配置文件:"
            echo "   1. 复制模板文件:"
            echo "      cp config/prod.env.example config/prod.env"
            echo "   2. 编辑配置文件，填入您的实际配置:"
            echo "      vim config/prod.env"
            echo "   3. 重新运行部署命令:"
            echo "      ./scripts/deploy.sh start"
            echo
            echo "💡 提示: 配置文件包含数据库密码、API密钥等敏感信息"
            echo "         请妥善保管，不要提交到版本控制系统"
            echo
            exit 0
        else
            log_error "未找到任何配置文件或模板"
            log_info "请创建配置文件或模板文件"
            exit 1
        fi
    fi
}

# 加载环境配置
load_env_config() {
    local env_file="$DEPLOY_DIR/config/env.config"

    if [ ! -f "$env_file" ]; then
        # 检查 prod.env 是否存在
        if [ -f "$DEPLOY_DIR/config/prod.env" ]; then
            # 检查 prod.env 是否包含占位符
            if grep -q "your_" "$DEPLOY_DIR/config/prod.env"; then
                echo
                echo "⚠️  检测到配置文件包含未配置的占位符值"
                echo
                echo "📝 请编辑配置文件，替换所有 'your_*' 占位符为实际值:"
                echo "   vim config/prod.env"
                echo
                echo "🔍 常见的配置项包括:"
                echo "   • 数据库密码: MYSQL_ROOT_PASSWORD, DB_PASSWORD"
                echo "   • Redis密码: REDIS_PASSWORD"
                echo "   • JWT密钥: JWT_RSA_PRIVATE_KEY, JWT_RSA_PUBLIC_KEY"
                echo "   • API密钥: OSS_ACCESS_KEY_ID, GITHUB_CLIENT_SECRET 等"
                echo
                echo "💡 编辑完成后重新运行: ./scripts/deploy.sh start"
                echo
                exit 1
            else
                # prod.env 没有占位符，创建 env.config
                cp "$DEPLOY_DIR/config/prod.env" "$env_file"
                log_step "加载环境配置..."
            fi
        else
            log_error "配置文件不存在: $env_file"
            log_info "请先选择或创建配置文件"
            exit 1
        fi
    else
        # env.config 已存在，检查是否包含占位符
        if grep -q "your_" "$env_file"; then
            echo
            echo "⚠️  检测到运行时配置文件包含未配置的占位符值"
            echo "   这可能是因为之前的配置不完整导致的"
            echo
            echo "📝 请编辑配置文件，替换所有 'your_*' 占位符为实际值:"
            echo "   vim config/prod.env"
            echo
            echo "🔍 常见的配置项包括:"
            echo "   • 数据库密码: MYSQL_ROOT_PASSWORD, DB_PASSWORD"
            echo "   • Redis密码: REDIS_PASSWORD"
            echo "   • JWT密钥: JWT_RSA_PRIVATE_KEY, JWT_RSA_PUBLIC_KEY"
            echo "   • API密钥: OSS_ACCESS_KEY_ID, GITHUB_CLIENT_SECRET 等"
            echo
            echo "💡 编辑完成后，删除运行时配置并重新运行:"
            echo "   rm config/env.config && ./scripts/deploy.sh start"
            echo
            exit 1
        fi

        log_step "加载环境配置..."
    fi

    set -a
    source "$env_file"
    set +a
    
    # 复制到.env供docker-compose使用
    cp "$env_file" "$DEPLOY_DIR/.env"
    
    log_success "环境配置加载完成"
}

# 设置Docker Compose文件 (使用 docker-compose.yml)
setup_compose_file() {
    export COMPOSE_FILE="docker-compose.yml"
    export DOCKER_COMPOSE="docker-compose -f $COMPOSE_FILE"
    log_info "使用统一 Docker Compose 配置"
}

# 设置Docker Compose Profiles
setup_profiles() {
    local profiles=()

    log_step "配置服务启动策略..."

    # 基础设施服务控制 - 基于 ENABLE_* 变量
    if [ "${ENABLE_MYSQL}" = "true" ]; then
        profiles+=("mysql-local")
        log_info "✓ MySQL: 本地Docker"
    else
        log_info "✓ MySQL: 外部服务"
    fi

    if [ "${ENABLE_REDIS}" = "true" ]; then
        profiles+=("redis-local")
        log_info "✓ Redis: 本地Docker"
    else
        log_info "✓ Redis: 外部服务"
    fi

    if [ "${ENABLE_NACOS}" = "true" ]; then
        profiles+=("nacos-local")
        export NACOS_SERVER_ADDR="nacos:8848"
        log_info "✓ Nacos: 本地Docker"
    else
        # 外部Nacos，使用配置文件中的地址
        log_info "✓ Nacos: 外部服务 (${NACOS_SERVER_ADDR})"
    fi

    if [ "${ENABLE_MINIO}" = "true" ]; then
        profiles+=("storage-minio")
        log_info "✓ 存储: 本地MinIO"
    else
        log_info "✓ 存储: 外部服务"
    fi
    
    # MySQL配置
    if [ "${MYSQL_HOST}" != "mysql" ] && [ -n "${MYSQL_HOST}" ]; then
        log_info "✓ MySQL: 外部服务 (${MYSQL_HOST}:${MYSQL_PORT})"
    elif [ "${ENABLE_MYSQL}" = "false" ]; then
        log_info "✓ MySQL: 外部服务 (已配置)"
    else
        profiles+=("mysql-local")
        log_info "✓ MySQL: 本地Docker"
    fi
    
    # 构建profile参数
    if [ ${#profiles[@]} -gt 0 ]; then
        export COMPOSE_PROFILES=$(IFS=,; echo "${profiles[*]}")
        log_info "✓ Profiles: ${COMPOSE_PROFILES}"
    else
        export COMPOSE_PROFILES=""
        log_info "✓ Profiles: (none)"
    fi
    
    log_success "服务配置完成"
}

# 检查Docker环境
check_docker() {
    log_step "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi
    
    log_success "Docker环境检查通过"
}

# 创建必要目录
create_directories() {
    log_step "创建必要的目录..."
    
    cd "$DEPLOY_DIR"
    mkdir -p logs/{gateway,auth,user,museum,file,nginx}
    mkdir -p data/uploads
    
    log_success "目录创建完成"
}

# 停止现有服务
stop_existing_services() {
    log_step "停止现有服务..."
    
    cd "$DEPLOY_DIR"
    
            # 尝试停止所有可能的compose文件
            for compose_file in docker-compose.yml docker-compose.low-resource.yml docker-compose.external-all.yml; do
                if [ -f "$compose_file" ]; then
                    docker-compose -f "$compose_file" down --remove-orphans 2>/dev/null || true
                fi
            done
    sleep 2
    
    log_success "现有服务已停止"
}

# 启动服务
start_services() {
    log_step "启动 Museum Seek 服务..."
    
    cd "$DEPLOY_DIR"
    
    # 根据ENABLE_*变量有条件地启动基础设施服务

    # 启动本地MySQL（如果启用）
    if [ "${ENABLE_MYSQL}" = "true" ]; then
        log_info "→ 启动本地MySQL..."
        $DOCKER_COMPOSE --profile mysql-local up -d mysql
        log_info "→ 等待MySQL就绪..."
        sleep 15
    fi

    # 启动本地Redis（如果启用）
    if [ "${ENABLE_REDIS}" = "true" ]; then
        log_info "→ 启动本地Redis..."
        $DOCKER_COMPOSE --profile redis-local up -d redis
        log_info "→ 等待Redis就绪..."
        sleep 5
    fi

    # 启动本地Nacos（如果启用）
    if [ "${ENABLE_NACOS}" = "true" ]; then
        log_info "→ 启动Nacos配置中心..."
        $DOCKER_COMPOSE --profile nacos-local up -d nacos
        log_info "→ 等待Nacos启动..."
        sleep 20
    fi

    # 启动本地MinIO（如果启用）
    if [ "${ENABLE_MINIO}" = "true" ]; then
        log_info "→ 启动MinIO对象存储..."
        $DOCKER_COMPOSE --profile storage-minio up -d minio
        log_info "→ 等待MinIO启动..."
        sleep 10
    fi
    
    # 启动业务服务
    log_info "→ 启动业务服务 (Auth, User, Museum, File)..."
    $DOCKER_COMPOSE up -d auth-service user-service museum-service file-service
    
    # 等待业务服务启动
    log_info "→ 等待业务服务就绪..."
    sleep 25
    
    # 启动网关和前端
    log_info "→ 启动网关和前端服务..."
    $DOCKER_COMPOSE up -d gateway-service nginx
    
    log_success "所有服务启动完成"
}

# 显示部署计划
show_deployment_plan() {
    echo
    log_step "📋 部署计划预览"
    echo

    # 基础设施服务状态
    echo -e "${CYAN}🏗️ 基础设施服务${NC}"
    echo "  • MySQL: $([ "${ENABLE_MYSQL}" = "true" ] && echo "✅ 本地部署" || echo "🔗 外部服务 (${MYSQL_HOST:-外部})")"
    echo "  • Redis: $([ "${ENABLE_REDIS}" = "true" ] && echo "✅ 本地部署" || echo "🔗 外部服务 (${REDIS_HOST:-外部})")"
    echo "  • Nacos: $([ "${ENABLE_NACOS}" = "true" ] && echo "✅ 本地部署" || echo "🔗 外部服务 (${NACOS_SERVER_ADDR:-外部})")"
    echo "  • MinIO: $([ "${ENABLE_MINIO}" = "true" ] && echo "✅ 本地部署" || echo "🔗 外部服务 (${MINIO_ENDPOINT:-外部})")"
    echo

    # 业务服务（总是本地部署）
    echo -e "${CYAN}🚀 业务服务${NC}"
    echo "  • Auth服务: ✅ 本地部署"
    echo "  • User服务: ✅ 本地部署"
    echo "  • Museum服务: ✅ 本地部署"
    echo "  • File服务: ✅ 本地部署"
    echo "  • Gateway服务: ✅ 本地部署"
    echo "  • Nginx前端: ✅ 本地部署"
    echo

    # 资源需求提示
    echo -e "${CYAN}💡 资源需求评估${NC}"

    # 确保环境变量有默认值
    ENABLE_MYSQL=${ENABLE_MYSQL:-false}
    ENABLE_REDIS=${ENABLE_REDIS:-false}
    ENABLE_NACOS=${ENABLE_NACOS:-false}
    ENABLE_MINIO=${ENABLE_MINIO:-false}

    # 调试信息
    log_info "ENABLE_MYSQL=$ENABLE_MYSQL"
    log_info "ENABLE_REDIS=$ENABLE_REDIS"
    log_info "ENABLE_NACOS=$ENABLE_NACOS"
    log_info "ENABLE_MINIO=$ENABLE_MINIO"

    local local_services=0

    # 使用更兼容的计数方式
    if [ "${ENABLE_MYSQL}" = "true" ]; then
        local_services=$((local_services + 1))
        log_info "MySQL服务计数 +1"
    fi

    if [ "${ENABLE_REDIS}" = "true" ]; then
        local_services=$((local_services + 1))
        log_info "Redis服务计数 +1"
    fi

    if [ "${ENABLE_NACOS}" = "true" ]; then
        local_services=$((local_services + 1))
        log_info "Nacos服务计数 +1"
    fi

    if [ "${ENABLE_MINIO}" = "true" ]; then
        local_services=$((local_services + 1))
        log_info "MinIO服务计数 +1"
    fi

    log_info "检测到 $local_services 个本地基础设施服务"

    if [ "$local_services" -eq 0 ]; then
        echo "  📊 轻量部署: 仅业务服务，资源需求低"
    elif [ "$local_services" -le 2 ]; then
        echo "  📊 标准部署: $local_services 个基础设施服务，资源需求中等"
    else
        echo "  📊 完整部署: $local_services 个基础设施服务，建议配置充足资源"
    fi
    echo

    # 询问用户是否继续
    # 检查是否在交互式环境中
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        log_info "检测到交互式环境，等待用户确认..."
        read -p "是否继续执行部署? [Y/n]: " confirm
        confirm=${confirm:-Y}
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "部署已取消"
            exit 0
        fi
    else
        log_info "非交互环境或管道输入，自动继续部署..."
    fi
}

# 健康检查
health_check() {
    log_step "执行健康检查..."
    
    cd "$DEPLOY_DIR"
    
    # 等待服务完全启动
    sleep 10
    
    # 检查服务状态
    echo
    $DOCKER_COMPOSE ps
    echo
    
    # 检查关键端口
    local services=(
        "Gateway:8000"
        "Auth:8001"
        "User:8002"
        "Museum:8003"
        "File:8004"
        "Nginx:80"
    )
    
    # 检查本地MySQL
    if [ "${ENABLE_MYSQL}" != "false" ] && [ "${MYSQL_HOST}" = "mysql" ]; then
        services=("MySQL:3306" "${services[@]}")
    fi
    
    # 检查本地Redis
    if [ "${ENABLE_REDIS}" = "true" ]; then
        services=("Redis:6379" "${services[@]}")
    fi

    # 检查本地Nacos
    if [ "${ENABLE_NACOS}" = "true" ]; then
        services+=("Nacos:8848")
    fi

    # 检查本地MinIO
    if [ "${ENABLE_MINIO}" = "true" ]; then
        services+=("MinIO:9000")
    fi
    
    log_info "端口检查:"
    for service in "${services[@]}"; do
        local name="${service%%:*}"
        local port="${service##*:}"
        if nc -z localhost $port 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $name ($port)"
        else
            echo -e "  ${YELLOW}?${NC} $name ($port) - 未就绪"
        fi
    done
    
    echo
    log_success "健康检查完成"
}

# 显示服务信息
show_info() {
    echo
    log_success "=========================================="
    log_success "Museum Seek 部署完成！"
    log_success "=========================================="
    echo
    
    # 部署配置信息
    echo -e "${CYAN}📋 服务部署状态${NC}"
    echo "  • 本地MySQL: $([ "${ENABLE_MYSQL}" = "true" ] && echo "✅ 启用" || echo "❌ 禁用")"
    echo "  • 本地Redis: $([ "${ENABLE_REDIS}" = "true" ] && echo "✅ 启用" || echo "❌ 禁用")"
    echo "  • 本地Nacos: $([ "${ENABLE_NACOS}" = "true" ] && echo "✅ 启用" || echo "❌ 禁用")"
    echo "  • 本地MinIO: $([ "${ENABLE_MINIO}" = "true" ] && echo "✅ 启用" || echo "❌ 禁用")"
    echo "  • 日志级别: ${LOG_LEVEL:-INFO}"
    echo
    
    # 服务访问地址
    echo -e "${CYAN}🌐 服务访问地址${NC}"
    echo "  🎨 前端管理界面: http://localhost:${NGINX_PORT:-80}"
    echo "  🌐 API网关: http://localhost:${GATEWAY_PORT:-8000}"
    echo "  🔐 认证服务: http://localhost:${AUTH_PORT:-8001}"
    echo "  👥 用户服务: http://localhost:${USER_PORT:-8002}"
    echo "  🏛️ 博物馆服务: http://localhost:${MUSEUM_PORT:-8003}"
    echo "  📁 文件服务: http://localhost:${FILE_PORT:-8004}"
    echo
    
    # 基础设施访问
    echo -e "${CYAN}🔧 基础设施${NC}"
    
    # MySQL
    if [ "${ENABLE_MYSQL}" = "false" ] || [ "${MYSQL_HOST}" != "mysql" ]; then
        echo "  💾 MySQL: ${MYSQL_HOST}:${MYSQL_PORT:-3306} (外部)"
    else
        echo "  💾 MySQL: localhost:${MYSQL_PORT:-3306}"
    fi
    
    # Redis
    if [ "${ENABLE_REDIS}" = "true" ]; then
        echo "  🔥 Redis: localhost:${REDIS_PORT:-6379}"
    else
        echo "  🔥 Redis: ${REDIS_HOST}:${REDIS_PORT:-6379} (外部)"
    fi

    # Nacos
    if [ "${ENABLE_NACOS}" = "true" ]; then
        echo "  ⚙️ Nacos控制台: http://localhost:${LOCAL_NACOS_PORT:-8848}/nacos"
        echo "     用户名/密码: nacos/nacos"
    else
        echo "  ⚙️ Nacos: ${NACOS_SERVER_ADDR} (外部)"
    fi

    # 存储
    if [ "${ENABLE_MINIO}" = "true" ]; then
        echo "  📦 MinIO控制台: http://localhost:${MINIO_CONSOLE_PORT:-9001}"
        echo "     用户名/密码: ${MINIO_ACCESS_KEY}/${MINIO_SECRET_KEY}"
    else
        echo "  📦 存储服务: 外部配置"
    fi
    
    echo
    
    # 常用命令
    echo -e "${CYAN}📝 常用命令${NC}"
    echo "  • 查看服务状态: ./scripts/deploy.sh status"
    echo "  • 查看日志: ./scripts/deploy.sh logs [service_name]"
    echo "  • 重启服务: ./scripts/deploy.sh restart"
    echo "  • 停止服务: ./scripts/deploy.sh stop"
    echo
}

# 主函数
main() {
    show_banner
    
    case "${1:-start}" in
        "start"|"deploy")
            # 选择或使用现有配置
            select_config

            check_docker
            load_env_config
            show_deployment_plan
            setup_compose_file
            setup_profiles
            create_directories
            stop_existing_services
            start_services
            health_check
            show_info
            ;;
        "stop")
            cd "$DEPLOY_DIR"
            if [ -f ".env" ]; then
                source ".env"
                setup_compose_file
                $DOCKER_COMPOSE down
            else
                # 停止docker-compose服务
                docker-compose down 2>/dev/null || true
            fi
            log_success "服务已停止"
            ;;
        "restart")
            cd "$DEPLOY_DIR"
            if [ -f ".env" ]; then
                source ".env"
            fi
            load_env_config
            setup_compose_file
            setup_profiles
            $DOCKER_COMPOSE restart
            health_check
            show_info
            ;;
        "status")
            cd "$DEPLOY_DIR"
            if [ -f ".env" ]; then
                source ".env"
                setup_compose_file
                $DOCKER_COMPOSE ps
            else
                docker-compose ps
            fi
            ;;
        "logs")
            cd "$DEPLOY_DIR"
            if [ -f ".env" ]; then
                source ".env"
                setup_compose_file
                $DOCKER_COMPOSE logs -f "${2:-}"
            else
                docker-compose logs -f "${2:-}"
            fi
            ;;
        "clean")
            cd "$DEPLOY_DIR"
            # 清理docker-compose文件
            for cf in docker-compose.yml; do
                [ -f "$cf" ] && docker-compose -f "$cf" down --volumes --remove-orphans 2>/dev/null || true
            done
            docker system prune -f
            log_success "清理完成"
            ;;
        "config")
            select_config
            log_success "配置文件已更新"
            ;;
        "help"|"-h"|"--help"|*)
            echo "Museum Seek 部署脚本 v2.1.0"
            echo
            echo "用法: $0 [命令] [选项]"
            echo
            echo "命令:"
            echo "  start [preset]  - 启动服务"
            echo "  stop            - 停止服务"
            echo "  restart         - 重启服务"
            echo "  status          - 查看服务状态"
            echo "  logs [service]  - 查看日志"
            echo "  clean           - 清理所有数据和容器"
            echo "  config          - 配置部署选项"
            echo "  help            - 显示帮助信息"
            echo
            echo "示例:"
            echo "  $0 start                       # 启动服务"
            echo "  $0 stop                        # 停止服务"
            echo "  $0 restart                     # 重启服务"
            echo "  $0 logs museum-service         # 查看博物馆服务日志"
            echo "  $0 status                      # 查看服务状态"
            exit 1
            ;;
    esac
}

main "$@"