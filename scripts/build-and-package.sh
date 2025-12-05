#!/bin/bash

# Museum Seek 服务打包脚本
# 版本: 2.0.0
# 作者: lynn
# 功能: 编译、打包、构建完整部署环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="MuseumSeek"
PROJECT_VERSION="2.0.0"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_DIR="$BASE_DIR/mseek-admin-backend"
FRONTEND_DIR="$BASE_DIR/mseek-admin-frontend"
DEPLOY_DIR="$BASE_DIR/mseek-deploy"

# 服务列表
SERVICES=(
    "auth-center/auth-service"
    "api-gateway/gateway-service" 
    "business-service/user-service"
    "business-service/museum-service"
    "common-service/file-service"
)

# 服务名称映射
SERVICE_NAMES=(
    "auth-service"
    "gateway-service"
    "user-service"
    "museum-service"
    "file-service"
)

# 日志函数
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

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查Java
    if ! command -v java &> /dev/null; then
        log_error "Java 未安装或不在PATH中"
        exit 1
    fi
    
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    if [ "$JAVA_VERSION" -lt 17 ]; then
        log_error "需要Java 17或更高版本，当前版本: $JAVA_VERSION"
        exit 1
    fi
    log_success "Java版本检查通过: $(java -version 2>&1 | head -1)"
    
    # 检查Maven
    if ! command -v mvn &> /dev/null; then
        log_error "Maven 未安装或不在PATH中"
        exit 1
    fi
    log_success "Maven版本: $(mvn -version | head -1)"
    
    # 检查Node.js (用于前端构建)
    if ! command -v node &> /dev/null; then
        log_warning "Node.js 未安装，将跳过前端构建"
    else
        log_success "Node.js版本: $(node --version)"
    fi
}

# 清理旧的构建产物
clean_build() {
    log_info "清理旧的构建产物..."
    
    cd "$BACKEND_DIR"
    mvn clean -q
    
    # 清理services/business目录
    for service_name in "${SERVICE_NAMES[@]}"; do
        rm -rf "$DEPLOY_DIR/services/business/$service_name"/*
        mkdir -p "$DEPLOY_DIR/services/business/$service_name"
    done
    
    # 清理前端目录
    rm -rf "$DEPLOY_DIR/services/common/nginx/web"
    mkdir -p "$DEPLOY_DIR/services/common/nginx/web"
    
    log_success "清理完成"
}

# 编译后端项目
build_backend() {
    log_info "编译后端项目..."
    
    cd "$BACKEND_DIR"
    
    # 编译所有模块
    log_info "Maven编译中..."
    mvn clean compile -DskipTests -q
    log_success "后端编译完成"
    
    # 打包所有服务
    for i in "${!SERVICES[@]}"; do
        service="${SERVICES[$i]}"
        service_name="${SERVICE_NAMES[$i]}"
        
        log_info "打包服务: $service -> $service_name"
        cd "$BACKEND_DIR/$service"
        
        # Maven打包
        mvn package -DskipTests -q
        
        # 检查打包结果并解压到目标目录
        if [ -f "target/${service##*/}-0.0.1.tar.gz" ]; then
            log_info "解压 $service_name 到 $DEPLOY_DIR/services/business/$service_name/"
            tar -xzf "target/${service##*/}-0.0.1.tar.gz" -C "$DEPLOY_DIR/services/business/$service_name/" --strip-components=1
            log_success "服务 $service_name 打包并解压完成"
        else
            log_error "服务 $service 打包失败，未找到 target/${service##*/}-0.0.1.tar.gz"
            exit 1
        fi
        
        cd "$BACKEND_DIR"
    done
}

