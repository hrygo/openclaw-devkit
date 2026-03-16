# 飞书 (Feishu/Lark) 机器人快速配置指南

> **快速入门**：7 步完成飞书机器人接入 openclaw-devkit（约 10 分钟）

---

## 官方文档

对于完整的配置参考、高级功能和故障排除，请查阅 **OpenClaw 官方文档**：

- 📖 [飞书渠道配置（中文）](https://docs.openclaw.ai/zh-CN/channels/feishu)
- 📖 [Feishu Channel (English)](https://docs.openclaw.ai/channels/feishu)

官方文档包含：
- 完整配置项参考
- 配额优化（typingIndicator、resolveSenderNames）
- 访问控制策略（私聊配对、群组白名单）
- 多账号配置
- 多 Agent 路由
- 流式输出与消息引用
- 完整故障排除指南

---

## 快速入门（7 步配置）

### 前置条件

确保 openclaw-devkit 服务正常运行：

```bash
make status
```

预期输出：
```
【容器】
  openclaw-gateway: Up X hours
【访问】 http://127.0.0.1:18789/
```

---

### 第 1 步：创建飞书应用

1. 打开 [飞书开放平台](https://open.feishu.cn)（国际站：https://open.larksuite.com）
2. 点击 **"创建应用"** → 选择 **"企业自建应用"**
3. 填写应用名称（如 `OpenClaw助手`）和描述
4. 进入应用详情页 → **"凭证与基础信息"**
5. 复制 **App ID** 和 **App Secret**（保存好！）

---

### 第 2 步：配置 OpenClaw

> **⚠️ 重要**：容器使用 Docker 命名卷（`openclaw-state`）存储配置。
>
> **宿主机 `~/.openclaw/` 仅作为初始化种子，运行时修改不会自动同步到容器！**
>
> **正确的配置方式**：
> - **方法一（推荐）**：使用 CLI 命令
> - **方法二**：进入容器直接编辑

#### 方法一：使用 CLI 命令（推荐）

```bash
# 启用飞书渠道
make cli CMD="config set channels.feishu.enabled true"

# 设置 App ID（替换为你的实际值）
make cli CMD="config set channels.feishu.accounts.main.appId 'cli_xxxxxxxxxxxx'"

# 设置 App Secret（替换为你的实际值）
make cli CMD="config set channels.feishu.accounts.main.appSecret 'your_secret_here'"

# 验证配置
make cli CMD="config list"
```

#### 方法二：进入容器编辑

```bash
# 进入容器
make shell

# 在容器内编辑配置文件（容器内只有 vi）
vi ~/.openclaw/openclaw.json
# 提示：按 i 进入编辑模式，编辑完成后按 Esc，输入 :wq 保存退出

# 或者使用 openclaw config 命令（更简单）
openclaw config list
openclaw config set channels.feishu.enabled true

# 保存后退出容器
exit
```

配置示例：

```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "accounts": {
        "main": {
          "appId": "cli_xxxxxxxxxxxx",
          "appSecret": "your_secret_here"
        }
      }
    }
  }
}
```

---

### 第 3 步：启用机器人能力

在飞书开放平台：
1. 进入 **"添加应用能力"** → **"机器人"** → **"添加"**
2. 填写机器人名称和描述
3. **"版本管理与发布"** → **"创建版本"** → **"发布"**

---

### 第 4 步：配置权限

在飞书开放平台 → **"权限管理"**：

| 权限 | 说明 |
|------|------|
| `im:message` | 获取与发送消息 |
| `im:message.group_at_msg` | 获取群聊中 @ 机器人的消息 |
| `im:chat` | 获取群组信息 |
| `contact:user.base:readonly` | 获取用户基本信息 |

> 💡 如需云盘、知识库等功能，按需添加 `drive:*` 和 `wiki:*` 权限。

---

### 第 5 步：配置事件订阅（关键！）

在飞书开放平台 → **"事件与回调"**：

1. **开启长连接**：
   - 点击 **"开启长连接"**
   - 确保状态显示 **"已开启"**

2. **添加事件订阅**：
   - 点击 **"添加事件"**
   - 添加：`im.message.receive_v1`

3. **发布新版本**（必须！配置变更需发布生效）

#### 常见问题：未检测到应用连接信息

如看到 "未检测到应用连接信息" 错误：

1. 确认 App ID / App Secret 已正确填入配置（使用 `make cli CMD="config list"` 验证）
2. 确认应用已发布并安装到企业
3. 重启 OpenClaw 服务：`make restart`
4. 查看日志确认连接：`make logs`
5. 返回飞书后台刷新并重新保存

---

### 第 6 步：添加应用到工作台

在飞书开放平台：
1. 点击 **"添加到工作台"**
2. 选择可见范围（部门或全公司）
3. 在飞书客户端 → **"工作台"** → 找到应用

---

### 第 7 步：测试验证

```bash
# 重启服务
make restart

# 查看日志（确认 WebSocket 连接成功）
make logs
```

在飞书中发送消息，如收到回复即配置成功！

---

## devkit 常用命令

| 操作 | 命令 |
|------|------|
| 查看状态 | `make status` |
| 查看日志 | `make logs` |
| 进入容器 | `make shell` |
| 重启服务 | `make restart` |
| 查看配置 | `make cli CMD="config list"` |
| 设置配置 | `make cli CMD="config set <path> <value>"` |
| 配对列表 | `make cli CMD="pairing list feishu"` |
| 批准配对 | `make cli CMD="pairing approve feishu <CODE>"` |

---

## 配置存储说明

```
┌─────────────────────────────────────────────────────────────┐
│                      宿主机 (Host)                          │
│  ~/.openclaw/                                               │
│  └── openclaw.json  ──────────────┐                        │
│       (初始化种子，仅首次启动时复制)  │                        │
└─────────────────────────────────────│───────────────────────┘
                                      │ 挂载为只读 seed
                                      ▼
┌─────────────────────────────────────────────────────────────┐
│                     Docker 容器                             │
│  /home/node/.openclaw-seed/   ← 只读挂载                    │
│  /home/node/.openclaw/        ← Docker 命名卷 (运行时配置)  │
│  └── openclaw.json            ← 实际使用的配置文件          │
└─────────────────────────────────────────────────────────────┘
```

**关键点**：
- 容器首次启动时，会将 seed 目录的配置复制到运行时目录
- 之后的修改**只影响容器内的配置**，不会同步回宿主机
- **正确的修改方式**：使用 `make cli CMD="config set ..."` 或 `make shell` 进入容器

---

## 常见问题

### 1. 发送消息无响应

```bash
# 检查服务状态
make status

# 查看实时日志
make logs

# 确认配置正确
make cli CMD="config list"

# 重启服务
make restart
```

### 2. 配置修改后不生效

确保你使用了正确的方式修改配置：

```bash
# ❌ 错误：直接编辑宿主机文件（不会同步到容器）
# 无论是用 nano、vi 还是其他编辑器编辑宿主机的 ~/.openclaw/ 都不会生效
nano ~/.openclaw/openclaw.json  # 这样做不会生效！

# ✅ 正确：使用 CLI 命令
make cli CMD="config set channels.feishu.enabled true"

# ✅ 正确：进入容器编辑（使用 vi）
make shell
vi ~/.openclaw/openclaw.json
# 提示：按 i 进入编辑模式，编辑完成后按 Esc，输入 :wq 保存退出
```

修改后重启服务：`make restart`

### 3. 容器无法启动

```bash
# 查看容器日志
docker compose logs openclaw-gateway

# 完全重启
make down && make up
```

### 4. 需要重置配置

```bash
# 进入容器
make shell

# 备份并删除配置
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup
rm ~/.openclaw/openclaw.json

# 退出并重启（会从 seed 重新初始化）
exit
make restart
```

---

## 更多配置

对于高级配置（多账号、群组白名单、流式输出、多Agent路由等），请参阅：

👉 **[OpenClaw 官方文档 - 飞书渠道](https://docs.openclaw.ai/zh-CN/channels/feishu)**

---

**文档版本**：2.1.0
**最后更新**：2025-03
**适用环境**：openclaw-devkit Docker 部署
