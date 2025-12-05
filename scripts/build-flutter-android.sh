#!/bin/bash

# Flutter Android 打包脚本
# 版本: 1.0.0
# 作者: lynn
# 日期: 2024-01-15
# 用途: 自动化打包 Flutter Android APP

# 设置脚本参数
set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
BUILD_MODE="release"
BUILD_TYPE="apk"
FLUTTER_PROJECT_PATH="../mseek-mobile"
OUTPUT_DIR="build/app/outputs"

# 函数定义
print_help() {
    echo "Flutter Android 打包脚本"
    echo ""
    echo "用法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -m, --mode MODE        构建模式 (debug|profile|release) [默认: release]"
    echo "  -t, --type TYPE        构建类型 (apk|appbundle) [默认: apk]"
    echo "  -p, --path PATH        Flutter项目路径 [默认: ../mseek-mobile]"
    echo "  -c, --clean            清理构建缓存"
    echo "  -h, --help             显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --mode release --type apk          # 构建发布版APK"
    echo "  $0 --mode debug --type appbundle      # 构建调试版AAB"
    echo "  $0 --clean --mode release             # 清理缓存后构建发布版"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_requirements() {
    print_info "检查构建环境..."

    # 检查Flutter是否安装
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter 未安装或不在PATH中"
        print_info "请访问 https://flutter.dev/docs/get-started/install 下载并安装 Flutter"
        exit 1
    fi

    # 检查Flutter版本
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    print_success "Flutter 版本: $FLUTTER_VERSION"

    # 检查项目路径是否存在
    if [ ! -d "$FLUTTER_PROJECT_PATH" ]; then
        print_error "Flutter 项目路径不存在: $FLUTTER_PROJECT_PATH"
        exit 1
    fi

    # 检查pubspec.yaml是否存在
    if [ ! -f "$FLUTTER_PROJECT_PATH/pubspec.yaml" ]; then
        print_error "不是有效的Flutter项目，缺少 pubspec.yaml 文件"
        exit 1
    fi

    print_success "环境检查通过"
}

setup_project() {
    print_info "设置项目环境..."

    cd "$FLUTTER_PROJECT_PATH"

    # 获取Flutter项目信息
    PROJECT_NAME=$(grep '^name:' pubspec.yaml | cut -d' ' -f2 | tr -d '\r')
    PROJECT_VERSION=$(grep '^version:' pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1 | tr -d '\r')

    print_info "项目名称: $PROJECT_NAME"
    print_info "项目版本: $PROJECT_VERSION"
    print_info "构建模式: $BUILD_MODE"
    print_info "构建类型: $BUILD_TYPE"
}

install_dependencies() {
    print_info "安装项目依赖..."

    if flutter pub get; then
        print_success "依赖安装完成"
    else
        print_error "依赖安装失败"
        exit 1
    fi
}

clean_build_cache() {
    print_info "清理构建缓存..."

    if flutter clean; then
        print_success "缓存清理完成"
    else
        print_warning "缓存清理失败，继续构建..."
    fi
}

build_app() {
    print_info "开始构建应用..."

    local build_command="flutter build"

    # 设置构建类型
    case $BUILD_TYPE in
        "apk")
            build_command="$build_command apk"
            ;;
        "appbundle")
            build_command="$build_command appbundle"
            ;;
        *)
            print_error "不支持的构建类型: $BUILD_TYPE"
            exit 1
            ;;
    esac

    # 设置构建模式
    case $BUILD_MODE in
        "debug")
            build_command="$build_command --debug"
            ;;
        "profile")
            build_command="$build_command --profile"
            ;;
        "release")
            build_command="$build_command --release"
            ;;
        *)
            print_error "不支持的构建模式: $BUILD_MODE"
            exit 1
            ;;
    esac

    print_info "执行命令: $build_command"

    if $build_command; then
        print_success "应用构建完成"
    else
        print_error "应用构建失败"
        exit 1
    fi
}

show_build_info() {
    print_info "构建信息汇总"

    local output_path=""

    case $BUILD_TYPE in
        "apk")
            output_path="$OUTPUT_DIR/flutter-apk"
            ;;
        "appbundle")
            output_path="$OUTPUT_DIR/bundle/release"
            ;;
    esac

    if [ -d "$output_path" ]; then
        echo ""
        print_success "构建输出文件:"

        case $BUILD_TYPE in
            "apk")
                find "$output_path" -name "*.apk" -type f | while read -r file; do
                    local file_size=$(du -h "$file" | cut -f1)
                    echo "  📱 $(basename "$file") ($file_size)"
                done
                ;;
            "appbundle")
                find "$output_path" -name "*.aab" -type f | while read -r file; do
                    local file_size=$(du -h "$file" | cut -f1)
                    echo "  📦 $(basename "$file") ($file_size)"
                done
                ;;
        esac

        echo ""
        print_info "输出目录: $FLUTTER_PROJECT_PATH/$output_path"
    else
        print_warning "未找到输出目录: $output_path"
    fi
}

show_usage_guide() {
    echo ""
    print_info "使用指南:"
    echo ""
    echo "1. APK文件可以直接安装到Android设备"
    echo "2. AAB文件需要上传到Google Play进行发布"
    echo ""
    echo "📋 发布检查清单:"
    echo "  □ 应用签名配置正确"
    echo "  □ 应用ID (applicationId) 设置正确"
    echo "  □ 版本号 (versionCode/versionName) 已更新"
    echo "  □ 权限配置完整"
    echo "  □ 测试功能正常"
    echo ""
}

main() {
    # 参数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                BUILD_MODE="$2"
                shift 2
                ;;
            -t|--type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            -p|--path)
                FLUTTER_PROJECT_PATH="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_CACHE=true
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                print_help
                exit 1
                ;;
        esac
    done

    # 验证参数
    case $BUILD_MODE in
        debug|profile|release) ;;
        *) print_error "无效的构建模式: $BUILD_MODE (支持: debug, profile, release)"; exit 1 ;;
    esac

    case $BUILD_TYPE in
        apk|appbundle) ;;
        *) print_error "无效的构建类型: $BUILD_TYPE (支持: apk, appbundle)"; exit 1 ;;
    esac

    echo ""
    echo "========================================"
    print_info "Flutter Android 打包脚本 v1.0.0"
    echo "========================================"
    echo ""

    # 执行构建流程
    check_requirements
    setup_project

    if [ "$CLEAN_CACHE" = true ]; then
        clean_build_cache
    fi

    install_dependencies
    build_app
    show_build_info
    show_usage_guide

    echo ""
    print_success "🎉 打包完成！"
    echo ""
}

# 执行主函数
main "$@"
