# Museum Seek 部署方案

<div align="center">

**Museum Seek 博物馆打卡系统的完整部署工具集**

一键部署、灵活配置、完整监控的生产级部署解决方案

[![Docker](https://img.shields.io/badge/Docker-20.0+-2496ED.svg?logo=docker&logoColor=white)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-2.0+-2496ED.svg?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Bash](https://img.shields.io/badge/Bash-5.0+-4EAA25.svg?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](./LICENSE)

</div>

---

## 📋 项目简介

**Museum Seek 部署方案** 是一套完整的微服务部署工具集，为 Museum Seek 博物馆打卡系统提供一键部署、灵活配置、完整监控等功能。支持本地开发、Docker 容器化部署、生产环境部署等多种场景，通过环境变量灵活控制各服务的启用状态。

### ✨ 核心特色

- 🚀 **一键部署**: 完整的自动化部署脚本，支持交互式配置选择
- 🔧 **灵活配置**: 通过 `ENABLE_*` 变量灵活控制各服务的启用状态
- 📊 **完整监控**: 内置健康检查、日志查看、服务状态监控
- 🔐 **安全管理**: 敏感信息脱敏，支持环境变量管理
- 📦 **多环境支持**: 开发、测试、生产环境预设配置
- 🎯 **资源优化**: 根据启用的服务动态调整资源分配

### 🎯 主要功能

#### 🚀 部署管理
- **一键启动**: 自动化部署脚本，支持交互式配置选择
- **灵活控制**: 通过 `ENABLE_*` 变量控制各服务启用状态
- **配置管理**: 支持多环境配置文件切换
- **服务编排**: Docker Compose 自动编排所有服务

#### 🔧 服务管理
- **启停控制**: 一键启动、停止、重启所有服务
- **状态监控**: 实时查看服务运行状态
- **日志查看**: 快速查看各服务日志
- **健康检查**: 内置服务健康检查机制

#### 📊 监控维护
- **性能监控**: 系统资源使用情况监控
- **数据备份**: 自动化数据备份脚本
- **日志管理**: 完整的日志收集和管理
- **故障诊断**: 内置诊断工具快速定位问题

## 🏗️ 系统架构

```
Museum Seek 系统
├── 基础设施层
│   ├── MySQL 8.0          # 数据库
│   ├── Redis 7.0          # 缓存
│   ├── Nacos 2.2.3        # 注册中心/配置中心
│   └── MinIO              # 对象存储
├── 应用服务层
│   ├── Gateway Service    # API网关 (8000)
│   ├── Auth Service       # 认证服务 (8001)
│   ├── User Service       # 用户服务 (8002)
│   ├── Museum Service     # 博物馆服务 (8003)
│   └── File Service       # 文件服务 (8004)
└── 前端展示层
    ├── Admin UI           # 管理后台 (8080)
    └── WeChat Mini App    # 微信小程序
```

## 🚀 快速开始

### 📦 环境要求

| 工具/环境 | 版本要求 | 说明 |
|---------|---------|------|
| Docker | 20.0+ | 容器运行时 |
| Docker Compose | 2.0+ | 容器编排工具 |
| Bash | 5.0+ | 脚本执行环境 |
| nc (netcat) | 任意版本 | 端口检查工具（可选） |

### 🔧 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/zketer/mseek-deploy.git
   cd mseek-deploy
   ```

2. **配置环境**
   ```bash
   # 复制示例配置文件
   cp config/prod.example.env config/prod.env
   
   # 编辑配置文件，填入实际的敏感信息
   vim config/prod.env
   ```

3. **启动部署**
   ```bash
   # 赋予脚本执行权限
   chmod +x scripts/deploy.sh
   
   # 启动服务（交互式选择配置）
   ./scripts/deploy.sh start
   ```

### 🌐 服务访问

部署完成后，可通过以下地址访问：

| 服务 | 地址 | 说明 |
|------|------|------|
| 前端管理界面 | http://localhost:80 | 管理后台 |
| API网关 | http://localhost:8000 | 微服务网关 |
| 认证服务 | http://localhost:8001 | 用户认证 |
| 用户服务 | http://localhost:8002 | 用户管理 |
| 博物馆服务 | http://localhost:8003 | 核心业务 |
| 文件服务 | http://localhost:8004 | 文件上传 |

> ⚠️ **重要**: 敏感信息（密码、密钥）已脱敏，请参考 `config/prod.example.env` 文件配置实际值。生产环境必须修改所有默认密码。

---

## 🔧 技术栈

### 部署工具

| 技术 | 说明 | 版本 |
|-----|------|------|
| Docker | 容器运行时 | 20.0+ |
| Docker Compose | 容器编排工具 | 2.0+ |
| Bash | 脚本执行环境 | 5.0+ |
| Netcat | 端口检查工具 | 任意 |

### 基础设施

| 技术 | 说明 | 版本 |
|-----|------|------|
| MySQL | 关系型数据库 | 8.0 |
| Redis | 缓存数据库 | 7.0+ |
| Nacos | 注册中心/配置中心 | 2.2.3+ |
| MinIO | 对象存储服务 | 最新 |
| Nginx | Web 服务器 | Alpine |

### 业务服务

| 技术 | 说明 | 版本 |
|-----|------|------|
| Java | 编程语言 | 17+ |
| Spring Boot | 应用框架 | 3.0+ |
| Spring Cloud | 微服务框架 | 2022.0.1+ |
| MyBatis Plus | ORM 框架 | 3.5+ |

## 📋 脚本说明

### deploy.sh - 部署管理脚本

**功能**: 一键部署、启停服务、查看状态、管理配置

**常用命令**:

```bash
# 启动服务（交互式选择配置）
./scripts/deploy.sh start

# 停止服务
./scripts/deploy.sh stop

# 重启服务
./scripts/deploy.sh restart

# 查看服务状态
./scripts/deploy.sh status

# 查看服务日志
./scripts/deploy.sh logs [service_name]

# 清理所有数据和容器
./scripts/deploy.sh clean

# 重新配置部署选项
./scripts/deploy.sh config

# 显示帮助信息
./scripts/deploy.sh help
```

**部署计划预览**:

脚本会在启动前显示部署计划，包括：
- 各基础设施服务的启用状态
- 业务服务的部署方式
- 资源需求评估
- 等待用户确认后执行

### 其他脚本

详细的脚本说明请参考 `scripts/README.md`：

- **build-and-package.sh** - 构建打包脚本
- **build-flutter-android.sh** - Flutter Android 打包
- **cleanup-macos-files.sh** - macOS 文件清理
- **check-external-services.sh** - 外部服务检查
- **diagnose.sh** - 诊断脚本

## 📁 项目结构

```
mseek-deploy/
├── scripts/                    # 部署脚本
│   ├── deploy.sh              # 一键部署脚本（主要）
│   ├── build-and-package.sh   # 构建打包脚本
│   ├── build-flutter-android.sh  # Flutter Android 打包
│   ├── cleanup-macos-files.sh # macOS 文件清理
│   ├── check-external-services.sh  # 外部服务检查
│   ├── diagnose.sh            # 诊断脚本
│   └── README.md              # 脚本详细说明
├── config/                    # 配置文件目录
│   └── prod.example.env       # 生产环境配置模板
├── docker-compose.yml         # Docker Compose 配置
├── services/                  # 服务配置
│   ├── business/              # 业务服务配置
│   └── common/                # 通用配置（MySQL、Nginx等）
├── claudeflare/               # Cloudflare 隧道配置
├── data/                      # 数据目录（运行时创建）
├── logs/                      # 日志目录（运行时创建）
├── LICENSE                    # Apache 2.0 许可证
└── README.md                  # 本文档
```


## ⚙️ 配置说明

### 环境配置文件

系统使用 `.env` 文件管理配置，示例文件位置：

- `config/prod.example.env` - 生产环境配置模板

**配置步骤**：

1. 复制示例文件：
   ```bash
   cp config/prod.example.env config/prod.env
   ```

2. 编辑配置文件，填入实际的敏感信息：
   ```bash
   # 数据库配置
   MYSQL_ROOT_PASSWORD=your_mysql_root_password
   DB_USERNAME=your_db_username
   DB_PASSWORD=your_db_password
   
   # Redis 配置
   REDIS_HOST=your_redis_host
   REDIS_PASSWORD=your_redis_password
   
   # 其他敏感配置...
   ```

3. 启动部署时自动加载配置

### Docker环境配置

每个服务都有对应的 `application-docker.yml` 配置文件：

- `auth-service/src/main/resources/application-docker.yml`
- `gateway-service/src/main/resources/application-docker.yml`
- `user-service/src/main/resources/application-docker.yml`
- `museum-service/src/main/resources/application-docker.yml`
- `file-service/src/main/resources/application-docker.yml`

### 端口分配

| 服务 | 端口 | 描述 |
|------|------|------|
| Gateway | 8000 | API网关 |
| Auth | 8001 | 认证服务 |
| User | 8002 | 用户服务 |
| Museum | 8003 | 博物馆服务 |
| File | 8004 | 文件服务 |
| Frontend | 8080 | 前端界面 |
| MySQL | 3306 | 数据库 |
| Redis | 6379 | 缓存 |
| Nacos | 8848 | 注册中心 |
| MinIO | 9000/9001 | 对象存储 |

### 数据库配置

系统使用 MySQL 8.0，包含以下数据库：

- `museum_auth` - 认证服务数据库
- `museum_user` - 用户服务数据库
- `museum_info` - 博物馆信息数据库
- `museum_file` - 文件服务数据库
- `nacos_config` - Nacos配置数据库

## 🔍 故障排除

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tulpn | grep :8000
   
   # 停止冲突进程
   sudo kill -9 <pid>
   ```

2. **Docker镜像缺失**
   ```bash
   # 拉取所需镜像
   docker pull mysql:8.0
   docker pull redis:7-alpine
   docker pull nacos/nacos-server:latest
   docker pull quay.io/minio/minio:latest
   ```

3. **权限问题**
   ```bash
   # 修复脚本权限
   chmod +x deployment/scripts/*.sh
   
   # 修复数据目录权限
   sudo chown -R $USER:$USER deployment/data
   ```

4. **服务启动失败**
   ```bash
   # 查看服务日志
   cd deployment
   docker-compose logs [service_name]
   
   # 重启服务
   docker-compose restart [service_name]
   ```

### 日志查看

```bash
# 查看所有服务日志
cd deployment
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f auth-service

# 查看应用日志文件
tail -f deployment/logs/auth/auth-service.log
```

## 🔄 更新升级

### 应用更新

```bash
# 1. 停止服务
./deployment/scripts/deploy.sh stop

# 2. 备份数据
cp -r deployment/data deployment/data.backup.$(date +%Y%m%d)

# 3. 更新代码
git pull origin main

# 4. 重新部署
./deployment/scripts/deploy.sh
```

### 配置更新

```bash
# 更新配置后重启相关服务
cd deployment
docker-compose restart [service_name]
```

## 📊 监控和维护

### 健康检查

所有服务都配置了健康检查端点：

- Gateway: http://localhost:8000/actuator/health
- Auth: http://localhost:8001/api/v1/auth/actuator/health
- User: http://localhost:8002/api/v1/users/actuator/health
- Museum: http://localhost:8003/api/v1/museums/actuator/health
- File: http://localhost:8004/api/v1/files/actuator/health

### 性能监控

```bash
# 查看系统资源使用
docker stats

# 查看服务状态
cd deployment
docker-compose ps
```

### 数据备份

```bash
# 备份MySQL数据
docker exec museumseek-mysql mysqldump -u $DB_USERNAME -p$DB_PASSWORD --all-databases > backup.sql

# 备份Redis数据
docker exec museumseek-redis redis-cli BGSAVE

# 备份MinIO数据
cp -r deployment/data/minio deployment/data/minio.backup.$(date +%Y%m%d)
```

> 💡 **提示**: 使用环境变量 `$DB_USERNAME` 和 `$DB_PASSWORD` 替代硬编码密码。

## 🔐 安全建议

### 生产环境部署

1. **修改默认密码**
   - 修改 MySQL root 密码
   - 修改 Redis 密码
   - 修改 Nacos 用户密码
   - 修改 MinIO 访问密钥

2. **环境变量管理**
   - 不要将 `.env` 文件提交到版本控制
   - 使用 `.gitignore` 排除敏感文件
   - 在生产环境使用密钥管理服务

3. **网络安全**
   - 配置防火墙规则
   - 使用 HTTPS/TLS 加密通信
   - 限制服务访问 IP 范围

4. **定期维护**
   - 定期备份数据
   - 及时更新依赖版本
   - 监控系统日志和性能指标

## 🤝 技术支持

如遇到问题，请按以下顺序排查：

1. 查看服务日志
2. 检查端口占用
3. 验证配置文件
4. 重启相关服务
5. 联系技术支持

---

## 📚 相关文档

### 项目文档

- **部署脚本说明**: [docs/SCRIPTS.md](./docs/SCRIPTS.md)
- **Flutter 打包指南**: [docs/FLUTTER-BUILD.md](./docs/FLUTTER-BUILD.md)
- **Cloudflare + Nginx 排查**: [docs/CLOUDFLARE-NGINX-TROUBLESHOOTING.md](./docs/CLOUDFLARE-NGINX-TROUBLESHOOTING.md)
- **配置文件示例**: [config/prod.example.env](./config/prod.example.env)
- **Docker Compose 配置**: [docker-compose.yml](./docker-compose.yml)

### 外部资源

| 资源 | 链接 | 说明 |
|-----|------|------|
| Docker 官方文档 | [查看](https://docs.docker.com/) | Docker 使用指南 |
| Docker Compose 文档 | [查看](https://docs.docker.com/compose/) | 容器编排工具 |
| Bash 脚本教程 | [查看](https://www.gnu.org/software/bash/manual/) | Bash 参考手册 |
| Spring Boot 文档 | [查看](https://spring.io/projects/spring-boot) | 应用框架文档 |

---

## 🤝 贡献指南

欢迎贡献代码、提出问题和建议！

### 贡献流程

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: 添加某个功能'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

### 问题反馈

- 🐛 **Bug 反馈**: [提交 Issue](https://github.com/zketer/mseek-deploy/issues)
- 💡 **功能建议**: [提交 Issue](https://github.com/zketer/mseek-deploy/issues)
- 💬 **技术讨论**: [GitHub Discussions](https://github.com/zketer/mseek-deploy/discussions)

---

## 👥 开发团队

- **项目维护**: lynn
- **联系邮箱**: museumseek@163.com
- **GitHub**: [@zketer](https://github.com/zketer)

---

## 📄 开源协议

本项目采用 Apache License 2.0 许可证 - 详见 [LICENSE](./LICENSE) 文件

---

<div align="center">

**Museum Seek 部署方案**

探索文化 · 记录足迹 · 分享美好

Made with ❤️ by lynn

---

**最后更新**: 2025-12-05  
**当前版本**: v1.0.0

</div>