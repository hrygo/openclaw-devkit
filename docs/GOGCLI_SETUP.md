# gogcli (Google Workspace CLI) 可选配置指南

> **目标**：在容器内安装 gogcli 并配置 Google 账号认证，使 AI Agent 能够访问 Gmail、Calendar、Drive、Sheets、Docs 等 Google Workspace 数据。
>
> **适用场景**：需要让 OpenClaw Agent 操作你的 Google 数据的用户。
>
> **是否为必选配置**：否（可选）
>
> **设计原则**：Google 账号认证在**宿主机**完成，通过导出/导入 refresh token 传递给容器，**容器内无需浏览器授权**。

---

## 功能概览

gogcli ([steipete/gogcli](https://github.com/steipete/gogcli)) 是 Google Workspace CLI 工具，支持：

| 服务 | 功能 |
|------|------|
| Gmail | 搜索、发送、标记、管理邮件 |
| Calendar | 列出/创建/修改日程事件 |
| Drive | 浏览、上传、下载文件 |
| Sheets | 读写电子表格 |
| Docs | 读取、编辑 Google 文档 |
| Contacts | 管理通讯录 |

---

## 前置条件

### 1. 拥有 Google OAuth 凭据

需要已创建好的 Google OAuth 2.0 客户端凭据（`client_id` + `client_secret`）：

1. 访问 [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. 创建 **Desktop App** 类型的 OAuth Client ID（或使用已有的凭据）
3. 下载 JSON 文件，保存到宿主机 `~/.openclaw/` 目录
4. 文件命名格式：`client_secret_<client_id>.json`

### 2. 启用 Google API

在 [Google Cloud Console](https://console.cloud.google.com/apis/library) 为项目启用所需 API：

- Gmail API
- Google Calendar API
- Google Drive API
- Google Sheets API
- Google Docs API
- Google People API（通讯录）
- Google Contacts API

> **提示**：如果只使用部分服务，只需启用对应的 API 即可。

---

## 配置步骤

### 第 1 步：确保 openclaw-devkit 运行中

```bash
make status
```

确认容器状态为 `Up`。

---

### 第 2 步：在宿主机完成 gogcli 认证

> **推荐**：在宿主机完成认证后导出 token，导入到容器。这样可以避免容器内进行浏览器授权。

#### 2.1 安装 gogcli（宿主机）

```bash
# macOS
brew install gogcli

# Linux
curl -fsSL https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_$(uname -m).tar.gz | tar -xzC /tmp
sudo mv /tmp/gog /usr/local/bin/gog
sudo chmod +x /usr/local/bin/gog
```

#### 2.2 注册 OAuth 凭据

```bash
gog auth credentials set ~/.openclaw/client_secret_<your-client-id>.json
```

#### 2.3 授权 Google 账号

```bash
gog auth add <your-email@gmail.com> --services gmail,calendar,drive,contacts,sheets,docs
```

浏览器会打开授权页面，完成授权后返回。

#### 2.4 导出 refresh token

```bash
gog auth tokens export <your-email@gmail.com> --out /tmp/gog-token.json --overwrite
```

导出的文件包含 refresh token，后续导入容器时使用。

---

### 第 3 步：导入 token 到容器

#### 3.1 复制 token 文件到 .openclaw 目录

```bash
cp /tmp/gog-token.json ~/.openclaw/gog-token-export.json
```

#### 3.2 进入容器安装 gogcli

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
mkdir -p ~/.global/bin

# 下载 gogcli（根据架构选择）
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_URL="amd64"
else
    ARCH_URL="arm64"
fi

curl -fsSL "https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_${ARCH_URL}.tar.gz" | tar -xzC /tmp
mv /tmp/gog ~/.global/bin/gog
chmod +x ~/.global/bin/gog

# 创建别名（可选，保持与宿主机命令一致）
ln -sf ~/.global/bin/gog ~/.global/bin/gogcli

echo "gog version:"
~/.global/bin/gog version
'
```

#### 3.3 设置 keyring 密码

容器内使用文件存储 keyring，需要设置解密密码：

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
# 创建密钥目录
mkdir -p ~/.config/gogcli

# 切换为文件 keyring
gog auth keyring file

# 导入 token（将 <your-password> 替换为你设置的密码）
export GOG_KEYRING_PASSWORD="<your-password>"
echo "{" > /tmp/token.json
echo "  \"email\": \"<your-email@gmail.com>\"," >> /tmp/token.json
echo "  \"client\": \"default\"," >> /tmp/token.json
echo "  \"services\": [\"calendar\",\"contacts\",\"docs\",\"drive\",\"gmail\",\"sheets\"]," >> /tmp/token.json
echo "  \"scopes\": [\"email\",\"https://www.googleapis.com/auth/calendar\",\"https://www.googleapis.com/auth/contacts\",\"https://www.googleapis.com/auth/contacts.other.readonly\",\"https://www.googleapis.com/auth/directory.readonly\",\"https://www.googleapis.com/auth/documents\",\"https://www.googleapis.com/auth/drive\",\"https://www.googleapis.com/auth/gmail.modify\",\"https://www.googleapis.com/auth/gmail.settings.basic\",\"https://www.googleapis.com/auth/gmail.settings.sharing\",\"https://www.googleapis.com/auth/spreadsheets\",\"https://www.googleapis.com/auth/userinfo.email\",\"openid\"]," >> /tmp/token.json

# 从导出的 token 文件中提取 refresh_token（手动复制token值）
# refresh_token 从 ~/.openclaw/gog-token-export.json 中获取
echo "  \"refresh_token\": \"<从 gog-token-export.json 中提取的 refresh_token>\"" >> /tmp/token.json
echo "}" >> /tmp/token.json

gog auth tokens import /tmp/token.json
'
```

#### 3.4 简化导入（推荐）

直接从宿主机复制的 token 文件导入：

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD="<your-password>"

# 切换为文件 keyring
gog auth keyring file

# 直接导入（gog-token-export.json 已挂载到 ~/.openclaw/）
gog auth tokens import ~/.openclaw/gog-token-export.json

# 验证
gog auth list
'
```

---

### 第 4 步：配置环境变量（持久化）

#### 4.1 添加到 .env

```bash
echo 'GOG_KEYRING_PASSWORD=<your-password>' >> ~/.env
```

#### 4.2 确认 docker-compose.yml 包含环境变量

检查 `docker-compose.yml` 中是否有：

```yaml
environment:
  GOG_KEYRING_PASSWORD: ${GOG_KEYRING_PASSWORD:-}
```

> openclaw-devkit 已预置此配置，无需手动添加。

#### 4.3 重启容器使配置生效

```bash
make restart
```

---

### 第 5 步：验证配置

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD="<your-password>"

echo "=== 认证状态 ==="
gog auth status

echo ""
echo "=== Gmail 测试 ==="
gog gmail search "in:inbox" -n 3

echo ""
echo "=== Calendar 测试 ==="
gog calendar list

echo ""
echo "=== Drive 测试 ==="
gog drive ls -n 5
'
```

预期输出示例：

```
=== 认证状态 ===
config_path    /home/node/.config/gogcli/config.json
keyring_backend    file
account    your-email@gmail.com
client    default

=== Gmail 测试 ===
ID    DATE    FROM    SUBJECT    LABELS    THREAD
xxx    2026-03-21    xxx@example.com    Test Email    INBOX    -

=== Calendar 测试 ===
No events

=== Drive 测试 ===
ID    NAME    TYPE    SIZE    MODIFIED
xxx    My Document    file    1.0 KB    2026-03-10
```

---

## 容器内使用方式

### 直接使用

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD="<your-password>"
gog <command>
'
```

### 通过 Makefile 简化

在 `Makefile` 中添加快捷命令（可选）：

```makefile
gog:
	docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD="${GOG_KEYRING_PASSWORD}" && gog $(filter-out $@,$(MAKECMDGOALS))'

gog-gmail:
	docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD="${GOG_KEYRING_PASSWORD}" && gog gmail $(filter-out $@,$(MAKECMDGOALS))'
```

### 通过 OpenClaw Agent 使用

在 Claude Code 或其他 AI Agent 中，可以直接对话：

```
请帮我查看最近一周的 Gmail 邮件
帮我创建一个日历事件：明天下午3点开会
列出我的 Google Drive 文件
```

---

## 故障排除

### "No auth for gmail" 错误

**原因**：keyring 密码未设置或 token 未正确导入。

**解决**：

```bash
# 检查认证状态
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD="<your-password>"
gog auth status
'

# 检查 keyring 是否存在
docker exec openclaw-gateway runuser -u node -- bash -c '
ls -la ~/.config/gogcli/keyring/
'
```

### "Google API error (403)" 错误

**原因**：Google Cloud 项目中未启用对应 API。

**解决**：在 [Google Cloud Console](https://console.cloud.google.com/apis/library) 启用对应 API，等待几分钟后重试。

### 重启后认证失效

**原因**：环境变量 `GOG_KEYRING_PASSWORD` 未持久化。

**解决**：

```bash
# 确认 .env 中有密码
grep GOG_KEYRING_PASSWORD ~/.env

# 如果没有，添加
echo 'GOG_KEYRING_PASSWORD=<your-password>' >> ~/.env

# 重启容器
make restart
```

### "no TTY available for keyring file backend password prompt"

**原因**：容器内需要设置 `GOG_KEYRING_PASSWORD` 环境变量。

**解决**：确认 `.env` 文件中有密码，然后重启容器。

---

## 数据存储位置

| 数据 | 容器内路径 | 持久化方式 |
|------|-----------|-----------|
| gogcli 二进制 | `~/.global/bin/gog` | 命名卷 `openclaw-devkit-home` |
| gog 配置 | `~/.config/gogcli/` | 命名卷 `openclaw-devkit-home` |
| keyring (token) | `~/.config/gogcli/keyring/` | 命名卷 `openclaw-devkit-home` |
| OAuth 凭据 | `~/.config/gogcli/credentials.json` | 命名卷 `openclaw-devkit-home` |
| 环境变量 | `GOG_KEYRING_PASSWORD` | `.env` + `docker-compose.yml` |

> **注意**：所有数据存储在 Docker 命名卷中，容器重建后仍保留。token 文件（`gog-token-export.json`）仅作为导入媒介，后续无需保留。

---

## 安全建议

1. **保护 refresh token**：refresh token 可以长期使用，妥善保管 `.env` 文件中的 `GOG_KEYRING_PASSWORD`。
2. **定期轮换**：如发现异常访问，在 Google 账号安全设置中撤销访问权限，然后重新认证。
3. **最小权限**：只授权必要的 Google API 服务范围。
