# Flutter Android 打包脚本使用指南

## 📱 脚本概述

`build-flutter-android.sh` 是用于自动化打包 Flutter Android 应用的脚本，支持多种构建模式和输出格式。

## 🚀 快速开始

### 基本用法

```bash
# 构建发布版 APK（推荐）
./build-flutter-android.sh

# 构建调试版 APK
./build-flutter-android.sh --mode debug

# 构建发布版 AAB（Google Play推荐）
./build-flutter-android.sh --type appbundle

# 清理缓存后构建
./build-flutter-android.sh --clean --mode release
```

## 📋 参数说明

### 构建模式 (-m, --mode)

| 模式 | 说明 | 文件大小 | 适用场景 |
|------|------|----------|----------|
| `release` | 发布模式，代码优化 | 最小 | 正式发布 |
| `debug` | 调试模式，包含调试信息 | 最大 | 开发测试 |
| `profile` | 性能分析模式 | 中等 | 性能测试 |

### 构建类型 (-t, --type)

| 类型 | 说明 | 输出文件 | 适用场景 |
|------|------|----------|----------|
| `apk` | Android 安装包 | `.apk` | 直接安装、第三方应用商店 |
| `appbundle` | Android App Bundle | `.aab` | Google Play 发布 |

### 其他选项

| 选项 | 说明 |
|------|------|
| `-p, --path PATH` | 指定 Flutter 项目路径 |
| `-c, --clean` | 清理构建缓存 |
| `-h, --help` | 显示帮助信息 |

## 🎯 使用示例

### 1. 发布到 Google Play
```bash
# 清理缓存并构建 AAB 文件
./build-flutter-android.sh --clean --mode release --type appbundle
```

### 2. 内部测试 APK
```bash
# 构建调试版 APK 用于内部测试
./build-flutter-android.sh --mode debug --type apk
```

### 3. 性能分析版本
```bash
# 构建性能分析版本用于测试
./build-flutter-android.sh --mode profile --type apk
```

### 4. 自定义项目路径
```bash
# 指定不同的 Flutter 项目路径
./build-flutter-android.sh --path /path/to/your/flutter/project --mode release
```

## 📂 输出文件位置

### APK 文件
```
mseek-mobile/build/app/outputs/flutter-apk/
├── app-release.apk          # 发布版
├── app-debug.apk            # 调试版
└── app-profile.apk          # 性能分析版
```

### AAB 文件
```
mseek-mobile/build/app/outputs/bundle/release/
└── app-release.aab          # Android App Bundle
```

## ⚙️ 环境准备

### 系统要求

- **Flutter**: 2.0+ (推荐最新稳定版)
- **Dart**: 与 Flutter 版本匹配
- **Android SDK**: API 21+ (Android 5.0+)
- **Java**: JDK 11+

### 环境检查

脚本会自动检查：
- ✅ Flutter 是否安装
- ✅ 项目路径是否存在
- ✅ pubspec.yaml 文件是否存在

## 🔧 配置要求

### 1. Android 配置 (android/app/build.gradle)

```gradle
android {
    defaultConfig {
        applicationId "com.your_company.your_app"  // 替换为你的应用ID
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 1                   // 每次发布递增
        versionName "1.0.0"            // 版本号
    }
}
```

### 2. 签名配置 (发布版本需要)

创建 `android/key.properties` 文件：
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=../key.jks
```

### 3. Flutter 配置 (pubspec.yaml)

确保应用信息正确：
```yaml
name: your_app_name
description: 你的应用描述
version: 1.0.0+1

environment:
  sdk: '>=2.19.0 <4.0.0'
  flutter: ">=3.7.0"
```

## 📋 发布检查清单

### 构建前检查
- [ ] Flutter 环境正常 (`flutter doctor`)
- [ ] 依赖已更新 (`flutter pub get`)
- [ ] 应用ID 配置正确
- [ ] 版本号已更新
- [ ] 签名文件准备就绪

### 构建后检查
- [ ] APK/AAB 文件生成成功
- [ ] 文件大小合理
- [ ] 应用图标正确
- [ ] 权限配置完整
- [ ] 测试功能正常

## 🐛 故障排除

### 常见问题

#### 1. 构建失败
```bash
# 查看详细错误信息
flutter build apk --verbose

# 清理重新构建
flutter clean && flutter pub get
```

#### 2. 签名错误
```bash
# 检查签名配置
cat android/key.properties

# 验证签名文件
keytool -list -v -keystore android/app/key.jks
```

#### 3. 依赖问题
```bash
# 清理依赖缓存
flutter pub cache clean

# 重新获取依赖
flutter pub get
```

### 日志分析

脚本会输出详细的构建信息，包括：
- Flutter 版本信息
- 项目配置信息
- 构建进度和结果
- 输出文件信息

## 📈 最佳实践

### 1. 版本管理
- 使用语义化版本号 (major.minor.patch)
- 每次发布递增 versionCode
- 记录版本变更日志

### 2. 构建策略
- **开发阶段**: 使用 debug 模式快速迭代
- **测试阶段**: 使用 profile 模式进行性能测试
- **发布阶段**: 使用 release 模式优化包体积

### 3. 分发策略
- **内部测试**: APK 直接安装
- **Google Play**: AAB 格式发布
- **第三方商店**: APK 格式发布

## 🔗 相关文档

- [Flutter 官方打包指南](https://docs.flutter.dev/deployment/android)
- [Android App Bundle 文档](https://developer.android.com/guide/app-bundle)
- [Google Play 发布指南](https://support.google.com/googleplay/android-developer)

---

**脚本版本**: v1.0.0
**最后更新**: 2024-01-15
**维护者**: lynn
