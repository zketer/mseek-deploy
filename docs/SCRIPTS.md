# 部署脚本说明

本目录包含部署和维护相关的脚本工具。

---

## 📁 脚本列表

### 1. deploy.sh - 部署管理脚本

**功能**: 一键部署、管理服务

**用法**:
```bash
# 启动服务（交互式选择配置）
./scripts/deploy.sh start

# 使用指定配置启动
./scripts/deploy.sh start dev             # 开发环境
./scripts/deploy.sh start test            # 测试环境  
./scripts/deploy.sh start prod            # 生产环境（混合）
./scripts/deploy.sh start prod-external   # 生产环境（全外部）

# 停止服务
./scripts/deploy.sh stop

# 重启服务
./scripts/deploy.sh restart

# 查看状态
./scripts/deploy.sh status

# 查看日志
./scripts/deploy.sh logs [service_name]

# 清理所有数据
./scripts/deploy.sh clean

# 重新配置
./scripts/deploy.sh config
```

---

### 2. build-and-package.sh - 构建打包脚本

**功能**: 编译后端、构建前端、打包到 deploy-mseek

**用法**:
```bash
# 完整构建
./scripts/build-and-package.sh
```

**执行流程**:
1. 检查依赖（Java 17+, Maven, Node.js）
2. 清理旧构建
3. 编译后端（Maven）
4. 构建前端（yarn/npm）
5. 验证配置文件

---

### 3. build-flutter-android.sh - Flutter Android 打包脚本

**功能**: 自动化打包 Flutter Android 应用，支持多种构建模式

**支持的构建类型**:
- **APK**: Android 安装包 (直接安装)
- **AAB**: Android App Bundle (Google Play 推荐)

**支持的构建模式**:
- **release**: 发布模式，代码优化，文件最小
- **debug**: 调试模式，包含调试信息
- **profile**: 性能分析模式

**用法**:
```bash
# 构建发布版 APK（推荐）
./scripts/build-flutter-android.sh

# 构建发布版 AAB（Google Play 发布）
./scripts/build-flutter-android.sh --type appbundle

# 构建调试版 APK（开发测试）
./scripts/build-flutter-android.sh --mode debug

# 清理缓存后构建
./scripts/build-flutter-android.sh --clean --mode release

# 指定项目路径
./scripts/build-flutter-android.sh --path /path/to/flutter/project

# 查看帮助
./scripts/build-flutter-android.sh --help
```

**环境要求**:
- Flutter SDK (2.0+)
- Android SDK (API 21+)
- Java JDK 11+

**输出位置**:
- APK: `your_project/build/app/outputs/flutter-apk/`
- AAB: `your_project/build/app/outputs/bundle/release/`

---

### 4. cleanup-macos-files.sh - macOS文件清理脚本

**功能**: 清理 macOS 打包生成的临时文件和系统文件

**清理的文件类型**:
- `._*` - 资源分支文件（Resource Fork）
- `.DS_Store` - Finder 配置文件
- `.AppleDouble/` - AppleDouble 目录
- `.LSOverride` - 启动服务覆盖文件
- `__MACOSX/` - macOS 元数据目录
- `Thumbs.db` - Windows 缩略图缓存
- `.Trashes/` - 回收站目录

**用法**:
```bash
# 交互模式（默认）- 扫描后需要确认
bash ./scripts/cleanup-macos-files.sh

# 仅扫描模式 - 只显示统计，不清理
bash ./scripts/cleanup-macos-files.sh scan

# 强制清理模式 - 直接清理，不确认
bash ./scripts/cleanup-macos-files.sh clean

# 自动模式 - 扫描并自动清理
bash ./scripts/cleanup-macos-files.sh auto

# 显示帮助
bash ./scripts/cleanup-macos-files.sh help
```

**示例输出**:
```
╔════════════════════════════════════════════════╗
║     macOS 系统文件清理工具                    ║
║     Version: 1.0.0                             ║
╚════════════════════════════════════════════════╝

[INFO] 扫描 macOS 系统文件...

扫描结果:
────────────────────────────────────────────────────────────────
文件类型                                 数量       大小
────────────────────────────────────────────────────────────────
资源分支文件 (._*)                           15      120KB
Finder 配置文件 (.DS_Store)                   8       48KB
__MACOSX 目录 (__MACOSX)                      2      500KB
────────────────────────────────────────────────────────────────
总计                                           25      668KB
────────────────────────────────────────────────────────────────
```

**注意事项**:
- ⚠️ 必须使用 `bash` 执行（不支持 zsh）
- ⚠️ 清理操作不可逆，建议先使用 `scan` 模式查看
- ✅ 这些文件通常由 Finder/压缩工具自动生成
- ✅ 清理这些文件不会影响正常功能

---

## 🎯 常见使用场景

### 场景1: 首次部署

```bash
# 1. 构建项目
cd /path/to/museum-management
./deploy-mseek/scripts/build-and-package.sh

# 2. 部署服务
cd deploy-mseek
./scripts/deploy.sh start dev
```

### 场景2: 更新代码后重新部署

```bash
# 1. 重新构建
./deploy-mseek/scripts/build-and-package.sh

# 2. 重启服务
cd deploy-mseek
./scripts/deploy.sh restart
```

### 场景3: 切换部署配置

```bash
# 从开发环境切换到生产环境
./scripts/deploy.sh stop
./scripts/deploy.sh start prod
```

### 场景4: 准备提交代码前清理

```bash
# 清理macOS系统文件
bash ./scripts/cleanup-macos-files.sh auto

# 检查Git状态
git status

# 提交代码
git add .
git commit -m "清理系统文件"
```

### 场景5: 完全清理重新开始

```bash
# 清理所有Docker数据
./scripts/deploy.sh clean

# 清理macOS系统文件
bash ./scripts/cleanup-macos-files.sh auto

# 重新部署
./scripts/deploy.sh start dev
```

---

## 🔧 故障排查

### 问题1: deploy.sh 执行失败

**检查**:
```bash
# 检查权限
ls -l scripts/deploy.sh
# 应该显示 -rwxr-xr-x

# 如果没有执行权限
chmod +x scripts/deploy.sh
```

### 问题2: cleanup-macos-files.sh 报错

**解决**:
```bash
# 必须使用 bash 执行
bash ./scripts/cleanup-macos-files.sh

# 而不是
./scripts/cleanup-macos-files.sh  # 可能会用zsh执行
```

### 问题3: build-and-package.sh 编译失败

**检查依赖**:
```bash
# 检查Java版本
java -version  # 需要17+

# 检查Maven
mvn -version

# 检查Node.js
node --version
```

---

## 📝 维护建议

### 定期清理

```bash
# 每周清理一次macOS系统文件
bash ./scripts/cleanup-macos-files.sh auto

# 每月清理一次Docker未使用的资源
docker system prune -a
```

### 日志管理

```bash
# 查看日志大小
du -sh logs/

# 清理旧日志（可选）
find logs/ -name "*.log" -mtime +30 -delete
```

### 数据备份

```bash
# 备份MySQL数据
docker exec your_mysql_container mysqldump -uroot -p your_database > backup.sql

# 备份配置文件
tar -czf config-backup.tar.gz config/
```

---

## 🎯 最佳实践

1. **提交代码前**: 运行 `cleanup-macos-files.sh auto`
2. **定期更新**: 每次更新代码后重新构建和部署
3. **配置管理**: 使用预设配置，避免手动修改
4. **日志监控**: 定期查看服务日志，及时发现问题
5. **备份重要数据**: 定期备份MySQL数据和配置文件

---

**版本**: 2.2.0
**最后更新**: 2024-01-15
