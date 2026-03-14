# 👶 Zero-Friction! Slack App Integration Beginner Guide for OpenClaw

> 🎯 **This guide is exclusively designed for OpenClaw users.**
> Follow these step-by-step visual instructions to complete the robot integration in just a few minutes and start your AI collaboration journey!

---

## 🟢 Core Concept: What do we need to do?
To connect OpenClaw to Slack, you only need two "keys":
1. **Bot Token (xoxb-...)**: The "Identity Card" of the robot, used for sending and receiving messages.
2. **App Token (xapp-...)**: The "Communication Pass" for the system to enable Socket Mode (Intranet communication), allowing it to run without a public IP address.

---

## Step 1: Create a Slack App

1. Open a browser and log in to the [Slack API Console](https://api.slack.com/apps).
2. Click the green **"Create New App"** button in the top right corner.
3. Select **"From an app manifest"** (One-click configuration).
4. Choose the Workspace where you want to install it, then click **"Next"**.
5. In the text box, select the **"JSON"** tab and directly paste the following official OpenClaw **App Manifest** configuration:

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

6. Click **"Next"** -> **"Create"**.

![Step 1: Create via Manifest](images/guides/slack_step1_manifest.png)

---

## Step 2: Get App Token (xapp-)

To enable **Socket Mode**, we need to generate an App Token.

1. Go to your App's settings page, and in the left menu, find **"Settings" -> "Basic Information"**.
2. Scroll down to the **"App-Level Tokens"** section and click **"Generate Token and Scopes"**.
3. Enter a Token Name (e.g., `openclaw_socket`), click **"Add Scope"**, and select `connections:write`.
4. Click **"Generate"**, and the system will display a string starting with `xapp-...`.

![Step 2: Enable Socket Mode](images/guides/slack_step2_socketmode.png)

5. **Copy and save this string**.

---

## Step 3: Get Bot Token (xoxb-)

1. In the left menu, find **"Settings" -> "Install App"**.
2. Click **"Install to Workspace"** and follow the terminal prompts to click **"Allow"** to complete the authorization.
3. After successful authorization, you will see the **"Bot User OAuth Token"**.

![Step 3: Get Bot Token (xoxb)](images/guides/slack_step3_tokens.png)

4. **Copy and save this string starting with `xoxb-...`**.

---

## Step 4: Configure OpenClaw Environment Variables

Fill the two "keys" you just obtained into the OpenClaw `.env` file in the root directory. If this is your first time configuring, copy `.env.example` and rename it to `.env` first:

```env
# Slack Bot Token (xoxb-...)
SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxx-xxxxxxxxxxxxx-xxxxxxxxxxxxxxxx

# Slack App Token (xapp-...) - Used for Socket Mode (Intranet Communication)
SLACK_APP_TOKEN=xapp-x-xxxxxxxxxxx-xxxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## Step 5: Start and Test

1. **Save Configuration**: Ensure the `.env` file is saved.
2. **Apply Configuration**:
   - In your terminal, navigate to the OpenClaw root directory and restart the service using Docker Compose:
     ```bash
     docker compose down
     docker compose up -d
     ```
3. **Invite Robot to Channel**:
   - In Slack, enter any channel and type `/invite @OpenClaw`.
4. **Say Hello**:
   - Say `"Hi"` to it, or mention it like `@OpenClaw`. If it responds, the integration is successful!

> [!IMPORTANT]
> **About Network Proxies (Must-read for production)**:
> Since accessing the Slack API from certain regions might be restricted, please ensure that the `HTTP_PROXY` in `.env` correctly points to your host's proxy port.
> Example: `HTTP_PROXY=http://host.docker.internal:7897`.

---

## 🚀 Advanced Configuration

If you are using OpenClaw in a team collaboration environment, configuring just the two "keys" might not be enough. You need finer-grained permission controls to prevent the bot from interrupting casually or executing unauthorized operations.

Open your [`.env`](.env) file, and you can append the following advanced variables:

### 1. Admin Binding (Superuser Role)
By default, anyone can issue commands to OpenClaw. After setting an administrator, all **highly sensitive operations (like modifying core configs, deleting files, etc.)** will be intercepted. OpenClaw will send an interactive card and wait for the administrator to click "Approve" before executing.

```env
# Fill in your personal Member ID
SLACK_PRIMARY_OWNER=U0123456789
```
> **How to get my Member ID?**
> Click on your profile picture in Slack, select **"Profile"**, click the **"..." (More)** button next to your picture, and select **"Copy member ID"**.

### 2. Mention Mode (Group Policy)
By default, if you invite the bot into a group channel, it might try to analyze and reply to all daily chats (which consumes a lot of Token costs and can be very noisy).

```env
# Highly recommended to set to 'mention'
SLACK_GROUP_POLICY=mention
```
- `open`: Default. It listens and might proactively reply whether mentioned or not.
- `mention`: **Highly Recommended**. The bot stays silent until someone explicitly mentions `@OpenClaw` to handle a specific request.

### 3. Channel Binding (Allowed Channels)
If you don't want anyone to privately pull the bot into unauthorized random channels, you can establish a "safe isolation zone" by binding specific channel IDs.

```env
# Only allowed to operate in these specific channel IDs
SLACK_ALLOWED_CHANNELS=C1A2B3C4D5,C9Z8Y7X6W5
```
*(Note: Because the underlying architectural engine stores this securely, besides using the `.env` variable, you can also directly inspect the `channels.slack` property tree in `~/.openclaw/openclaw.json` inside the container after a successful configuration)*
