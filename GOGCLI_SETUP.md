# gogcli 傻瓜配置指南

> **5 分钟搞定。认证在宿主机完成，容器导入 token 即可，无需浏览器。**

---

## 配置流程（按顺序执行）

### 准备工作

确认服务运行中：

```bash
make status
```

看到 `openclaw-gateway ... Up` 即正常。

---

## 第一步：宿主机安装 gogcli

**在宿主机（新终端窗口）执行：**

```bash
# macOS
brew install gogcli

# Linux
curl -fsSL https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_$(uname -m).tar.gz | sudo tar -xzC /usr/local/bin/
```

安装成功后验证：

```bash
gog version
```

预期输出类似：`v0.12.0 (c18c58c)`

---

## 第二步：注册 Google 凭据

**在宿主机执行：**

```bash
# 把凭据文件路径改成你实际的文件名
gog auth credentials set ~/.openclaw/client_secret_*.json
```

> 找不到凭据文件？确保你在 Google Cloud Console 创建过 OAuth 客户端 ID，类型选"桌面应用"。

---

## 第三步：Google 账号授权

**在宿主机执行：**

```bash
# 改成你的邮箱
gog auth add aaronwong1989@gmail.com --services gmail,calendar,drive,contacts,sheets,docs
```

浏览器会自动打开，登录 Google 账号并点击"允许"。完成后终端会显示成功。

---

## 第四步：导出 token

**在宿主机执行：**

```bash
# 改成你的邮箱
gog auth tokens export aaronwong1989@gmail.com --out ~/.openclaw/gog-token.json --overwrite
```

预期输出：`exported    true`

> 如果提示"没有可用 token"，先执行第三步完成授权。

---

## 第五步：导入 token 到容器

**在宿主机执行（不要进容器）：**

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
mkdir -p ~/.global/bin

# 判断架构并下载
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then ARCH_URL="amd64"; else ARCH_URL="arm64"; fi

curl -fsSL "https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_${ARCH_URL}.tar.gz" | tar -xzC /tmp
mv /tmp/gog ~/.global/bin/gog
chmod +x ~/.global/bin/gog

# 设置 keyring 为文件模式
gog auth keyring file

# 导入 token
gog auth tokens import ~/.openclaw/gog-token.json

echo "安装完成，认证状态："
gog auth list
'
```

预期输出：

```
安装完成，认证状态：
your-email@gmail.com    default    gmail,calendar,...    oauth
```

---

## 第六步：设置密码（重启后自动生效）

**在宿主机执行：**

```bash
# 设置一个密码（随便设，只用于解密本地 token 文件）
echo 'GOG_KEYRING_PASSWORD=随便一个密码' >> ~/.env

# 重启容器
make restart
```

---

## 验证是否成功

```bash
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=你的密码 && gog gmail search "in:inbox" 2>&1 | head -5'
```

预期：看到邮件列表

如果报错看这里：

| 错误信息 | 解决方法 |
|---------|---------|
| `No auth for gmail` | 执行第五步重新导入 token |
| `403 accessNotConfigured` | 在 Google Cloud Console 启用 Gmail API |
| `no TTY available for keyring` | 执行第六步设置 `GOG_KEYRING_PASSWORD` 并重启 |

---

## 日常使用

容器重启后直接用，无需重复配置：

```bash
# 查邮件
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=你的密码 && gog gmail search "in:inbox"'

# 查日历
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=你的密码 && gog calendar list'

# 查 Drive
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=你的密码 && gog drive ls'

# 发邮件
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=你的密码 && gog gmail send --to someone@example.com --subject "Test" --body "Hello"'
```

---

## 卸载（可选）

如果不再需要，从容器中移除：

```bash
docker exec openclaw-gateway runuser -u node -- bash -c 'rm ~/.global/bin/gog ~/.global/bin/gogcli ~/.config/gogcli -rf'
```

宿主机保留 gog 和 token 不影响。

---

## 故障排查

### "gog: command not found"

第五步没执行成功。重新执行第五步。

### "No auth for gmail"

token 没导入成功。执行：

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD=你的密码
gog auth tokens import ~/.openclaw/gog-token.json
'
```

### 403 错误

Google Cloud 项目没开对应 API。打开以下链接，点击"启用"：

- Gmail: https://console.cloud.google.com/apis/library/gmail.googleapis.com
- Calendar: https://console.cloud.google.com/apis/library/calendar-json.googleapis.com
- Drive: https://console.cloud.google.com/apis/library/drive.googleapis.com

等 2-3 分钟再试。

### 容器重启后不能用

检查密码是否设置：

```bash
grep GOG_KEYRING_PASSWORD ~/.env
```

如果没有，执行第六步。
