# 👶 零基础！Slack App 接入 OpenClaw 保姆级完整教程

> 🎯 **本教程专为 OpenClaw 用户设计。**
> 跟着以下保姆级图文步骤，只需几分钟即可完成机器人接入，开启 AI 协作之旅！

---

## 🟢 核心理念：我们需要做什么？
让 OpenClaw 连接 Slack 只需要两个“钥匙”：
1. **Bot Token (xoxb-...)**：机器人的“身份证”，用于收发消息。
2. **App Token (xapp-...)**：系统的“通讯证”，用于开启 Socket Mode（内网通），无需公网 IP 即可运行。

---

## 第 1 步：创建 Slack App

1. 打开浏览器登录 [Slack API 控制台](https://api.slack.com/apps)。
2. 点击右上角绿色按钮 **"Create New App"**。
3. 选择 **"From an app manifest"** (一键式配置)。
4. 选择你要安装的工作区 (Workspace)，点击 **"Next"**。
5. 在文本框中选择 **"JSON"** 标签，粘贴以下 OpenClaw 推荐的基础配置（魔法代码）：

```json
{
  "_metadata": {
    "major_version": 2,
    "minor_version": 1
  },
  "display_information": {
    "name": "OpenClaw",
    "long_description": "OpenClaw is an open-source AI coding assistant that provides intelligent code completion, refactoring, and debugging capabilities. It features deep understanding of code context, multi-language support, and seamless IDE integration. Perfect for developers seeking an alternative to proprietary AI coding tools with full data privacy and self-hosted deployment options.",
    "description": "OpenClaw AI Assistant - Open-source Coding Partner",
    "background_color": "#1e40af"
  },
  "features": {
    "assistant_view": {
      "assistant_description": "OpenClaw is an open-source AI coding assistant with intelligent code completion, refactoring, and debugging capabilities. It provides multi-language support, real-time suggestions, and self-hosted deployment for complete data privacy.",
      "suggested_prompts": [
        {
          "title": "💡 Brainstorm",
          "message": "In brainstorming mode, analyze the current project architecture, identify three areas for improvement, and explain the value and implementation approach"
        },
        {
          "title": "📝 Create Issue",
          "message": "Create a GitHub Issue using the project's defined Issue template, describing an important bug or feature request in the project"
        },
        {
          "title": "🔀 Create PR",
          "message": "Create a pull request based on current code changes using the project's defined PR template"
        },
        {
          "title": "🔍 Code Review",
          "message": "Conduct a comprehensive code review of the current branch, including DRY principles, SOLID principles, clean architecture, code quality, security vulnerabilities, and performance optimization"
        }
      ]
    },
    "app_home": {
      "home_tab_enabled": false,
      "messages_tab_enabled": true,
      "messages_tab_read_only_enabled": false
    },
    "bot_user": {
      "display_name": "OpenClaw",
      "always_online": true
    }
  },
  "oauth_config": {
    "scopes": {
      "bot": [
        "assistant:write",
        "app_mentions:read",
        "chat:write",
        "chat:write.public",
        "channels:read",
        "groups:read",
        "im:read",
        "im:write",
        "reactions:write",
        "im:history",
        "channels:history",
        "groups:history",
        "mpim:history",
        "files:write",
        "commands"
      ]
    }
  },
  "settings": {
    "event_subscriptions": {
      "bot_events": [
        "app_mention",
        "message.channels",
        "message.groups",
        "message.im",
        "assistant_thread_started",
        "assistant_thread_context_changed"
      ]
    },
    "org_deploy_enabled": false,
    "socket_mode_enabled": true
  }
}
```

6. 点击 **"Next"** -> **"Create"**。

![步骤 1：通过 Manifest 创建](images/guides/slack_step1_manifest.png)

---

## 第 2 步：获取 App Token (xapp-)

为了启用 **Socket Mode**，我们需要生成 App Token。

1. 进入 App 设置页面，在左侧菜单找到 **"Settings" -> "Basic Information"**。
2. 向下滚动到 **"App-Level Tokens"** 部分，点击 **"Generate Token and Scopes"**。
3. 输入 Token 名称（例如：`openclaw_socket`），并点击 **"Add Scope"**，选择 `connections:write`。
4. 点击 **"Generate"**，系统会显示一串以 `xapp-...` 开头的字符串。

![步骤 2：启用 Socket Mode](images/guides/slack_step2_socketmode.png)

5. **复制并保存这串代码**。

---

## 第 3 步：获取 Bot Token (xoxb-)

1. 在左侧菜单找到 **"Settings" -> "Install App"**。
2. 点击 **"Install to Workspace"** 并按照提示点击 **"Allow"** 完成授权。
3. 授权完成后，你会看到 **"Bot User OAuth Token"**。

![步骤 3：获取 Bot Token (xoxb)](images/guides/slack_step3_tokens.png)

4. **复制并保存这串以 `xoxb-...` 开头的代码**。

---

## 第 4 步：配置 OpenClaw 环境变量

将刚才拿到的两把“钥匙”填入 OpenClaw 根目录下的 `.env` 文件中。如果您是首次配置，请先复制 `.env.example` 文件并重命名为 `.env`：

```env
# Slack Bot Token (xoxb-...)
SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxx-xxxxxxxxxxxxx-xxxxxxxxxxxxxxxx

# Slack App Token (xapp-...) - 用于 Socket Mode
SLACK_APP_TOKEN=xapp-x-xxxxxxxxxxx-xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 第 5 步：启动并测试

1. 确保 `.env` 已保存。在终端进入 OpenClaw 根目录并重启服务：
   ```bash
   docker compose down
   docker compose up -d
   ```
2. 在 Slack 中，进入任意频道，输入 `/invite @OpenClaw` 或直接在输入框提到 `@OpenClaw`。
3. 对它说一句 `"Hi"`，如果它响应了你，说明接入成功！

> [!IMPORTANT]
> **关于网络代理 (生产环境必读)**：
> 由于国内访问 Slack API 可能受限，请务必检查 `.env` 中的 `HTTP_PROXY` 是否正确指向了宿主机的代理端口。
> 例如：`HTTP_PROXY=http://host.docker.internal:7897`。

---

## 🚀 进阶与高级配置 (Advanced Configuration)

如果你在多人协作的团队环境中使用 OpenClaw，仅配置两把“钥匙”可能还不够。你需要更精细的权限管控来避免机器人胡乱接话或越权操作。

打开你的 [`.env`](.env) 文件，你可以追加配置以下高级变量：

### 1. 绑定超级管理员 (Admin Binding)
默认情况下，任何人都可以对 OpenClaw 发号施令。设置管理员后，所有的**敏感高危操作（如修改代码核心配置、删除文件等）**都会被拦截，并通过交互式卡片等待管理员点击“批准”(Approve) 才能执行。

```env
# 填入你的个人 Member ID
SLACK_PRIMARY_OWNER=U0123456789
```
> **如何获取我的 Member ID？**
> 在 Slack 中点击你自己的个人头像，选择 **"Profile"**，点击头像旁边的 **"..." (More)** 按钮，选择 **"Copy member ID"**。

### 2. 消息响应模式 (@ 模式 / Mention Mode)
默认情况下，如果把机器人拉进一个群组，它极有可能会尝试分析并回复频道里的所有日常聊天（这不仅消耗大量 Tokens 成本，还会显得非常吵闹）。

```env
# 推荐设置为 mention
SLACK_GROUP_POLICY=mention
```
- `open`：默认。无论是否被 @ 都会倾听并可能抢答。
- `mention`：**强烈推荐**。机器人只装死，直到有人明确 `@OpenClaw` 才会出击处理专属需求。

### 3. 限定工作频道 (Channel Binding)
如果你不希望任何人私自把机器人拉入私人瞎聊频道，可以通过绑定指定频道 ID 的方式建立“安全隔离区”。

```env
# 仅允许在这几个特定的频道 ID 中运作
SLACK_ALLOWED_CHANNELS=C1A2B3C4D5,C9Z8Y7X6W5
```
*(注：由于底层架构引擎会将其最终结构化存储，除 `.env` 变量外，你也可在配置成功后，直接进容器审查 `~/.openclaw/openclaw.json` 里的 `channels.slack` 属性树)*
