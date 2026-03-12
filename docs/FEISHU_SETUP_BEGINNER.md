# 👶 零基础！飞书 (Feishu/Lark) 接入 OpenClaw 保姆级完整教程

> 🎯 **本教程专为 OpenClaw DevKit 用户设计。**
> 跟着以下保姆级图文步骤，只需 10 分钟即可完成飞书机器人接入（长连接模式），无需公网 IP。

---

## 🟢 核心理念：我们需要准备哪几把“钥匙”？

将 OpenClaw 接入飞书（Lark）长连接模式，通常需要以下凭证：

1. **App ID**：应用唯一标识（相当于机器人账号 ID）
2. **App Secret**：应用密钥（相当于机器人密码）
3. **Verification Token**：事件订阅校验凭证（用于校验回调来源）

> [!TIP]
> 飞书平台不同版本（飞书中国站 / Lark 国际站）界面文案可能略有差异，但菜单路径一致：
> **开发者后台 → 你的应用 → 凭证与基础信息 / 事件与回调**

---

## 第 1 步：在飞书开放平台创建企业自建应用

1. 打开 [飞书开放平台](https://open.feishu.cn/)（Lark 国际站可使用 https://open.larksuite.com/）
2. 登录管理员账号，进入 **开发者后台**
3. 点击 **创建应用**，选择 **企业自建应用（Custom App）**
4. 填写应用名称（建议：`OpenClaw-devkit`）和应用描述，确认创建
5. 创建完成后进入应用详情页

![步骤 1：创建企业自建应用](images/guides/feishu_step1_create_app.png)

---

## 第 2 步：启用机器人能力并安装到企业

1. 在应用左侧菜单进入 **添加应用能力**
2. 打开 **启用机器人** 开关
3. 在 **可用范围** 中选择测试群或全员（建议先小范围测试）
4. 进入 **版本管理与发布**，点击 **创建版本** 并 **发布**
5. 在企业管理后台完成安装/可用配置（如需审批，按组织流程处理）

---

## 第 3 步：配置事件订阅（长连接 / WebSocket）

1. 在应用菜单进入 **事件与回调 / Event Subscriptions**
2. 打开 **事件订阅** 开关
3. 选择 **长连接（WebSocket）** 模式
4. 按下文"推荐事件列表"勾选必需事件
5. 保存配置
6. 找到 **Verification Token** 并复制
7. 如果启用了"加密传输"开关，再复制 **Encrypt Key**（可选）

![步骤 3：开启事件订阅并选择长连接](images/guides/feishu_step3_events.png)

### 推荐事件列表

- `im.message.receive_v1` — 接收消息（群聊/私聊）
- `im.chat.member.add_v1` — 成员添加
- `im.chat.member.delete_v1` — 成员移除

---

## 第 4 步：获取 App ID 与 App Secret

1. 进入 **凭证与基础信息 / Credentials & Basic Info**
2. 在页面中找到并复制 **App ID**（格式：`cli_xxxxxxxxxxxxxxxx`）
3. 点击显示或重置密钥后复制 **App Secret**
4. 将两项临时保存到你的密码管理器或安全笔记中

![步骤 4：获取 App ID 与 App Secret](images/guides/feishu_step4_info.png)

---

## 第 5 步：配置 OpenClaw 环境变量

在 OpenClaw DevKit 项目根目录下创建或编辑 `.env` 文件（首次可从 `.env.example` 复制）：

```env
# 飞书应用凭证
FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx

# 事件校验 Token
FEISHU_VERIFICATION_TOKEN=xxxxxxxxxxxxxxxx

# 可选：加密传输密钥（开启加密传输时需要）
# FEISHU_ENCRYPT_KEY=xxxxxxxxxxxxxxxx

# 推荐：内网/无公网 IP 部署时使用 WebSocket 模式
FEISHU_EVENT_MODE=websocket
```

> [!IMPORTANT]
> 配置完成后，需要重启服务使配置生效（见第 6 步）

---

## 第 6 步：启动并验证接入

1. 保存 `.env` 后，在项目根目录执行：

```bash
# 进入项目目录
cd openclaw-devkit

# 重启服务使配置生效
docker compose down
docker compose up -d
```

2. 查看日志确认连接成功：

```bash
docker compose logs -f openclaw-gateway
```

**日志检查点**：
- 出现 `WebSocket connected` 或 `event stream started` 表示连接成功
- 如果出现 `invalid token` 或 `decrypt failed` 等错误，检查凭证是否正确

3. 在飞书中把机器人拉入测试群
4. 在群内 @ 机器人，发送 `Hi` 或 `帮我总结今天的待办`
5. 若机器人正常响应，说明接入成功！

> [!TIP]
> 本项目常用命令：
> - `make up` — 启动服务
> - `make down` — 停止服务
> - `make restart` — 重启服务
> - `make logs` — 查看日志

---

## ✅ 推荐权限点与事件列表

### 必需权限（Scopes）

- `im:message` — 发送消息
- `im:message.group_at_msg` — 接收群 @ 消息
- `im:chat` — 获取会话信息
- `drive:drive` — 云盘访问
- `drive:file:readonly` — 只读云盘文件
- `drive:file` — 云盘文件操作
- `wiki:wiki` — 知识库访问
- `contact:user.base:readonly` — 只读用户基础信息

### 推荐事件（Events）

- `im.message.receive_v1` — 接收消息（群聊）
- `im.message.receive_v1` — 接收消息（私聊）
- `im.chat.member.add_v1` — 成员添加
- `im.chat.member.delete_v1` — 成员移除

> [!TIP]
> 权限遵循最小化原则：先开启最小必需权限跑通流程，再按需扩展

---

## 🚀 进阶配置

### 网络代理配置

如果服务器访问飞书开放平台受限，请在 `.env` 中配置代理：

```env
HTTP_PROXY=http://host.docker.internal:7897
HTTPS_PROXY=http://host.docker.internal:7897
```

### 日志监控

定期检查网关日志，关注连接状态和事件处理情况：

```bash
make logs
```

---

## 🆘 常见问题

### 问题：飞书中发送消息无响应

**排查步骤：**

1. 检查服务是否运行：
   ```bash
   make status
   ```

2. 查看错误日志：
   ```bash
   make logs
   ```

3. 检查配置是否正确：
   - 确认 `.env` 中 `FEISHU_APP_ID` 和 `FEISHU_APP_SECRET` 正确
   - 确认应用已在飞书开放平台发布
   - 确认已配置长连接（WebSocket）模式

4. 重启服务：
   ```bash
   make restart
   ```

### 问题：配置文件格式错误

**解决方法：**

1. 使用 JSON 校验工具检查格式：https://jsonlint.com
2. 确保使用双引号，不能用单引号
3. 确保没有 trailing comma

### 问题：未检测到应用连接信息

如果在飞书后台保存长连接配置时看到提示"未检测到应用连接信息"：

1. 确认 OpenClaw 服务已启动（`make status`）
2. 确认应用已在飞书后台发布并安装到企业
3. 检查网络是否能访问飞书开放平台
4. 检查代理配置是否正确

---

**文档版本：** 1.5.0  
**最后更新：** 2026-03-12
