#!/bin/bash

# ================================
# 服务器环境诊断脚本
# 用于检查 MuseumSeek 服务部署状态
# ================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_separator() {
    echo "=================================================================="
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 1. 检查Docker环境
check_docker() {
    print_separator
    echo -e "${BLUE}=== 1. 检查Docker环境 ===${NC}"
    print_separator
    
    if command_exists docker; then
        log_success "Docker已安装: $(docker --version)"
    else
        log_error "Docker未安装"
        return 1
    fi
    
    if command_exists docker-compose; then
        log_success "Docker Compose已安装: $(docker-compose --version)"
    else
        log_warning "docker-compose未安装，尝试使用 docker compose"
    fi
    
    echo ""
}

# 2. 检查容器状态
check_containers() {
    print_separator
    echo -e "${BLUE}=== 2. 检查容器状态 ===${NC}"
    print_separator
    
    log_info "所有MuseumSeek容器："
    docker ps -a --filter "name=mseek" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    
    # 检查每个服务
    local services=("mseek-gateway" "mseek-auth" "mseek-user" "mseek-museum" "mseek-file" "mseek-nginx")
    
    for service in "${services[@]}"; do
        if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
            log_success "$service 运行中"
        else
            log_error "$service 未运行"
        fi
    done
    
    echo ""
}

