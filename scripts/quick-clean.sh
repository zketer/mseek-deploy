#!/bin/bash

# 快速清理脚本 - macOS系统文件
# 适用于 Linux 环境
# 用途: 在Linux服务器上快速清理macOS打包带来的系统文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     macOS 文件快速清理工具 (Linux)            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$DEPLOY_DIR"

echo -e "${YELLOW}[提示]${NC} 当前目录: $DEPLOY_DIR"
echo ""

# 统计需要清理的文件
echo -e "${BLUE}[扫描]${NC} 统计需要清理的文件..."
resource_fork=$(find . -type f -name "._*" 2>/dev/null | wc -l)
ds_store=$(find . -type f -name ".DS_Store" 2>/dev/null | wc -l)
macosx=$(find . -type d -name "__MACOSX" 2>/dev/null | wc -l)
apple_double=$(find . -type d -name ".AppleDouble" 2>/dev/null | wc -l)

total=$((resource_fork + ds_store + macosx + apple_double))

echo ""
echo "发现以下文件:"
echo "  • 资源分支文件 (._*):    $resource_fork 个"
echo "  • .DS_Store:              $ds_store 个"
echo "  • __MACOSX 目录:          $macosx 个"
echo "  • .AppleDouble 目录:      $apple_double 个"
echo "  ─────────────────────────────────"
echo "  总计:                     $total 个"
echo ""

if [ "$total" -eq 0 ]; then
    echo -e "${GREEN}[完成]${NC} 没有需要清理的文件！"
    exit 0
fi

# 确认清理
if [ "$1" != "-y" ] && [ "$1" != "--yes" ]; then
    read -p "确认清理这些文件？[y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[取消]${NC} 已取消清理操作"
        exit 0
    fi
fi

echo ""
echo -e "${GREEN}[开始]${NC} 清理 macOS 系统文件..."
echo ""

# 清理 ._* 文件（包括所有包含 ._ 的文件）
if [ "$resource_fork" -gt 0 ]; then
    echo -e "${BLUE}[清理]${NC} 删除资源分支文件 (._* 和 *._*)..."
    # 清理以 ._ 开头的文件
    find . -type f -name "._*" -delete 2>/dev/null
    # 清理包含 ._ 的文件（以防万一）
    find . -type f -name "*._*" -delete 2>/dev/null
    # 清理 ._ 开头的目录（如果有）
    find . -type d -name "._*" -exec rm -rf {} + 2>/dev/null || true
    echo "  ✓ 已删除所有 ._ 相关文件"
fi

# 清理 .DS_Store
if [ "$ds_store" -gt 0 ]; then
    echo -e "${BLUE}[清理]${NC} 删除 .DS_Store 文件..."
    find . -type f -name ".DS_Store" -delete 2>/dev/null
    echo "  ✓ 已删除 $ds_store 个文件"
fi

# 清理 __MACOSX
if [ "$macosx" -gt 0 ]; then
    echo -e "${BLUE}[清理]${NC} 删除 __MACOSX 目录..."
    find . -type d -name "__MACOSX" -exec rm -rf {} + 2>/dev/null || true
    echo "  ✓ 已删除 $macosx 个目录"
fi

# 清理 .AppleDouble
if [ "$apple_double" -gt 0 ]; then
    echo -e "${BLUE}[清理]${NC} 删除 .AppleDouble 目录..."
    find . -type d -name ".AppleDouble" -exec rm -rf {} + 2>/dev/null || true
    echo "  ✓ 已删除 $apple_double 个目录"
fi

# 清理其他文件
echo -e "${BLUE}[清理]${NC} 删除其他系统文件..."
find . -type d -name ".Trashes" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name ".LSOverride" -delete 2>/dev/null || true
find . -type f -name "Thumbs.db" -delete 2>/dev/null || true
echo "  ✓ 完成"

echo ""
echo -e "${GREEN}[验证]${NC} 检查清理结果..."
remaining_resource=$(find . -type f -name "._*" 2>/dev/null | wc -l)
remaining_ds=$(find . -type f -name ".DS_Store" 2>/dev/null | wc -l)
remaining_total=$((remaining_resource + remaining_ds))

echo "  • 剩余 ._* 文件: $remaining_resource"
echo "  • 剩余 .DS_Store: $remaining_ds"

echo ""
if [ "$remaining_total" -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ 清理完成！所有文件已删除                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}[警告]${NC} 还有 $remaining_total 个文件未清理"
    echo -e "${YELLOW}[提示]${NC} 可能是权限问题，请尝试使用 sudo"
fi

echo ""

