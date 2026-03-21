# gogcli傻瓜 Setup Guide

> **5 minutes. Auth on host, import token to container. No browser in container.**

---

## Before You Start

Confirm the service is running:

```bash
make status
```

You should see `openclaw-gateway ... Up`.

---

## Step 1: Install gogcli on Host

**Run in a new terminal on your host:**

```bash
# macOS
brew install gogcli

# Linux
curl -fsSL https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_$(uname -m).tar.gz | sudo tar -xzC /usr/local/bin/
```

Verify:

```bash
gog version
```

Expected output: `v0.12.0 (c18c58c)` or similar.

---

## Step 2: Register Google Credentials

**On host:**

```bash
# Replace * with your actual file name
gog auth credentials set ~/.openclaw/client_secret_*.json
```

> No credentials file? Create an OAuth Client ID (type: Desktop App) in Google Cloud Console first.

---

## Step 3: Authorize Google Account

**On host:**

```bash
# Replace with your actual email
gog auth add your-email@gmail.com --services gmail,calendar,drive,contacts,sheets,docs
```

Browser opens automatically. Sign in to Google and click "Allow". Terminal shows success when done.

---

## Step 4: Export Refresh Token

**On host:**

```bash
# Replace with your actual email
gog auth tokens export your-email@gmail.com --out ~/.openclaw/gog-token.json --overwrite
```

Expected output: `exported    true`

> If it says "no tokens available", go back to Step 3 and complete authorization first.

---

## Step 5: Import Token into Container

**On host (do NOT enter the container):**

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
mkdir -p ~/.global/bin

# Detect architecture and download
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then ARCH_URL="amd64"; else ARCH_URL="arm64"; fi

curl -fsSL "https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_${ARCH_URL}.tar.gz" | tar -xzC /tmp
mv /tmp/gog ~/.global/bin/gog
chmod +x ~/.global/bin/gog

# Switch keyring to file mode
gog auth keyring file

# Import token
gog auth tokens import ~/.openclaw/gog-token.json

echo "Done. Auth status:"
gog auth list
'
```

Expected output:

```
Done. Auth status:
your-email@gmail.com    default    gmail,calendar,...    oauth
```

---

## Step 6: Set Keyring Password (for Restart Persistence)

**On host:**

```bash
# Set any password (used only to decrypt local token file)
echo 'GOG_KEYRING_PASSWORD=any-password-you-like' >> ~/.env

# Restart container
make restart
```

---

## Verify It Works

```bash
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=your-password && gog gmail search "in:inbox" 2>&1 | head -5'
```

Expected: see your email list.

Quick fixes if error:

| Error | Fix |
|-------|-----|
| `No auth for gmail` | Re-run Step 5 to import token |
| `403 accessNotConfigured` | Enable Gmail API in Google Cloud Console |
| `no TTY available for keyring` | Run Step 6 and restart |

---

## Daily Usage

After container restart, just use it directly:

```bash
# Check email
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=your-password && gog gmail search "in:inbox"'

# Check calendar
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=your-password && gog calendar list'

# List Drive files
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=your-password && gog drive ls'

# Send email
docker exec openclaw-gateway runuser -u node -- bash -c 'export GOG_KEYRING_PASSWORD=your-password && gog gmail send --to someone@example.com --subject "Test" --body "Hello"'
```

---

## Remove (Optional)

To remove from container only:

```bash
docker exec openclaw-gateway runuser -u node -- bash -c 'rm ~/.global/bin/gog ~/.global/bin/gogcli ~/.config/gogcli -rf'
```

Keep gog on host if you want it there too.

---

## Troubleshooting

### "gog: command not found"

Step 5 didn't run. Re-run Step 5.

### "No auth for gmail"

Token import failed. Run:

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD=your-password
gog auth tokens import ~/.openclaw/gog-token.json
'
```

### 403 Errors

API not enabled in Google Cloud Console. Open these links and click "Enable":

- Gmail: https://console.cloud.google.com/apis/library/gmail.googleapis.com
- Calendar: https://console.cloud.google.com/apis/library/calendar-json.googleapis.com
- Drive: https://console.cloud.google.com/apis/library/drive.googleapis.com

Wait 2-3 minutes and try again.

### Stopped Working After Restart

Check if password is set:

```bash
grep GOG_KEYRING_PASSWORD ~/.env
```

If missing, run Step 6.