# 3. 检查服务健康状态
check_health() {
    print_separator
    echo -e "${BLUE}=== 3. 检查服务健康状态 ===${NC}"
    print_separator
    
    local endpoints=(
        "Gateway:8000:/actuator/health"
        "Auth:8001:/api/v1/auth/actuator/health"
        "User:8002:/api/v1/system/actuator/health"
        "Museum:8003:/api/v1/museums/actuator/health"
        "File:8004:/api/v1/files/actuator/health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local name="${endpoint%%:*}"
        local temp="${endpoint#*:}"
        local port="${temp%%:*}"
        local path="${temp#*:}"
        
        if curl -s -f --connect-timeout 5 "http://localhost:${port}${path}" > /dev/null 2>&1; then
            local status=$(curl -s "http://localhost:${port}${path}" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            if [ "$status" = "UP" ]; then
                log_success "$name 健康检查: UP"
            else
                log_warning "$name 健康检查: $status"
                log_info "详细信息: curl http://localhost:${port}${path}"
            fi
        else
            log_error "$name 无法访问 (端口 $port)"
        fi
    done
    
    echo ""
}

# 4. 检查网络连通性
check_network() {
    print_separator
    echo -e "${BLUE}=== 4. 检查网络连通性 ===${NC}"
    print_separator
    
    # 检查外部Redis
    log_info "检查外部Redis (123.56.12.253:6379)..."
    if timeout 5 bash -c "echo > /dev/tcp/123.56.12.253/6379" 2>/dev/null; then
        log_success "Redis端口可访问"
        
        if command_exists redis-cli; then
            if redis-cli -h 123.56.12.253 -p 6379 -a h2vMDLpFgeTCs2n8 --no-auth-warning ping 2>/dev/null | grep -q "PONG"; then
                log_success "Redis连接成功"
            else
                log_warning "Redis端口开放但无法认证"
            fi
        fi
    else
        log_error "Redis端口不可访问"
    fi
    
    # 检查外部Nacos
    log_info "检查外部Nacos (123.56.12.253:8848)..."
    if timeout 5 bash -c "echo > /dev/tcp/123.56.12.253/8848" 2>/dev/null; then
        log_success "Nacos端口可访问"
        
        if curl -s -f --connect-timeout 5 "http://123.56.12.253:8848/nacos/" > /dev/null 2>&1; then
            log_success "Nacos服务正常"
        else
            log_warning "Nacos端口开放但服务无响应"
        fi
    else
        log_error "Nacos端口不可访问"
    fi
    
    # 检查邮件服务器
    log_info "检查SMTP服务器 (smtp.163.com:465)..."
    if timeout 5 bash -c "echo > /dev/tcp/smtp.163.com/465" 2>/dev/null; then
        log_success "SMTP端口可访问"
    else
        log_warning "SMTP端口不可访问（可能被云服务商封禁）"
        log_info "这会导致邮件功能失败，但不影响核心服务"
    fi
    
    echo ""
}

# 5. 检查端口监听
check_ports() {
    print_separator
    echo -e "${BLUE}=== 5. 检查端口监听 ===${NC}"
    print_separator
    
    log_info "检查业务服务端口..."
    
    if command_exists netstat; then
        netstat -tlnp 2>/dev/null | grep -E ':800[0-4]' || log_warning "未找到监听端口，服务可能未启动"
    elif command_exists ss; then
        ss -tlnp | grep -E ':800[0-4]' || log_warning "未找到监听端口，服务可能未启动"
    else
        log_warning "netstat/ss 命令不可用，跳过端口检查"
    fi
    
    echo ""
}

# 6. 检查容器日志
check_logs() {
    print_separator
    echo -e "${BLUE}=== 6. 检查容器日志（最近错误）===${NC}"
    print_separator
    
    local services=("mseek-gateway" "mseek-auth" "mseek-user" "mseek-museum" "mseek-file")
    
    for service in "${services[@]}"; do
        if docker ps --filter "name=$service" | grep -q "$service"; then
            log_info "检查 $service 错误日志..."
            local errors=$(docker logs "$service" --tail=100 2>&1 | grep -iE 'error|exception|failed' | tail -3)
            
            if [ -n "$errors" ]; then
                log_warning "发现错误:"
                echo "$errors" | while read -r line; do
                    echo "  $line"
                done
            else
                log_success "无明显错误"
            fi
        fi
    done
    
    echo ""
}

# 7. 检查资源使用
check_resources() {
    print_separator
    echo -e "${BLUE}=== 7. 检查资源使用 ===${NC}"
    print_separator
    
    log_info "容器资源使用情况:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker ps --filter "name=mseek" -q)
    
    echo ""
    
    log_info "系统资源:"
    if command_exists free; then
        free -h
    else
        log_warning "free命令不可用"
    fi
    
    echo ""
}

# 8. 检查配置文件
check_config() {
    print_separator
    echo -e "${BLUE}=== 8. 检查配置文件 ===${NC}"
    print_separator
    
    local config_file="../config/env.config"
    
    if [ -f "$config_file" ]; then
        log_success "配置文件存在: $config_file"
        
        log_info "关键配置项:"
        grep -E 'DEPLOY_CONFIG|REDIS_HOST|NACOS_SERVER_ADDR|MYSQL_HOST' "$config_file" | grep -v '^#' || log_warning "未找到关键配置"
    else
        log_error "配置文件不存在: $config_file"
    fi
    
    echo ""
}

# 9. 生成诊断报告
generate_report() {
    print_separator
    echo -e "${BLUE}=== 诊断总结 ===${NC}"
    print_separator
    
    echo ""
    echo "📋 快速修复建议:"
    echo ""
    echo "1. 如果容器未运行，重启服务:"
    echo "   cd deploy-mseek && ./scripts/deploy.sh restart"
    echo ""
    echo "2. 如果健康检查失败，查看详细日志:"
    echo "   docker logs -f mseek-auth"
    echo ""
    echo "3. 如果邮件服务失败（不影响核心功能），禁用健康检查:"
    echo "   在配置中添加: MANAGEMENT_HEALTH_MAIL_ENABLED=false"
    echo ""
    echo "4. 如果Redis/Nacos连接失败，检查网络和防火墙:"
    echo "   firewall-cmd --list-all"
    echo ""
    echo "5. 查看完整日志:"
    echo "   docker-compose -f docker-compose.external-all.yml logs -f"
    echo ""
}

# 主函数
main() {
    echo ""
    print_separator
    echo -e "${GREEN}MuseumSeek 服务诊断工具${NC}"
    print_separator
    echo ""
    
    # 切换到脚本目录
    cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    check_docker
    check_containers
    check_health
    check_network
    check_ports
    check_logs
    check_resources
    check_config
    generate_report
    
    print_separator
    echo -e "${GREEN}诊断完成！${NC}"
    print_separator
    echo ""
}

# 执行主函数
main "$@"

