#!/bin/bash

# Cloudflare Tunnel 统一管理脚本
# 功能：创建、配置、启动、停止、重启、查看状态、查看日志
# 支持：MinIO Tunnel 和 Museum Tunnel

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }
log_title() { echo -e "${CYAN}═══════════════════════════════════════${NC}"; }

# 配置
WORK_DIR="/opt/claudeflare"
MINIO_CONFIG="$WORK_DIR/minio-tunnel-config.yml"
MUSEUM_CONFIG="$WORK_DIR/museum-tunnel-config.yml"
MINIO_PID_FILE="$WORK_DIR/cloudflare-minio.pid"
MUSEUM_PID_FILE="$WORK_DIR/cloudflare-museum.pid"

# 显示帮助信息
show_help() {
    echo ""
    log_title
    echo -e "${CYAN}  Cloudflare Tunnel 统一管理脚本${NC}"
    log_title
    echo ""
    echo "用法: $0 <服务> <操作>"
    echo ""
    echo "服务:"
    echo "  minio    - MinIO Tunnel (minio-api.your-domain.com, minio-console.your-domain.com)"
    echo "  museum   - Museum Tunnel (museum.your-domain.com)"
    echo "  all      - 所有服务"
    echo ""
    echo "操作:"
    echo "  start      - 启动 Tunnel"
    echo "  stop       - 停止 Tunnel"
    echo "  restart    - 重启 Tunnel"
    echo "  status     - 查看状态"
    echo "  logs       - 查看日志（实时）"
    echo "  create     - 创建新 Tunnel 并配置"
    echo "  delete     - 删除 Tunnel（包括配置、日志、DNS记录）"
    echo "  clean      - 清理所有历史数据并重新创建"
    echo "  fix        - 修复配置（自动检测并修复）"
    echo "  validate   - 验证配置"
    echo ""
    echo "示例:"
    echo "  $0 minio start       # 启动 MinIO Tunnel"
    echo "  $0 museum status     # 查看 Museum Tunnel 状态"
    echo "  $0 all restart       # 重启所有 Tunnel"
    echo "  $0 minio logs        # 查看 MinIO Tunnel 日志"
    echo "  $0 minio clean       # 清理所有历史数据并重新创建"
    echo "  $0 minio delete      # 仅删除 Tunnel（不重新创建）"
    echo ""
}

# 检查 cloudflared
check_cloudflared() {
    if ! command -v cloudflared > /dev/null; then
        log_error "cloudflared 未安装"
        log_info "请先安装 cloudflared"
        exit 1
    fi
}

# 检查认证
check_auth() {
    if [ ! -f ~/.cloudflared/cert.pem ]; then
        log_error "未找到 Cloudflare 认证文件"
        log_info "请先执行: cloudflared tunnel login"
        exit 1
    fi
}

# 启动 Tunnel
start_tunnel() {
    local service=$1
    local config_file=""
    local pid_file=""
    local log_file=""
    local tunnel_name=""
    
    case $service in
        minio)
            config_file="$MINIO_CONFIG"
            pid_file="$MINIO_PID_FILE"
            log_file="$WORK_DIR/cloudflared-minio.log"
            tunnel_name="MinIO"
            ;;
        museum)
            config_file="$MUSEUM_CONFIG"
            pid_file="$MUSEUM_PID_FILE"
            log_file="$WORK_DIR/cloudflared-museum.log"
            tunnel_name="Museum"
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        log_info "请先运行: $0 $service create"
        return 1
    fi
    
    # 检查是否已在运行
    if [ -f "$pid_file" ]; then
        local old_pid=$(cat "$pid_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_warn "$tunnel_name Tunnel 已在运行 (PID: $old_pid)"
            return 0
        fi
    fi
    
    # 清理残留进程
    pkill -f "cloudflared.*tunnel.*run.*$service" 2>/dev/null || true
    
    log_info "启动 $tunnel_name Tunnel..."
    
    # 验证配置
    if ! cloudflared tunnel --config "$config_file" ingress validate > /dev/null 2>&1; then
        log_error "配置文件验证失败"
        log_info "运行验证: cloudflared tunnel --config $config_file ingress validate"
        return 1
    fi
    
    # 启动
    cd "$WORK_DIR"
    nohup cloudflared tunnel --config "$config_file" run > "$log_file" 2>&1 &
    local pid=$!
    echo $pid > "$pid_file"
    
    sleep 2
    
    if kill -0 "$pid" 2>/dev/null; then
        log_info "✅ $tunnel_name Tunnel 启动成功 (PID: $pid)"
        log_info "日志文件: $log_file"
    else
        log_error "❌ $tunnel_name Tunnel 启动失败"
        log_info "查看日志: tail -50 $log_file"
        return 1
    fi
}

