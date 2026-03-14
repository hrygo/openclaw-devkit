# Feishu (Lark) Bot Quick Setup Guide

> **Quick Start**: Complete Feishu bot integration with openclaw-devkit in 7 steps (~10 minutes)

---

## Official Documentation

For complete configuration reference, advanced features, and troubleshooting, please refer to the **OpenClaw Official Documentation**:

- 📖 [Feishu Channel (中文)](https://docs.openclaw.ai/zh-CN/channels/feishu)
- 📖 [Feishu Channel (English)](https://docs.openclaw.ai/channels/feishu)

The official documentation includes:
- Complete configuration reference
- Quota optimization (typingIndicator, resolveSenderNames)
- Access control policies (DM pairing, group allowlists)
- Multi-account configuration
- Multi-Agent routing
- Streaming output and message quoting
- Complete troubleshooting guide

---

## Quick Start (7 Steps)

### Prerequisites

Ensure openclaw-devkit service is running:

```bash
make status
```

Expected output:
```
【容器】
  openclaw-gateway: Up X hours
【访问】 http://127.0.0.1:18789/
```

---

### Step 1: Create Feishu App

1. Open [Feishu Open Platform](https://open.feishu.cn) (International: https://open.larksuite.com)
2. Click **"Create App"** → Select **"Enterprise Self-built App"**
3. Fill in app name (e.g., `OpenClaw Assistant`) and description
4. Go to app details → **"Credentials & Basic Info"**
5. Copy **App ID** and **App Secret** (save them!)

---

### Step 2: Configure OpenClaw

> **⚠️ Important**: The container uses a Docker named volume (`openclaw-state`) to store configuration.
>
> **Host machine's `~/.openclaw/` only serves as initialization seed, runtime changes will NOT sync back to host!**
>
> **Correct ways to modify configuration**:
> - **Method 1 (Recommended)**: Use CLI commands
> - **Method 2**: Enter container and edit directly

#### Method 1: Use CLI Commands (Recommended)

```bash
# Enable Feishu channel
make cli CMD="config set channels.feishu.enabled true"

# Set App ID (replace with your actual value)
make cli CMD="config set channels.feishu.accounts.main.appId 'cli_xxxxxxxxxxxx'"

# Set App Secret (replace with your actual value)
make cli CMD="config set channels.feishu.accounts.main.appSecret 'your_secret_here'"

# Verify configuration
make cli CMD="config list"
```

#### Method 2: Enter Container to Edit

```bash
# Enter container
make shell

# Edit config file inside container (only vi available)
vi ~/.openclaw/openclaw.json
# Tip: Press i to enter edit mode, press Esc when done, type :wq to save and exit

# Or use openclaw config command (easier)
openclaw config list
openclaw config set channels.feishu.enabled true

# Exit container after saving
exit
```

Configuration example:

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

### Step 3: Enable Bot Capability

In Feishu Open Platform:
1. Go to **"Add App Capability"** → **"Bot"** → **"Add"**
2. Fill in bot name and description
3. **"Version Management & Release"** → **"Create Version"** → **"Release"**

---

### Step 4: Configure Permissions

In Feishu Open Platform → **"Permission Management"**:

| Permission | Description |
|------------|-------------|
| `im:message` | Get and send messages |
| `im:message.group_at_msg` | Get group messages that @ mention the bot |
| `im:chat` | Get group information |
| `contact:user.base:readonly` | Get user basic information |

> 💡 For cloud drive, knowledge base, etc., add `drive:*` and `wiki:*` permissions as needed.

---

### Step 5: Configure Event Subscription (Critical!)

In Feishu Open Platform → **"Events & Callbacks"**:

1. **Enable Long Connection**:
   - Click **"Enable Long Connection"**
   - Ensure status shows **"Enabled"**

2. **Add Event Subscription**:
   - Click **"Add Event"**
   - Add: `im.message.receive_v1`

3. **Publish New Version** (Required! Config changes need to be published to take effect)

#### Common Issue: App Connection Not Detected

If you see "App connection not detected" error:

1. Confirm App ID / App Secret are correctly configured (verify with `make cli CMD="config list"`)
2. Confirm app is published and installed to your organization
3. Restart OpenClaw service: `make restart`
4. Check logs to confirm connection: `make logs`
5. Return to Feishu admin panel, refresh and re-save

---

### Step 6: Add App to Workspace

In Feishu Open Platform:
1. Click **"Add to Workspace"**
2. Select visibility scope (department or whole company)
3. In Feishu client → **"Workspace"** → Find the app

---

### Step 7: Test and Verify

```bash
# Restart service
make restart

# Check logs (confirm WebSocket connection successful)
make logs
```

Send a message in Feishu. If you receive a reply, configuration is successful!

---

## devkit Common Commands

| Action | Command |
|--------|---------|
| Check status | `make status` |
| View logs | `make logs` |
| Enter container | `make shell` |
| Restart service | `make restart` |
| View config | `make cli CMD="config list"` |
| Set config | `make cli CMD="config set <path> <value>"` |
| List pairings | `make cli CMD="pairing list feishu"` |
| Approve pairing | `make cli CMD="pairing approve feishu <CODE>"` |

---

## Configuration Storage Explained

```
┌─────────────────────────────────────────────────────────────┐
│                      Host Machine                           │
│  ~/.openclaw/                                               │
│  └── openclaw.json  ──────────────┐                        │
│       (Initialization seed, only copied on first start)     │
└─────────────────────────────────────│───────────────────────┘
                                      │ Mounted as read-only seed
                                      ▼
┌─────────────────────────────────────────────────────────────┐
│                     Docker Container                        │
│  /home/node/.openclaw-seed/   ← Read-only mount             │
│  /home/node/.openclaw/        ← Docker named volume (runtime)│
│  └── openclaw.json            ← Actual config file in use   │
└─────────────────────────────────────────────────────────────┘
```

**Key Points**:
- On first container start, config is copied from seed directory to runtime directory
- Subsequent modifications **only affect container's config**, will NOT sync back to host
- **Correct modification method**: Use `make cli CMD="config set ..."` or `make shell` to enter container

---

## Common Issues

### 1. No Response to Messages

```bash
# Check service status
make status

# View real-time logs
make logs

# Confirm configuration is correct
make cli CMD="config list"

# Restart service
make restart
```

### 2. Configuration Changes Not Taking Effect

Ensure you're using the correct method to modify configuration:

```bash
# ❌ Wrong: Directly editing host machine file (will NOT sync to container)
# Whether using nano, vi or any other editor on host's ~/.openclaw/, it won't work
nano ~/.openclaw/openclaw.json  # This won't work!

# ✅ Correct: Use CLI commands
make cli CMD="config set channels.feishu.enabled true"

# ✅ Correct: Enter container to edit (using vi)
make shell
vi ~/.openclaw/openclaw.json
# Tip: Press i to enter edit mode, press Esc when done, type :wq to save and exit
```

Restart service after modification: `make restart`

### 3. Container Won't Start

```bash
# View container logs
docker compose logs openclaw-gateway

# Full restart
make down && make up
```

### 4. Need to Reset Configuration

```bash
# Enter container
make shell

# Backup and delete config
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup
rm ~/.openclaw/openclaw.json

# Exit and restart (will re-initialize from seed)
exit
make restart
```

---

## Advanced Configuration

For advanced configuration (multi-account, group allowlists, streaming output, multi-Agent routing, etc.), please refer to:

👉 **[OpenClaw Official Documentation - Feishu Channel](https://docs.openclaw.ai/channels/feishu)**

---

**Document Version**: 2.1.0
**Last Updated**: 2025-03
**Environment**: openclaw-devkit Docker deployment
