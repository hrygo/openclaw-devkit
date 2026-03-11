# 👶 Zero-Friction! Feishu (Lark) Integration Beginner Guide for OpenClaw

> 🎯 **This guide is written for OpenClaw users who want a step-by-step setup with screenshots.**
> You can complete Feishu/Lark integration in around 10 minutes using long connection mode (WebSocket), without exposing a public webhook endpoint.

---

## 🟢 Core Concept: Which "keys" do we need?
For Feishu/Lark long-connection integration, you usually need these credentials:
1. **App ID**: Unique app identifier.
2. **App Secret**: App-level secret key.
3. **Verification Token**: Event source verification token.
4. **Encrypt Key (optional)**: Required only when encrypted event payload is enabled.

> [!TIP]
> UI labels can differ slightly between Feishu CN and Lark Global, but the menu path is typically the same:
> **Developer Console -> Your App -> Credentials & Basic Info / Event Subscriptions**.

---

## Step 1: Create a Custom App in Feishu Open Platform

1. Open [Feishu Open Platform](https://open.feishu.cn/) (for global Lark, use https://open.larksuite.com/).
2. Sign in with an admin/developer account and enter the developer console.
3. Click **Create App** and choose **Custom App (tenant app)**.
4. Fill in app name (recommended: `OpenClaw-devkit`) and description.
5. Enter the app detail page after creation.

![Step 1: Create custom app](images/guides/feishu_step1_create_app.png)

---

## Step 2: Enable Bot Capability and Publish the App

1. Open **Add App Capability** from the left menu.
2. Enable the bot switch.
3. Configure app availability scope (recommend a test group first).
4. Go to **Version Management & Release**, create a version, then publish.
5. Complete tenant installation/approval if your org requires it.

---

## Step 3: Configure Event Subscription (WebSocket / Long Connection)

1. Open **Event Subscriptions** in your app settings.
2. Enable event subscription.
3. Select **Long Connection (WebSocket)** if a subscription mode selector is provided.
4. Select the recommended events from the list in this guide.
5. Save the configuration.
6. Copy **Verification Token**.
7. If encrypted event delivery is enabled, copy **Encrypt Key** too.
8. If encryption is disabled, `Encrypt Key` can be empty.

![Step 3: Enable event subscription with websocket](images/guides/feishu_step3_events.png)

### Common Error Fix: "No app connection detected"

If Feishu shows this message when you save long-connection settings:
"No app connection detected. Please make sure the long connection is established before saving.",
handle it in this order:

1. Make sure you have obtained your App ID / App Secret (see Step 4), filled them correctly in OpenClaw, then start OpenClaw services.
2. In Feishu console, confirm the app is already published and installed to the tenant.
3. Verify Event Subscriptions is set to **Long Connection (WebSocket)** and keep that page refreshed.
4. Check gateway logs for success markers such as `WebSocket connected` or `event stream started`.
5. If no connection logs appear, check outbound networking first:
    - whether the server can access Feishu Open Platform domains
    - whether `HTTP_PROXY` / `HTTPS_PROXY` is configured
    - whether your proxy allows container egress traffic
6. Return to Event Subscriptions, refresh, and save again.

If it still fails, the most common causes are credential mismatch or app not published/installed. Re-check:
- App ID / App Secret come from the same app
- Current tenant is the same tenant where this app is installed
- Bot capability is enabled

---

## Step 4: Get App ID and App Secret

1. Go to **Credentials & Basic Info**.
2. Copy **App ID**.
3. Reveal/reset and copy **App Secret**.
4. Store both values securely.

![Step 4: Get app id and app secret](images/guides/feishu_step4_info.png)

---

## Step 5: Fill your OpenClaw `.env` file

Create or edit `.env` in the OpenClaw root directory:

```env
# Feishu/Lark App identity
FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx

# Event verification (required when event subscription is enabled)
FEISHU_VERIFICATION_TOKEN=xxxxxxxxxxxxxxxx

# Optional: required only when encrypted event payload is enabled
FEISHU_ENCRYPT_KEY=xxxxxxxxxxxxxxxx

# Recommended for no-public-IP deployments
FEISHU_EVENT_MODE=websocket
```

> [!IMPORTANT]
> The `FEISHU_*` variable names shown above are **illustrative examples only**. They are **not** guaranteed to appear in `.env.example` or be read directly by OpenClaw.
> For real deployments, `make onboard` and the generated config in `~/.openclaw/openclaw.json` are the **authoritative configuration path**.
> Use this `.env` snippet only as a **conceptual mapping** between your Feishu app credentials and potential environment variables, or if your own deployment tooling is explicitly wired to expect these names.

---

## Step 6: Start services and verify

1. Save `.env`, then run in project root:

```bash
docker compose down
docker compose up -d
```

2. Invite the bot into a test group.
3. Mention the bot and send `Hi` or a simple task.
4. If the bot responds, integration is successful.

**Recommended log checkpoints**:
- Gateway logs show WebSocket connected / event received.
- No auth/decryption errors (`invalid token`, `decrypt failed`).

---

## ✅ Recommended Permissions and Event List

### Recommended app permissions (scopes)
- Send and receive group/direct messages
- Read conversation metadata (chat/group IDs, conversation type)
- Read messages that mention the bot
- Send rich text or interactive cards (if card workflow is enabled)

### Recommended event subscriptions
- Bot mention event (core trigger)
- Group message event (enable only for controlled scopes)
- Direct message event (if DM support is needed)
- Bot joined/removed or conversation update events (optional for lifecycle sync)

> [!TIP]
> Follow least-privilege principle: start with minimum required permissions, then expand only when needed.

---

## 🚀 Advanced Recommendations

1. **Canary rollout first**: start with one test chat.
2. **Admin approval for risky actions**: strongly recommended for team environments.
3. **Channel allowlist**: limit bot operation to specific business chats.
4. **Proxy configuration**: set `HTTP_PROXY` / `HTTPS_PROXY` if network egress is restricted.
5. **Log monitoring**: check gateway logs regularly for connection state and event handling errors.

---

## 📸 Screenshot Asset Naming (under docs/images/guides/)

- `feishu_step1_create_app.png`
- `feishu_step3_events.png`
- `feishu_step4_info.png`

> Keep these filenames stable so the team can replace placeholders with real captured screenshots later.