# 停止 Tunnel
stop_tunnel() {
    local service=$1
    local pid_file=""
    local tunnel_name=""
    
    case $service in
        minio)
            pid_file="$MINIO_PID_FILE"
            tunnel_name="MinIO"
            ;;
        museum)
            pid_file="$MUSEUM_PID_FILE"
            tunnel_name="Museum"
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    log_info "停止 $tunnel_name Tunnel..."
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            log_info "✅ $tunnel_name Tunnel 已停止 (PID: $pid)"
        else
            log_warn "进程可能已停止 (PID: $pid)"
        fi
        rm -f "$pid_file"
    else
        log_warn "未找到 PID 文件"
    fi
    
    # 清理残留进程
    pkill -f "cloudflared.*tunnel.*run.*$service" 2>/dev/null || true
}

# 查看状态
show_status() {
    local service=$1
    
    if [ "$service" = "all" ]; then
        show_status minio
        echo ""
        show_status museum
        return
    fi
    
    local config_file=""
    local pid_file=""
    local log_file=""
    local tunnel_name=""
    
    case $service in
        minio)
            config_file="$MINIO_CONFIG"
            pid_file="$MINIO_PID_FILE"
            log_file="$WORK_DIR/cloudflared-minio.log"
            tunnel_name="MinIO"
            ;;
        museum)
            config_file="$MUSEUM_CONFIG"
            pid_file="$MUSEUM_PID_FILE"
            log_file="$WORK_DIR/cloudflared-museum.log"
            tunnel_name="Museum"
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    log_title
    log_info "$tunnel_name Tunnel 状态"
    log_title
    
    # 进程状态
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "✅ 运行中 (PID: $pid)"
            ps -p "$pid" -o pid,etime,cmd | tail -1 | sed 's/^/   /'
        else
            log_warn "⚠️  PID 文件存在但进程不存在 (PID: $pid)"
        fi
    else
        log_info "⚪ 未运行"
    fi
    
    # 配置文件
    echo ""
    if [ -f "$config_file" ]; then
        log_info "配置文件: $config_file"
        local tunnel_id=$(grep "^tunnel:" "$config_file" | awk '{print $2}' | tr -d '"' || echo "")
        if [ -n "$tunnel_id" ]; then
            log_info "隧道 ID: $tunnel_id"
        fi
        
        local hostnames=$(grep -E "^\s+- hostname:" "$config_file" | awk -F: '{print $2}' | sed 's/^[[:space:]]*//' | tr -d '"' || echo "")
        if [ -n "$hostnames" ]; then
            log_info "配置的域名:"
            echo "$hostnames" | while read hostname; do
                if [ -n "$hostname" ] && [ "$hostname" != "hostname" ]; then
                    log_info "  - $hostname"
                fi
            done
        fi
    else
        log_warn "配置文件不存在: $config_file"
    fi
    
    # 日志
    echo ""
    if [ -f "$log_file" ]; then
        log_info "日志文件: $log_file ($(wc -l < "$log_file" 2>/dev/null || echo 0) 行)"
        log_info "最近日志:"
        tail -5 "$log_file" 2>/dev/null | sed 's/^/   /' || log_warn "无法读取日志"
    else
        log_warn "日志文件不存在"
    fi
}

