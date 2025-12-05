#!/bin/bash

################################################################################
# 日志清理脚本
# 功能：清理Docker容器和宿主机的日志文件
# 作者：lynn
# 版本：1.0.0
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$PROJECT_ROOT/services/business"

# 日志统计
declare -A log_sizes_before
declare -A log_sizes_after

################################################################################
# 辅助函数
################################################################################

# 打印带颜色的消息
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

# 打印分隔线
print_separator() {
    echo "=================================================================="
}

# 获取目录大小（人类可读格式）
get_dir_size() {
    local dir=$1
    if [ -d "$dir" ]; then
        du -sh "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0B"
    fi
}

# 获取目录大小（字节）
get_dir_size_bytes() {
    local dir=$1
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# 格式化字节数
format_bytes() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")KB"
    else
        echo "${bytes}B"
    fi
}

################################################################################
# 统计函数
################################################################################

# 统计清理前的日志大小
collect_sizes_before() {
    print_info "正在统计清理前的日志大小..."
    
    if [ -d "$SERVICES_DIR" ]; then
        for service_dir in "$SERVICES_DIR"/*; do
            if [ -d "$service_dir/logs" ]; then
                service_name=$(basename "$service_dir")
                log_sizes_before[$service_name]=$(get_dir_size_bytes "$service_dir/logs")
            fi
        done
    fi
}

# 统计清理后的日志大小并显示对比
collect_sizes_after_and_report() {
    print_info "正在统计清理后的日志大小..."
    echo ""
    
    print_separator
    printf "%-20s %-15s %-15s %-15s\n" "服务名称" "清理前" "清理后" "清理量"
    print_separator
    
    local total_before=0
    local total_after=0
    
    if [ -d "$SERVICES_DIR" ]; then
        for service_dir in "$SERVICES_DIR"/*; do
            if [ -d "$service_dir/logs" ]; then
                service_name=$(basename "$service_dir")
                size_before=${log_sizes_before[$service_name]:-0}
                size_after=$(get_dir_size_bytes "$service_dir/logs")
                size_cleaned=$((size_before - size_after))
                
                printf "%-20s %-15s %-15s %-15s\n" \
                    "$service_name" \
                    "$(format_bytes $size_before)" \
                    "$(format_bytes $size_after)" \
                    "$(format_bytes $size_cleaned)"
                
                total_before=$((total_before + size_before))
                total_after=$((total_after + size_after))
            fi
        done
    fi
    
    local total_cleaned=$((total_before - total_after))
    
    print_separator
    printf "%-20s %-15s %-15s %-15s\n" \
        "总计" \
        "$(format_bytes $total_before)" \
        "$(format_bytes $total_after)" \
        "$(format_bytes $total_cleaned)"
    print_separator
    echo ""
    
    if [ $total_cleaned -gt 0 ]; then
        print_success "共清理日志：$(format_bytes $total_cleaned)"
    else
        print_info "没有需要清理的日志"
    fi
}

################################################################################
# 清理函数
################################################################################

# 清理所有日志（完全删除）
clean_all_logs() {
    print_warning "准备清理所有日志文件..."
    
    if [ ! -d "$SERVICES_DIR" ]; then
        print_info "服务目录不存在：$SERVICES_DIR"
        return
    fi
    
    read -p "确认要删除所有日志文件吗？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消清理操作"
        return
    fi
    
    collect_sizes_before
    
    print_info "正在删除所有日志文件..."
    for service_dir in "$SERVICES_DIR"/*; do
        if [ -d "$service_dir/logs" ]; then
            rm -rf "$service_dir/logs"/*
        fi
    done
    
    print_success "所有日志文件已删除"
    
    collect_sizes_after_and_report
}

# 清理旧日志（保留最近N天）
clean_old_logs() {
    local days=${1:-7}
    
    print_info "准备清理 $days 天前的日志文件..."
    
    if [ ! -d "$SERVICES_DIR" ]; then
        print_info "服务目录不存在：$SERVICES_DIR"
        return
    fi
    
    collect_sizes_before
    
    local file_count=0
    
    # 清理压缩的归档日志
    print_info "清理压缩归档日志（*.log.gz）..."
    for service_dir in "$SERVICES_DIR"/*; do
        if [ -d "$service_dir/logs" ]; then
            while IFS= read -r -d '' file; do
                rm -f "$file"
                ((file_count++))
            done < <(find "$service_dir/logs" -name "*.log.gz" -type f -mtime +$days -print0)
        fi
    done
    
    # 清理旧的日志文件（带日期的）
    print_info "清理旧的日志文件（*.log.*）..."
    for service_dir in "$SERVICES_DIR"/*; do
        if [ -d "$service_dir/logs" ]; then
            while IFS= read -r -d '' file; do
                # 排除当前活动日志（all.log, error.log）
                if [[ ! "$file" =~ (all\.log|error\.log)$ ]]; then
                    rm -f "$file"
                    ((file_count++))
                fi
            done < <(find "$service_dir/logs" -name "*.log.*" -type f -mtime +$days -print0)
        fi
    done
    
    print_success "清理了 $file_count 个旧日志文件"
    
    collect_sizes_after_and_report
}

# 清理压缩日志
clean_gz_logs() {
    print_info "准备清理所有压缩日志文件（*.log.gz）..."
    
    if [ ! -d "$SERVICES_DIR" ]; then
        print_info "服务目录不存在：$SERVICES_DIR"
        return
    fi
    
    collect_sizes_before
    
    local file_count=0
    
    for service_dir in "$SERVICES_DIR"/*; do
        if [ -d "$service_dir/logs" ]; then
            while IFS= read -r -d '' file; do
                rm -f "$file"
                ((file_count++))
            done < <(find "$service_dir/logs" -name "*.log.gz" -type f -print0)
        fi
    done
    
    print_success "清理了 $file_count 个压缩日志文件"
    
    collect_sizes_after_and_report
}

# 清理单个服务的日志
clean_service_logs() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_error "请指定要清理的服务名称"
        return 1
    fi
    
    local service_log_dir="$SERVICES_DIR/$service/logs"
    
    if [ ! -d "$service_log_dir" ]; then
        print_error "服务日志目录不存在：$service_log_dir"
        return 1
    fi
    
    print_warning "准备清理服务 $service 的所有日志..."
    
    read -p "确认要删除服务 $service 的所有日志吗？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消清理操作"
        return
    fi
    
    local size_before=$(get_dir_size "$service_log_dir")
    
    print_info "正在删除服务 $service 的日志..."
    rm -rf "$service_log_dir"/*
    
    local size_after=$(get_dir_size "$service_log_dir")
    
    print_success "服务 $service 的日志已清理（清理前：$size_before，清理后：$size_after）"
}

# 压缩当前日志
archive_current_logs() {
    print_info "准备归档当前日志..."
    
    if [ ! -d "$SERVICES_DIR" ]; then
        print_info "服务目录不存在：$SERVICES_DIR"
        return
    fi
    
    local archive_date=$(date +%Y%m%d_%H%M%S)
    local archive_file="$PROJECT_ROOT/logs_archive_$archive_date.tar.gz"
    
    print_info "正在创建归档文件：$archive_file"
    
    # 创建临时目录用于归档
    local temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/logs"
    
    # 复制所有服务的日志到临时目录
    for service_dir in "$SERVICES_DIR"/*; do
        if [ -d "$service_dir/logs" ]; then
            service_name=$(basename "$service_dir")
            cp -r "$service_dir/logs" "$temp_dir/logs/$service_name"
        fi
    done
    
    # 创建归档
    tar -czf "$archive_file" -C "$temp_dir" logs
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    local archive_size=$(du -sh "$archive_file" | awk '{print $1}')
    print_success "日志归档完成：$archive_file（大小：$archive_size）"
    
    read -p "归档完成后是否清理原日志？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        clean_all_logs
    fi
}

################################################################################
# 查看函数
################################################################################

# 查看日志统计
view_log_stats() {
    print_info "日志统计信息"
    echo ""
    
    if [ ! -d "$SERVICES_DIR" ]; then
        print_warning "服务目录不存在：$SERVICES_DIR"
        return
    fi
    
    print_separator
    printf "%-20s %-15s %-10s %-10s %-10s\n" "服务名称" "总大小" "日志文件" "归档文件" "总文件数"
    print_separator
    
    local total_size=0
    local total_logs=0
    local total_archives=0
    local total_files=0
    
    for service_dir in "$SERVICES_DIR"/*; do
        if [ -d "$service_dir/logs" ]; then
            service_name=$(basename "$service_dir")
            size=$(get_dir_size "$service_dir/logs")
            size_bytes=$(get_dir_size_bytes "$service_dir/logs")
            log_count=$(find "$service_dir/logs" -name "*.log" -type f 2>/dev/null | wc -l)
            gz_count=$(find "$service_dir/logs" -name "*.log.gz" -type f 2>/dev/null | wc -l)
            file_count=$(find "$service_dir/logs" -type f 2>/dev/null | wc -l)
            
            printf "%-20s %-15s %-10s %-10s %-10s\n" \
                "$service_name" \
                "$size" \
                "$log_count" \
                "$gz_count" \
                "$file_count"
            
            total_size=$((total_size + size_bytes))
            total_logs=$((total_logs + log_count))
            total_archives=$((total_archives + gz_count))
            total_files=$((total_files + file_count))
        fi
    done
    
    print_separator
    printf "%-20s %-15s %-10s %-10s %-10s\n" \
        "总计" \
        "$(format_bytes $total_size)" \
        "$total_logs" \
        "$total_archives" \
        "$total_files"
    print_separator
    echo ""
    
    # 检查是否有归档文件
    local archive_count=$(find "$PROJECT_ROOT" -maxdepth 1 -name "logs_archive_*.tar.gz" 2>/dev/null | wc -l)
    if [ $archive_count -gt 0 ]; then
        echo ""
        print_info "找到 $archive_count 个归档文件："
        find "$PROJECT_ROOT" -maxdepth 1 -name "logs_archive_*.tar.gz" -exec ls -lh {} \; | \
            awk '{print "  - " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
    fi
}

################################################################################
# 主函数
################################################################################

# 显示使用帮助
show_help() {
    cat << EOF
日志清理脚本

用法：
    $0 [选项]

选项：
    -h, --help              显示帮助信息
    -a, --all               清理所有日志（需要确认）
    -o, --old [天数]        清理N天前的日志（默认7天）
    -g, --gz                清理所有压缩日志（*.log.gz）
    -s, --service <名称>    清理指定服务的日志
    -r, --archive           归档当前日志
    -v, --view              查看日志统计信息

示例：
    $0 --view               # 查看日志统计
    $0 --old 7              # 清理7天前的日志
    $0 --gz                 # 清理所有压缩日志
    $0 --service museum     # 清理museum服务的日志
    $0 --archive            # 归档当前日志
    $0 --all                # 清理所有日志

EOF
}

# 主程序
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -a|--all)
            clean_all_logs
            ;;
        -o|--old)
            clean_old_logs "${2:-7}"
            ;;
        -g|--gz)
            clean_gz_logs
            ;;
        -s|--service)
            if [ -z "${2:-}" ]; then
                print_error "请指定服务名称"
                exit 1
            fi
            clean_service_logs "$2"
            ;;
        -r|--archive)
            archive_current_logs
            ;;
        -v|--view)
            view_log_stats
            ;;
        "")
            view_log_stats
            ;;
        *)
            print_error "未知选项：$1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

################################################################################
# 执行
################################################################################

main "$@"
