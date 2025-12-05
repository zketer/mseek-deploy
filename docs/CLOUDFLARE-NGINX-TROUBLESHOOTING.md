# Cloudflare + Nginx 排查指南

## 问题描述

使用 Cloudflare 代理自定义域名时出现 404 错误，但直接使用 IP 访问正常。

## 常见原因

1. **Nginx server_name 配置问题** - 未正确匹配域名
2. **Host 头传递问题** - Cloudflare 代理时 Host 头处理不当
3. **Cloudflare DNS 配置问题** - 代理模式设置错误
4. **SSL/TLS 模式不匹配** - Cloudflare SSL 模式与后端配置不匹配

## 排查步骤

### 1. 运行诊断脚本

```bash
cd mseek-deploy
# 注：诊断脚本已被删除，请手动检查以下步骤
```

### 2. 检查 Nginx 配置

```bash
# 进入 Nginx 容器
docker exec -it mseek-nginx sh

# 测试配置语法
nginx -t

# 查看配置
cat /etc/nginx/conf.d/default.conf | grep server_name
```

### 3. 检查 Cloudflare DNS 配置

在 Cloudflare 控制台检查：

- **DNS 记录**：你的域名是否设置为 **代理状态**（橙色云朵 ☁️）
- **SSL/TLS 模式**：应该设置为 **"灵活"** 或 **"完全"**（不能是"严格"）
  - **灵活**：Cloudflare ↔ 用户（HTTPS），Cloudflare ↔ 服务器（HTTP）
  - **完全**：Cloudflare ↔ 用户（HTTPS），Cloudflare ↔ 服务器（HTTPS）
  - **完全（严格）**：需要服务器有有效 SSL 证书

### 4. 测试请求头

```bash
# 测试域名访问（模拟 Cloudflare 请求）
curl -v -H "Host: your_domain.com" \
     -H "CF-Connecting-IP: your_client_ip" \
     -H "X-Forwarded-Proto: https" \
     http://YOUR_SERVER_IP/

# 查看 Nginx 访问日志
docker exec mseek-nginx tail -f /var/log/nginx/access.log

# 查看 Nginx 错误日志
docker exec mseek-nginx tail -f /var/log/nginx/error.log
```

### 5. 验证配置生效

```bash
# 重新加载 Nginx 配置
docker exec mseek-nginx nginx -s reload

# 或者重启 Nginx 容器
docker restart mseek-nginx
```

## 已修复的配置项

### 1. server_name 配置

**修复前：**
```nginx
server_name _;  # 匹配所有域名
```

**修复后：**
```nginx
server_name your_domain.com _;  # 优先匹配域名
```

### 2. Host 头传递

**修复前：**
```nginx
proxy_set_header Host $host;
```

**修复后：**
```nginx
proxy_set_header Host $http_host;  # 保留原始 Host 头（包含端口）
```

### 3. 真实 IP 获取

**修复前：**
```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

**修复后：**
```nginx
# 在 nginx.conf 中添加 map
map $http_cf_connecting_ip $real_ip {
    default $http_cf_connecting_ip;
    ""      $remote_addr;
}

# 在 default.conf 中使用
proxy_set_header X-Real-IP $real_ip;
proxy_set_header X-Forwarded-For $real_ip;
```

### 4. 协议头传递

**修复前：**
```nginx
proxy_set_header X-Forwarded-Proto $scheme;  # 总是 http
```

**修复后：**
```nginx
# 在 nginx.conf 中添加 map
map $http_cf_connecting_ip $is_cloudflare {
    default 1;
    ""      0;
}

map $is_cloudflare $forwarded_proto {
    default "https";  # Cloudflare 代理时
    0       $scheme;  # 直接访问时
}

# 在 default.conf 中使用
proxy_set_header X-Forwarded-Proto $forwarded_proto;
```

## 快速修复命令

如果问题仍然存在，执行以下命令：

```bash
# 1. 重启 Nginx
docker restart mseek-nginx

# 2. 等待几秒后测试
sleep 5
curl -I -H "Host: your_domain.com" http://YOUR_SERVER_IP/

# 3. 查看日志
docker exec mseek-nginx tail -20 /var/log/nginx/error.log
```

## Cloudflare 配置检查清单

- [ ] DNS 记录设置为代理模式（橙色云朵 ☁️）
- [ ] SSL/TLS 模式设置为"灵活"或"完全"
- [ ] 确保 A 记录指向正确的服务器 IP
- [ ] 检查 Cloudflare 页面规则是否有冲突
- [ ] 确认 Cloudflare 防火墙规则没有阻止请求

## 常见错误示例

### 错误 1: HTTP ERROR 404

**原因**：server_name 未正确匹配域名

**解决**：更新 `server_name` 为 `your_domain.com _;`

### 错误 2: 502 Bad Gateway

**原因**：后端服务未启动或无法连接

**解决**：检查 Gateway 服务状态
```bash
docker ps | grep gateway
docker logs mseek-gateway
```

### 错误 3: SSL 证书错误

**原因**：Cloudflare SSL 模式设置为"完全（严格）"，但服务器没有有效证书

**解决**：将 SSL/TLS 模式改为"灵活"或"完全"

## 验证修复

修复后，测试以下访问方式：

1. **通过域名访问**：`https://your_domain.com/`
2. **通过域名访问 API**：`https://your_domain.com/api/v1/health`
3. **检查响应头**：确认 `X-Forwarded-Proto: https` 正确传递

## 联系支持

如果问题仍未解决，请提供以下信息：

1. 诊断脚本输出
2. Nginx 错误日志（最近 50 行）
3. Cloudflare DNS 配置截图
4. Cloudflare SSL/TLS 模式设置