# 查看日志
show_logs() {
    local service=$1
    local log_file=""
    
    case $service in
        minio)
            log_file="$WORK_DIR/cloudflared-minio.log"
            ;;
        museum)
            log_file="$WORK_DIR/cloudflared-museum.log"
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    if [ -f "$log_file" ]; then
        log_info "实时日志 (按 Ctrl+C 退出):"
        tail -f "$log_file"
    else
        log_error "日志文件不存在: $log_file"
    fi
}

# 创建 Tunnel
create_tunnel() {
    local service=$1
    local tunnel_name=""
    local config_file=""
    local domains=()
    
    case $service in
        minio)
            tunnel_name="minio-mseek-tunnel"
            config_file="$MINIO_CONFIG"
            domains=("minio-api.your-domain.com" "minio-console.your-domain.com")
            ;;
        museum)
            tunnel_name="museum-mseek-tunnel"
            config_file="$MUSEUM_CONFIG"
            domains=("museum.your-domain.com")
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    log_title
    log_info "🚀 创建 $service Tunnel"
    log_title
    echo ""
    log_info "步骤 1/5: 检查并创建 Tunnel..."
    log_info "  Tunnel 名称: $tunnel_name"
    log_info "  配置域名:"
    for domain in "${domains[@]}"; do
        log_info "    - $domain"
    done
    echo ""
    
    # 检查 Tunnel 是否已存在
    local tunnel_id=""
    if cloudflared tunnel list 2>/dev/null | grep -q "$tunnel_name"; then
        log_warn "  Tunnel '$tunnel_name' 已存在"
        tunnel_id=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
        log_info "  使用现有 Tunnel ID: $tunnel_id"
        echo ""
        read -p "  是否删除旧 Tunnel 并重新创建？(y/n): " delete_old
        if [ "$delete_old" = "y" ]; then
            log_info "  删除旧 Tunnel..."
            cloudflared tunnel delete "$tunnel_name" || log_warn "  删除失败"
            log_info "  创建新 Tunnel..."
            cloudflared tunnel create "$tunnel_name"
            tunnel_id=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
        fi
    else
        log_info "  创建新 Tunnel..."
        cloudflared tunnel create "$tunnel_name"
        tunnel_id=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
    fi
    
    if [ -z "$tunnel_id" ]; then
        log_error "  ❌ 无法获取 Tunnel ID"
        return 1
    fi
    
    log_info "  ✅ Tunnel ID: $tunnel_id"
    log_info "  ✅ 凭证文件: $HOME/.cloudflared/${tunnel_id}.json"
    echo ""
    
    # 创建配置文件
    log_info "步骤 2/5: 生成配置文件..."
    mkdir -p "$WORK_DIR"
    
    # 备份旧配置
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        log_info "  旧配置已备份: $backup_file"
    fi
    
    # 生成配置
    cat > "$config_file" <<EOF
# $service Cloudflare Tunnel 配置
# 隧道 ID: $tunnel_id
# 创建时间: $(date '+%Y-%m-%d %H:%M:%S')

tunnel: $tunnel_id
credentials-file: $HOME/.cloudflared/${tunnel_id}.json

ingress:
EOF

    # 添加域名配置（MinIO 使用 80 端口，Museum 使用 80 端口）
    for domain in "${domains[@]}"; do
        cat >> "$config_file" <<EOF
  - hostname: $domain
    service: http://localhost:80
    originRequest:
      httpHostHeader: $domain
      noTLSVerify: true
      connectTimeout: 30s
      tcpKeepAlive: 30s
EOF
    done
    
    # 添加默认规则
    cat >> "$config_file" <<EOF
      
  - service: http_status:404