# 构建前端项目
build_frontend() {
    if [ ! -d "$FRONTEND_DIR" ]; then
        log_warning "前端目录不存在，跳过前端构建"
        return
    fi
    
    if ! command -v node &> /dev/null; then
        log_warning "Node.js 未安装，跳过前端构建"
        return
    fi
    
    log_info "构建前端项目..."
    
    cd "$FRONTEND_DIR"
    
    # 安装依赖
    if [ ! -d "node_modules" ]; then
        log_info "安装前端依赖..."
        if command -v yarn &> /dev/null; then
            yarn install --frozen-lockfile
        else
            npm install
        fi
    fi
    
    # 构建生产版本
    log_info "构建前端生产版本..."
    if command -v yarn &> /dev/null; then
        yarn build
    else
        npm run build
    fi
    
    # 复制前端文件到nginx/web目录
    log_info "复制前端文件到 $DEPLOY_DIR/services/common/nginx/web/"
    cp -r dist/* "$DEPLOY_DIR/services/common/nginx/web/"
    
    log_success "前端构建完成"
}

# 验证配置文件
verify_configs() {
    log_info "验证配置文件..."
    
    # 验证MySQL配置
    if [ ! -f "$DEPLOY_DIR/services/common/mysql/init/init-databases.sql" ]; then
        log_warning "MySQL初始化脚本不存在"
    fi
    
    if [ ! -f "$DEPLOY_DIR/services/common/mysql/conf/my.cnf" ] && [ ! -f "$DEPLOY_DIR/services/common/mysql/conf/mysql.cnf" ]; then
        log_warning "MySQL配置文件不存在"
    fi
    
    # 验证Nginx配置
    if [ ! -f "$DEPLOY_DIR/services/common/nginx/conf/nginx.conf" ]; then
        log_warning "Nginx主配置文件不存在"
    fi
    
    if [ ! -f "$DEPLOY_DIR/services/common/nginx/conf/default.conf" ]; then
        log_warning "Nginx前端配置文件不存在"
    fi
    
    # 验证Redis配置
    if [ ! -f "$DEPLOY_DIR/services/common/redis/redis.conf" ]; then
        log_warning "Redis配置文件不存在"
    fi
    
    log_success "配置文件验证完成"
}

# 创建docker-compose.yml
create_compose_file() {
    log_info "创建 docker-compose.yml 文件..."
    
    cat > "$DEPLOY_DIR/docker-compose.yml" << 'EOF'
services:
  # MySQL 数据库
  mysql:
    image: mysql:8.0
    container_name: mseek-mysql
    restart: always
    ports:
      - "${MYSQL_PORT:-3306}:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_CHARACTER_SET_SERVER: utf8mb4
      MYSQL_COLLATION_SERVER: utf8mb4_general_ci
    volumes:
      - mysql-data:/var/lib/mysql
      - ./services/common/mysql/init:/docker-entrypoint-initdb.d
      - ./services/common/mysql/conf:/etc/mysql/conf.d
    command: --default-authentication-plugin=mysql_native_password
    networks:
      - mseek-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  # Redis 缓存
  redis:
    image: redis:7-alpine
    container_name: mseek-redis
    restart: always
    ports:
      - "${REDIS_PORT:-6379}:6379"
    command: redis-server /usr/local/etc/redis/redis.conf
    volumes:
      - redis-data:/data
      - ./services/common/redis/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - mseek-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # API 网关服务
  gateway-service:
    image: openjdk:17
    container_name: mseek-gateway
    restart: always
    ports:
      - "${GATEWAY_PORT:-8000}:8000"
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE:-prod}
      DB_URL: jdbc:mysql://mysql:3306/mseek_gateway?useUnicode=true&characterEncoding=utf-8&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    working_dir: /app
    command: ["java", "-jar", "gateway-service-0.0.1.jar"]
    volumes:
      - ./services/business/gateway-service:/app
      - ./logs/gateway:/app/logs
    networks:
      - mseek-network
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # 认证服务
  auth-service:
    image: openjdk:17
    container_name: mseek-auth
    restart: always
    ports:
      - "${AUTH_PORT:-8001}:8001"
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE:-prod}
      DB_URL: jdbc:mysql://mysql:3306/mseek_auth?useUnicode=true&characterEncoding=utf-8&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    working_dir: /app
    command: ["java", "-jar", "auth-service-0.0.1.jar"]
    volumes:
      - ./services/business/auth-service:/app
      - ./logs/auth:/app/logs
    networks:
      - mseek-network
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # 用户服务
  user-service:
    image: openjdk:17
    container_name: mseek-user
    restart: always
    ports:
      - "${USER_PORT:-8002}:8002"
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE:-prod}
      DB_URL: jdbc:mysql://mysql:3306/mseek_user?useUnicode=true&characterEncoding=utf-8&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    working_dir: /app
    command: ["java", "-jar", "user-service-0.0.1.jar"]
    volumes:
      - ./services/business/user-service:/app
      - ./logs/user:/app/logs
    networks:
      - mseek-network
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      auth-service:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8002/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # 博物馆服务
  museum-service:
    image: openjdk:17
    container_name: mseek-museum
    restart: always
    ports:
      - "${MUSEUM_PORT:-8003}:8003"
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE:-prod}
      DB_URL: jdbc:mysql://mysql:3306/mseek_museum?useUnicode=true&characterEncoding=utf-8&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    working_dir: /app
    command: ["java", "-jar", "museum-service-0.0.1.jar"]
    volumes:
      - ./services/business/museum-service:/app
      - ./logs/museum:/app/logs
    networks:
      - mseek-network
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      auth-service:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8003/actuator/health"]
      interval: 30s
      timeout: 15s
      retries: 5
      start_period: 60s

  # 文件服务
  file-service:
    image: openjdk:17
    container_name: mseek-file
    restart: always
    ports:
      - "${FILE_PORT:-8004}:8004"
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE:-prod}
      STORAGE_TYPE: ${STORAGE_TYPE:-local}
      STORAGE_BASE_PATH: ${STORAGE_BASE_PATH:-/app/uploads}
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    working_dir: /app
    command: ["java", "-jar", "file-service-0.0.1.jar"]
    volumes:
      - ./services/business/file-service:/app
      - ./logs/file:/app/logs
      - file-storage:/app/uploads
    networks:
      - mseek-network
    depends_on:
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8004/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Nginx 前端服务
  nginx:
    image: nginx:alpine
    container_name: mseek-nginx
    restart: always
    ports:
      - "${NGINX_PORT:-80}:80"
    volumes:
      - ./services/common/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./services/common/nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./web:/usr/share/nginx/html
      - ./logs/nginx:/var/log/nginx
    networks:
      - mseek-network
    depends_on:
      - gateway-service
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  mseek-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16

volumes:
  mysql-data:
    driver: local
  redis-data:
    driver: local
  file-storage:
    driver: local
EOF

    log_success "docker-compose.yml 文件创建完成"
}

# 创建.env文件
create_env_file() {
    log_info "创建 .env 配置文件..."
    
    cat > "$DEPLOY_DIR/.env" << 'EOF'
# Museum Seek 部署配置文件
# 版本: 2.0.0

# 项目信息
PROJECT_NAME=MuseumSeek
PROJECT_VERSION=2.0.0
SPRING_PROFILES_ACTIVE=prod

# 端口配置
MYSQL_PORT=3306
REDIS_PORT=6379
GATEWAY_PORT=8000
AUTH_PORT=8001
USER_PORT=8002
MUSEUM_PORT=8003
FILE_PORT=8004
NGINX_PORT=80

# 数据库配置
MYSQL_ROOT_PASSWORD=mseek_root_2024
DB_USERNAME=root
DB_PASSWORD=mseek_root_2024

# Redis配置
REDIS_PASSWORD=mseek_redis_2024

# 存储配置
STORAGE_TYPE=local
STORAGE_BASE_PATH=/app/uploads

# JWT配置
JWT_SECRET=mseek_jwt_secret_key_2024_very_long_and_secure
JWT_EXPIRATION=86400

# 日志级别
LOG_LEVEL=INFO
EOF

    log_success ".env 配置文件创建完成"
}

# 创建部署脚本
create_deploy_script() {
    log_info "创建一键部署脚本..."
    
    cat > "$DEPLOY_DIR/scripts/deploy.sh" << 'EOF'
#!/bin/bash

# Museum Seek 一键部署脚本
# 版本: 2.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 检查Docker环境
check_docker() {
    log_info "检查Docker环境..."
    
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
    log_info "创建必要的目录..."
    
    cd "$DEPLOY_DIR"
    mkdir -p logs/{gateway,auth,user,museum,file,nginx}
    mkdir -p data/{uploads}
    
    log_success "目录创建完成"
}

# 停止现有服务
stop_existing_services() {
    log_info "停止现有服务..."
    
    cd "$DEPLOY_DIR"
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose down --remove-orphans || true
        sleep 3
    fi
    
    log_success "现有服务已停止"
}

# 启动服务
start_services() {
    log_info "启动 Museum Seek 服务..."
    
    cd "$DEPLOY_DIR"
    
    # 启动基础设施服务
    log_info "启动基础设施服务 (MySQL, Redis)..."
    docker-compose up -d mysql redis
    
    # 等待基础设施服务启动
    log_info "等待基础设施服务启动..."
    sleep 15
    
    # 启动业务服务
    log_info "启动业务服务..."
    docker-compose up -d auth-service user-service museum-service file-service
    
    # 等待业务服务启动
    log_info "等待业务服务启动..."
    sleep 20
    
    # 启动网关和前端
    log_info "启动网关和前端服务..."
    docker-compose up -d gateway-service nginx
    
    log_success "所有服务启动完成"
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    cd "$DEPLOY_DIR"
    
    # 等待服务完全启动
    sleep 10
    
    # 检查服务状态
    docker-compose ps
    
    # 检查端口
    local ports=(8000 8001 8002 8003 8004 80 3306 6379)
    
    for port in "${ports[@]}"; do
        if nc -z localhost $port 2>/dev/null; then
            log_success "端口 $port 正常"
        else
            log_warning "端口 $port 不可达"
        fi
    done
}

# 显示服务信息
show_info() {
    echo
    log_success "=========================================="
    log_success "Museum Seek 部署完成！"
    log_success "=========================================="
    echo
    log_info "服务访问地址:"
    echo "  - 前端界面: http://localhost"
    echo "  - API网关: http://localhost:8000"
    echo "  - 认证服务: http://localhost:8001"
    echo "  - 用户服务: http://localhost:8002"
    echo "  - 博物馆服务: http://localhost:8003"
    echo "  - 文件服务: http://localhost:8004"
    echo
    log_info "常用命令:"
    echo "  - 查看服务状态: docker-compose ps"
    echo "  - 查看日志: docker-compose logs [service_name]"
    echo "  - 停止服务: docker-compose down"
    echo "  - 重启服务: docker-compose restart [service_name]"
    echo
}

# 主函数
main() {
    case "${1:-start}" in
        "start"|"deploy")
            check_docker
            create_directories
            stop_existing_services
            start_services
            health_check
            show_info
            ;;
        "stop")
            cd "$DEPLOY_DIR"
            docker-compose down
            log_success "服务已停止"
            ;;
        "restart")
            cd "$DEPLOY_DIR"
            docker-compose restart
            health_check
            show_info
            ;;
        "status")
            cd "$DEPLOY_DIR"
            docker-compose ps
            ;;
        "logs")
            cd "$DEPLOY_DIR"
            docker-compose logs -f "${2:-}"
            ;;
        "clean")
            cd "$DEPLOY_DIR"
            docker-compose down --volumes --remove-orphans
            docker system prune -f
            log_success "清理完成"
            ;;
        *)
            echo "用法: $0 [start|stop|restart|status|logs|clean]"
            echo
            echo "命令说明:"
            echo "  start/deploy - 启动服务（默认）"
            echo "  stop         - 停止服务"
            echo "  restart      - 重启服务"
            echo "  status       - 查看服务状态"
            echo "  logs         - 查看日志 [service_name]"
            echo "  clean        - 清理所有数据和容器"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$DEPLOY_DIR/scripts/deploy.sh"
    log_success "一键部署脚本创建完成"
}

# 创建初始化脚本
create_init_script() {
    log_info "创建初始化脚本..."
    
    cat > "$DEPLOY_DIR/init/init.sh" << 'EOF'
#!/bin/bash

# Museum Seek 初始化脚本
# 用于初始化配置和数据

echo "Museum Seek 系统初始化中..."

# 这里可以添加其他初始化逻辑
# 比如：导入初始数据、创建管理员用户等

echo "初始化完成！"
EOF

    chmod +x "$DEPLOY_DIR/init/init.sh"
    log_success "初始化脚本创建完成"
}

# 显示最终信息
show_final_info() {
    echo
    log_success "=========================================="
    log_success "Museum Seek 打包完成！"
    log_success "=========================================="
    echo
    log_info "部署目录结构:"
    tree "$DEPLOY_DIR" -L 3
    echo
    log_info "使用方法:"
    echo "  1. 进入部署目录: cd $(basename $DEPLOY_DIR)"
    echo "  2. 执行部署脚本: ./scripts/deploy.sh"
    echo "  3. 或者手动启动: docker-compose up -d"
    echo
    log_info "配置文件:"
    echo "  - 环境配置: .env"
    echo "  - 容器编排: docker-compose.yml"
    echo "  - 部署脚本: scripts/deploy.sh"
    echo
}

# 主函数
main() {
    echo
    log_info "=========================================="
    log_info "Museum Seek 服务打包脚本"
    log_info "版本: $PROJECT_VERSION"
    log_info "=========================================="
    echo
    
    check_dependencies
    clean_build
    build_backend
    build_frontend
    verify_configs
    log_info "配置文件已存在于 $DEPLOY_DIR 中，无需复制"
    log_success "构建完成！服务已打包到 $DEPLOY_DIR/services/business/"
    log_info "前端文件已复制到 $DEPLOY_DIR/services/common/nginx/web/"
}

# 执行主函数
main "$@"
