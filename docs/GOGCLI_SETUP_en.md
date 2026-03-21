# gogcli (Google Workspace CLI) Optional Setup Guide

> **Goal**: Install gogcli in the container and configure Google account authentication, enabling AI Agents to access Gmail, Calendar, Drive, Sheets, Docs and other Google Workspace data.
>
> **Use case**: Users who need OpenClaw Agents to operate on their Google data.
>
> **Required**: No (optional configuration)

---

## Feature Overview

gogcli ([steipete/gogcli](https://github.com/steipete/gogcli)) is a Google Workspace CLI tool supporting:

| Service | Features |
|---------|----------|
| Gmail | Search, send, label, manage emails |
| Calendar | List/create/modify calendar events |
| Drive | Browse, upload, download files |
| Sheets | Read/write spreadsheets |
| Docs | Read, edit Google documents |
| Contacts | Manage address book |

---

## Prerequisites

### 1. Google OAuth Credentials

You need a Google OAuth 2.0 client credentials (`client_id` + `client_secret`):

1. Visit [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create an **OAuth Client ID** of type **Desktop App** (or use existing credentials)
3. Download the JSON file and save it to `~/.openclaw/` on your host
4. File naming format: `client_secret_<client_id>.json`

### 2. Enable Google APIs

Enable the required APIs in [Google Cloud Console](https://console.cloud.google.com/apis/library) for your project:

- Gmail API
- Google Calendar API
- Google Drive API
- Google Sheets API
- Google Docs API
- Google People API (contacts)
- Google Contacts API

> **Tip**: Enable only the APIs you need.

---

## Setup Steps

### Step 1: Ensure openclaw-devkit is Running

```bash
make status
```

Verify the container is `Up`.

---

### Step 2: Authenticate gogcli on Host (Recommended)

Authenticating on the host and exporting the token is recommended to avoid browser authorization in the container.

#### 2.1 Install gogcli (Host)

```bash
# macOS
brew install gogcli

# Linux
curl -fsSL https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_$(uname -m).tar.gz | tar -xzC /tmp
sudo mv /tmp/gog /usr/local/bin/gog
sudo chmod +x /usr/local/bin/gog
```

#### 2.2 Register OAuth Credentials

```bash
gog auth credentials set ~/.openclaw/client_secret_<your-client-id>.json
```

#### 2.3 Authorize Google Account

```bash
gog auth add <your-email@gmail.com> --services gmail,calendar,drive,contacts,sheets,docs
```

A browser window will open for authorization. Complete it and return.

#### 2.4 Export Refresh Token

```bash
gog auth tokens export <your-email@gmail.com> --out /tmp/gog-token.json --overwrite
```

The exported file contains the refresh token for container import.

---

### Step 3: Import Token into Container

#### 3.1 Copy Token File to .openclaw Directory

```bash
cp /tmp/gog-token.json ~/.openclaw/gog-token-export.json
```

#### 3.2 Install gogcli in Container

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
mkdir -p ~/.global/bin

# Download gogcli (select by architecture)
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_URL="amd64"
else
    ARCH_URL="arm64"
fi

curl -fsSL "https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_${ARCH_URL}.tar.gz" | tar -xzC /tmp
mv /tmp/gog ~/.global/bin/gog
chmod +x ~/.global/bin/gog

# Create alias (optional)
ln -sf ~/.global/bin/gog ~/.global/bin/gogcli

echo "gog version:"
~/.global/bin/gog version
'
```

#### 3.3 Import Token

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD="<your-password>"

# Switch to file keyring
gog auth keyring file

# Import token (gog-token-export.json is mounted at ~/.openclaw/)
gog auth tokens import ~/.openclaw/gog-token-export.json

# Verify
gog auth list
'
```

---

### Step 4: Configure Environment Variable (Persistence)

#### 4.1 Add to .env

```bash
echo 'GOG_KEYRING_PASSWORD=<your-password>' >> ~/.env
```

#### 4.2 Verify docker-compose.yml Includes the Variable

Check if `docker-compose.yml` contains:

```yaml
environment:
  GOG_KEYRING_PASSWORD: ${GOG_KEYRING_PASSWORD:-}
```

> openclaw-devkit already includes this configuration.

#### 4.3 Restart Container

```bash
make restart
```

---

### Step 5: Verify Configuration

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD="<your-password>"

echo "=== Auth Status ==="
gog auth status

echo ""
echo "=== Gmail Test ==="
gog gmail search "in:inbox" -n 3

echo ""
echo "=== Calendar Test ==="
gog calendar list

echo ""
echo "=== Drive Test ==="
gog drive ls -n 5
'
```

Expected output:

```
=== Auth Status ===
config_path    /home/node/.config/gogcli/config.json
keyring_backend    file
account    your-email@gmail.com
client    default

=== Gmail Test ===
ID    DATE    FROM    SUBJECT    LABELS    THREAD
xxx    2026-03-21    xxx@example.com    Test Email    INBOX    -
```

---

## Usage in Container

### Direct Use

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD="<your-password>"
gog <command>
'
```

### Via OpenClaw Agent

You can chat directly with Claude Code or other AI Agents:

```
Check my Gmail for the past week
Create a calendar event: meeting tomorrow at 3pm
List my Google Drive files
```

---

## Troubleshooting

### "No auth for gmail" Error

**Cause**: keyring password not set or token not imported correctly.

**Solution**:

```bash
docker exec openclaw-gateway runuser -u node -- bash -c '
export GOG_KEYRING_PASSWORD="<your-password>"
gog auth status
'
```

### "Google API error (403)" Error

**Cause**: Corresponding API not enabled in Google Cloud project.

**Solution**: Enable the API in [Google Cloud Console](https://console.cloud.google.com/apis/library), wait a few minutes and retry.

### Authentication Lost After Restart

**Cause**: `GOG_KEYRING_PASSWORD` environment variable not persisted.

**Solution**:

```bash
# Check if password exists in .env
grep GOG_KEYRING_PASSWORD ~/.env

# If not, add it
echo 'GOG_KEYRING_PASSWORD=<your-password>' >> ~/.env

# Restart container
make restart
```

### "no TTY available for keyring file backend password prompt"

**Cause**: `GOG_KEYRING_PASSWORD` environment variable not set in container.

**Solution**: Verify the password exists in `.env` and restart the container.

---

## Data Storage Locations

| Data | Container Path | Persistence |
|------|---------------|-------------|
| gogcli binary | `~/.global/bin/gog` | Named volume `openclaw-devkit-home` |
| gog config | `~/.config/gogcli/` | Named volume `openclaw-devkit-home` |
| keyring (token) | `~/.config/gogcli/keyring/` | Named volume `openclaw-devkit-home` |
| OAuth credentials | `~/.config/gogcli/credentials.json` | Named volume `openclaw-devkit-home` |
| Environment variable | `GOG_KEYRING_PASSWORD` | `.env` + `docker-compose.yml` |

> **Note**: All data is stored in Docker named volumes and persists after container rebuilds. The token file (`gog-token-export.json`) is only used for import.

---

## Security Recommendations

1. **Protect refresh token**: refresh tokens are long-lived. Keep `GOG_KEYRING_PASSWORD` in `.env` secure.
2. **Regular rotation**: If you notice suspicious access, revoke access in Google account security settings and re-authenticate.
3. **Least privilege**: Only authorize the Google API service scopes you need.