loglevel: info
logfile: $WORK_DIR/cloudflared-${service}.log
protocol: quic
retries: 3
grace-period: 30s
EOF

    log_info "  ✅ 配置文件已创建: $config_file"
    echo ""
    
    # 验证配置
    log_info "步骤 3/5: 验证配置文件..."
    if cloudflared tunnel --config "$config_file" ingress validate; then
        log_info "  ✅ 配置验证通过"
    else
        log_error "  ❌ 配置验证失败"
        log_info "  请检查配置文件: $config_file"
        return 1
    fi
    echo ""
    
    # 添加 DNS 记录
    log_info "步骤 4/5: 添加 DNS 记录..."
    log_info "  将以下域名添加到 Cloudflare DNS："
    for domain in "${domains[@]}"; do
        log_info "    - $domain → ${tunnel_id}.cfargotunnel.com"
    done
    echo ""
    
    for domain in "${domains[@]}"; do
        log_info "  添加: $domain"
        if cloudflared tunnel route dns "$tunnel_id" "$domain" 2>&1 | tee /tmp/cf_route_output.txt | grep -q "Added CNAME"; then
            log_info "    ✅ DNS 记录添加成功"
        else
            if grep -q "already exists" /tmp/cf_route_output.txt; then
                log_warn "    ⚠️  DNS 记录已存在（这是正常的）"
        else
                log_warn "    ⚠️  添加失败或已存在"
                log_info "    请在 Cloudflare Dashboard 手动确认"
            fi
        fi
    done
    rm -f /tmp/cf_route_output.txt
    echo ""
    
    # 完成总结
    log_title
    log_info "🎉 步骤 5/5: Tunnel 创建完成"
    log_title
    echo ""
    log_info "📋 配置信息："
    log_info "  Tunnel 名称: $tunnel_name"
    log_info "  Tunnel ID: $tunnel_id"
    log_info "  配置文件: $config_file"
    log_info "  凭证文件: $HOME/.cloudflared/${tunnel_id}.json"
    echo ""
    log_info "🌐 配置的域名："
    for domain in "${domains[@]}"; do
        log_info "  - $domain"
    done
    echo ""
    log_info "📝 下一步操作："
    log_info "  1. 在 Cloudflare Dashboard 中确认 DNS 记录："
    log_info "     https://dash.cloudflare.com → 选择域名 your-domain.com → DNS 记录"
    echo ""
    for domain in "${domains[@]}"; do
        log_info "     检查记录: $domain"
        log_info "       类型: CNAME"
        log_info "       内容: ${tunnel_id}.cfargotunnel.com"
        log_info "       代理状态: 已代理（橙色云朵）"
        echo ""
    done
    log_info "  2. 启动 Tunnel："
    log_info "     $0 $service start"
    echo ""
    log_info "  3. 查看状态："
    log_info "     $0 $service status"
    echo ""
    log_info "  4. 查看日志："
    log_info "     $0 $service logs"
    echo ""
    log_warn "⚠️  注意：DNS 记录添加后，Cloudflare 需要 5-10 分钟生成证书"
    echo ""
}

# 修复配置
fix_config() {
    local service=$1
    local config_file=""
    
    case $service in
        minio)
            config_file="$MINIO_CONFIG"
            ;;
        museum)
            config_file="$MUSEUM_CONFIG"
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        log_info "运行 '$0 $service create' 创建配置"
        return 1
    fi
    
    log_info "修复 $service 配置..."
    
    # 获取隧道 ID
    local tunnel_id=$(grep "^tunnel:" "$config_file" | awk '{print $2}' | tr -d '"' || echo "")
    if [ -z "$tunnel_id" ]; then
        log_error "无法获取隧道 ID"
        return 1
    fi
    
    log_info "隧道 ID: $tunnel_id"
    
    # 检查 hostname 是否为空
    local hostnames=$(grep -E "^\s+- hostname:" "$config_file" | awk '{print $2}' | tr -d '"' || echo "")
    local has_empty=false
    
    echo "$hostnames" | while read hostname; do
        if [ -z "$hostname" ]; then
            has_empty=true
        fi
    done
    
    if [ "$has_empty" = true ] || [ -z "$hostnames" ]; then
        log_warn "发现空的 hostname，需要修复"
        log_info "请运行 '$0 $service create' 重新创建配置"
        return 1
    fi
    
    log_info "✅ 配置看起来正常"
    
    # 验证配置
    if cloudflared tunnel --config "$config_file" ingress validate; then
        log_info "✅ 配置验证通过"
    else
        log_error "❌ 配置验证失败"
        return 1
    fi
}

# 验证配置
validate_config() {
    local service=$1
    
    if [ "$service" = "all" ]; then
        validate_config minio
        echo ""
        validate_config museum
        return
    fi
    
    local config_file=""
    
    case $service in
        minio)
            config_file="$MINIO_CONFIG"
            ;;
        museum)
            config_file="$MUSEUM_CONFIG"
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    log_info "验证 $service 配置..."
    if cloudflared tunnel --config "$config_file" ingress validate; then
        log_info "✅ 配置验证通过"
    else
        log_error "❌ 配置验证失败"
        return 1
    fi
}

# 删除 Tunnel
delete_tunnel() {
    local service=$1
    local tunnel_name=""
    local config_file=""
    local pid_file=""
    local log_file=""
    local domains=()
    
    case $service in
        minio)
            tunnel_name="minio-mseek-tunnel"
            config_file="$MINIO_CONFIG"
            pid_file="$MINIO_PID_FILE"
            log_file="$WORK_DIR/cloudflared-minio.log"
            domains=("minio-api.your-domain.com" "minio-console.your-domain.com")
            ;;
        museum)
            tunnel_name="museum-mseek-tunnel"
            config_file="$MUSEUM_CONFIG"
            pid_file="$MUSEUM_PID_FILE"
            log_file="$WORK_DIR/cloudflared-museum.log"
            domains=("museum.your-domain.com")
            ;;
        *)
            log_error "未知服务: $service"
            return 1
            ;;
    esac
    
    log_title
    log_warn "⚠️  删除 $service Tunnel"
    log_title
    echo ""
    log_warn "此操作将删除："
    log_warn "  - Tunnel: $tunnel_name"
    log_warn "  - 配置文件: $config_file"
    log_warn "  - 日志文件: $log_file"
    log_warn "  - PID 文件: $pid_file"
    log_warn "  - DNS 记录（需要手动在 Cloudflare Dashboard 删除）"
    echo ""
    read -p "确认删除？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "取消删除"
        return 0
    fi
    
    echo ""
    log_info "开始删除..."
    
    # 1. 停止服务
    log_info "步骤 1/5: 停止服务..."
    stop_tunnel "$service"
    echo ""
    
    # 2. 删除 Tunnel
    log_info "步骤 2/5: 删除 Tunnel..."
    if cloudflared tunnel list 2>/dev/null | grep -q "$tunnel_name"; then
        local tunnel_id=$(cloudflared tunnel list | grep "$tunnel_name" | awk '{print $1}')
        log_info "  Tunnel ID: $tunnel_id"
        
        if cloudflared tunnel delete "$tunnel_id" -f 2>/dev/null; then
            log_info "  ✅ Tunnel 已删除"
        else
            log_warn "  ⚠️  删除失败或 Tunnel 不存在"
        fi
    else
        log_info "  Tunnel 不存在，跳过"
    fi
    echo ""
    
    # 3. 删除配置文件
    log_info "步骤 3/5: 删除配置文件..."
    if [ -f "$config_file" ]; then
        rm -f "$config_file"
        log_info "  ✅ 配置文件已删除: $config_file"
    else
        log_info "  配置文件不存在，跳过"
    fi
    
    # 删除备份文件
    local backup_count=$(ls -1 "${config_file}.backup."* 2>/dev/null | wc -l)
    if [ "$backup_count" -gt 0 ]; then
        rm -f "${config_file}.backup."*
        log_info "  ✅ 已删除 $backup_count 个备份文件"
    fi
    echo ""
    
    # 4. 删除日志和 PID 文件
    log_info "步骤 4/5: 删除日志和 PID 文件..."
    if [ -f "$log_file" ]; then
        rm -f "$log_file"
        log_info "  ✅ 日志文件已删除: $log_file"
    fi
    if [ -f "$pid_file" ]; then
        rm -f "$pid_file"
        log_info "  ✅ PID 文件已删除: $pid_file"
    fi
    echo ""
    
    # 5. 提示删除 DNS 记录
    log_info "步骤 5/5: DNS 记录清理提示"
    log_warn "  ⚠️  需要手动在 Cloudflare Dashboard 删除以下 DNS 记录："
    log_warn "     https://dash.cloudflare.com → 选择域名 your-domain.com → DNS 记录"
    echo ""
    for domain in "${domains[@]}"; do
        log_warn "     - $domain"
    done
    echo ""
    
    log_info "✅ 删除完成"
}

# 清理并重新创建
clean_tunnel() {
    local service=$1
    
    log_title
    log_info "🧹 清理 $service Tunnel 并重新创建"
    log_title
    echo ""
    
    # 删除
    delete_tunnel "$service"
    
    if [ $? -eq 0 ]; then
        echo ""
        log_info "等待 2 秒后重新创建..."
        sleep 2
        echo ""
        
        # 重新创建
        create_tunnel "$service"
    else
        log_error "清理失败，取消重新创建"
        return 1
    fi
}

# 主函数
main() {
    local service=${1:-help}
    local action=${2:-help}
    
    case $service in
        help|-h|--help)
            show_help
            exit 0
            ;;
        minio|museum|all)
            ;;
        *)
            log_error "未知服务: $service"
            show_help
            exit 1
            ;;
    esac
    
    check_cloudflared
    
    case $action in
        start)
            if [ "$service" = "all" ]; then
                start_tunnel minio
                echo ""
                start_tunnel museum
            else
                check_auth
                start_tunnel "$service"
            fi
            ;;
        stop)
            if [ "$service" = "all" ]; then
                stop_tunnel minio
                echo ""
                stop_tunnel museum
            else
                stop_tunnel "$service"
            fi
            ;;
        restart)
            if [ "$service" = "all" ]; then
                stop_tunnel minio
                stop_tunnel museum
                sleep 2
                start_tunnel minio
                echo ""
                start_tunnel museum
            else
                stop_tunnel "$service"
                sleep 2
                check_auth
                start_tunnel "$service"
            fi
            ;;
        status)
            show_status "$service"
            ;;
        logs)
            if [ "$service" = "all" ]; then
                log_error "无法同时查看所有服务的日志"
                log_info "请指定服务: $0 minio logs 或 $0 museum logs"
                exit 1
            fi
            show_logs "$service"
            ;;
        create)
            if [ "$service" = "all" ]; then
                check_auth
                create_tunnel minio
                echo ""
                create_tunnel museum
            else
                check_auth
                create_tunnel "$service"
            fi
            ;;
        fix)
            if [ "$service" = "all" ]; then
                fix_config minio
                echo ""
                fix_config museum
            else
                fix_config "$service"
            fi
            ;;
        validate)
            validate_config "$service"
            ;;
        delete)
            if [ "$service" = "all" ]; then
                delete_tunnel minio
                echo ""
                delete_tunnel museum
            else
                delete_tunnel "$service"
            fi
            ;;
        clean)
            if [ "$service" = "all" ]; then
                clean_tunnel minio
                echo ""
                clean_tunnel museum
            else
                check_auth
                clean_tunnel "$service"
            fi
            ;;
        *)
            log_error "未知操作: $action"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

