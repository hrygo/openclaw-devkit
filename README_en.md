# OpenClaw Development Kit (OpenClaw DevKit)

English | [简体中文](./README.md)

<p align="center">
  <a href="https://github.com/openclaw/openclaw"><img src="https://img.shields.io/badge/Powered%20By-OpenClaw-blue" alt="OpenClaw"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/Env-Docker-blue?logo=docker" alt="Docker"></a>
  <a href="https://claude.ai/code"><img src="https://img.shields.io/badge/With-Claude%20Code-purple" alt="Claude Code"></a>
</p>

**OpenClaw DevKit** provides a complete containerized development, debugging, and runtime environment for the [OpenClaw](https://github.com/openclaw/openclaw) multi-channel AI productivity tool.

It integrates an out-of-the-box toolchain designed to help developers quickly build AI workflows based on OpenClaw, supporting automatic source updates, one-click environment setup, and built-in network optimization for various environments.

---

## ✨ Key Features

- 🔐 **Security Isolation**: Containerized runtime + isolated Git identity + least privilege, network exposed to localhost only
- 🚀 **One-Click Environment Setup**: Based on Docker Compose, start a complete development environment in seconds.
- 🛠️ **Triple Image Version Selection**:
    - **Standard Edition (Dockerfile)**: Integrated with Go 1.26, Node 22 LTS, Python 3.13, pnpm, Bun, Playwright, etc.
    - **Office Edition (Pro)**: Specialized for **non-developers**. Includes enhanced OCR, PDF tools, and UI automation.
    - **Java Enhanced Edition (Dockerfile.java)**: Deeply integrated with **JDK 21 (LTS)** and enterprise-grade tools.
- 🧠 **AI-Native Integration**: Built-in **Claude Code**, **OpenCode**, and **Pi-Mono**, allowing AI to write and run code directly within the container for you.
- 🌐 **Global Acceleration**: Intelligent proxy forwarding mechanism specifically optimized for Google and Claude APIs.
- 🎥 **Automation Capabilities**: Pre-installed Playwright and all browser dependencies, supporting complex web automation tasks.
- 📝 **Document Processing**: Integrated Pandoc and LaTeX, supporting high-quality document format conversion and generation.
- 💾 **Persistence**: Utilizes **Named Volumes** for extreme build speed and persistent session data.

---

## Prerequisites

### General Requirements
- **Docker**: V2 (Docker Desktop for macOS/Windows, Docker Engine for Linux)
- **Docker Compose**: V2 (included in Docker Desktop)
- **Make**: Pre-installed on macOS/Linux, Windows users need [Make for Windows](https://gnuwin32.sourceforge.net/packages/make.htm) or [Git Bash](https://git-scm.com/download/win)

### Windows-Specific Requirements

| Component | Requirement | Notes |
| :--- | :--- | :--- |
| **OS** | Windows 10 21H2+ or Windows 11 | |
| **WSL2** | Required | [Installation Guide](https://docs.microsoft.com/en-us/windows/wsl/install) |
| **Memory** | 8GB+ recommended | Docker Desktop minimum 4GB |
| **Virtualization** | Must enable in BIOS/UEFI | Intel VT-x / AMD-V |

> [!TIP]
> Windows users should use **Docker Desktop** (includes WSL2 integration). After installation, enable WSL2:
> ```powershell
> wsl --install
> ```

---

## 🚥 Quick Start

### Prebuilt Image ⭐ (Recommended)

```bash
# 1. Clone project
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit

# 2. Configure
cp .env.example .env

# 3. Pull prebuilt image
docker pull ghcr.io/hrygo/openclaw-devkit:latest

# 4. Start services
make up

# 5. Access Web UI
# Open http://127.0.0.1:18789 in browser

# 6. First-time setup (required)
make onboard
```

**Prebuilt Image Versions** (modify `OPENCLAW_IMAGE` in `.env`):
| Edition | Image Tag |
| :--- | :--- |
| Standard | `ghcr.io/hrygo/openclaw-devkit:latest` |
| Office | `ghcr.io/hrygo/openclaw-devkit:latest-office` |
| Java | `ghcr.io/hrygo/openclaw-devkit:latest-java` |

---

### Interactive Setup (onboard)

First-time setup requires running the interactive wizard to configure LLM providers, Feishu, channels, and other core settings:

```bash
# Launch interactive setup wizard
make onboard
```

This wizard will guide you through:
- 🤖 **LLM Configuration**: Select and configure Claude/OpenAI/Qwen models
- 📱 **Feishu Integration**: Configure Feishu bot permissions and channels
- 📢 **Notification Channels**: Set up message delivery methods and recipients

> [!TIP]
> If you're using a prebuilt image, configuration data persists in the `openclaw-state` volume—no need to reconfigure after container restarts.

---

> [!WARNING]
> ## ⚠️ Important Security Warning: Do NOT Mix Container & Host Installation
>
> This project shares configuration with the host machine via the `~/.openclaw` directory. Using both running methods simultaneously poses **security risks**:
>
> | Running Mode | `gateway.bind` Required | Security Notes |
> | :----------- | :--------------------- | :------------- |
> | **Docker Container** | `lan` (bind to `0.0.0.0`) | ✅ **Required** — Docker port mapping `127.0.0.1:18789` restricts access to localhost only |
> | **Host Direct Run** | `loopback` (bind to `127.0.0.1`) | ⚠️ Using `lan` will expose to local network |
>
> ### Why must containers use `lan`?
> Docker port mapping `127.0.0.1:18789:18789` means requests received by the host are forwarded to the container. If the service inside the container binds to `127.0.0.1`, it cannot properly receive requests forwarded from the Docker network layer. Binding to `0.0.0.0` is required for it to work.
>
> ### Recommended Approach
> 1. **Container-only usage** (recommended): Keep `gateway.bind = "lan"`, do not install OpenClaw on the host
> 2. **Need to run on host directly**: Change to `gateway.bind = "loopback"`, and ensure containers are stopped before starting host services
> 3. **Need both**: Use **separate config directories** (e.g., `~/.openclaw-docker` and `~/.openclaw-local`)
>
> ```bash
> # Check current bind config
> cat ~/.openclaw/openclaw.json | jq '.gateway.bind'
>
> # Change to loopback (for host direct run)
> # In config file, change "bind": "lan" to "bind": "loopback"
> ```

---

## 📊 Feature Comparison

| Feature              |    Standard Edition    | Java Enhanced Edition |   Office (Pro Edition)   |
| :------------------- | :--------------------: | :-------------------: | :----------------------: |
| Target Audience      |      General Devs      |    Java Enterprise    | Automation & Copywriting |
| Environment          |    Node, Go, Python    |     Same + JDK 21     |     Node 22, Python      |
| AI Coding Assistants |       ✅ Included       |      ✅ Included       |     Pi-Coding-Agent      |
| Automation           |       Playwright       |      Playwright       |  Playwright + Selenium   |
| Doc Conversion       |     Pandoc, LaTeX      |     Pandoc, LaTeX     |    Pandoc, Full LaTeX    |
| OCR Engines          |           ❌            |           ❌           |    Tesseract (CN/EN)     |
| Image/PDF Tools      |         Pandoc         |        Pandoc         |   ImageMagick, Poppler   |
| Data Analysis        |           ❌            |           ❌           |      Pandas, Numpy       |
| Build Tools          |       pnpm, Bun        |     Gradle, Maven     |        pnpm, Bun         |
| Key Advantage        | Lightweight, AI-Native | Policy & Audit Ready  |  Zero-Config Automation  |
| Image Size           |         6.4GB          |        8.08GB         |          4.7GB           |

---


> [!TIP]
> **Manual Switch**:
> 1. Modify `.env` file: `OPENCLAW_IMAGE=openclaw:pro` (or `openclaw:dev-java`)
> 2. Run `make up`

---


### Project Architecture
![Architecture Diagram](docs/assets/architecture.svg)

---

## 🔁 Core Workflow & File Collaboration

To achieve an "out-of-the-box" experience, this project establishes a self-consistent file collaboration system:

1. **Entry Layer (`Makefile`)**: Serves as the primary interface for user operations, encapsulating complex Docker commands and hiding environment interaction complexity.
2. **Initialization Layer (`docker-setup.sh`)**: Triggered by `make install`. It reads `.env` configurations, pre-creates host directory trees, handles permission fixes, and calls `Dockerfile` to build the customized development image.
3. **Orchestration Layer (`docker-compose.yml`)**: The central dispatch center. It defines network abstractions between containers, environment variable injection, and efficient `node_modules` caching using Named Volumes.
4. **Runtime Layer (`Dockerfile*`)**: The physical definition of the environment. It integrates Node.js, Go, Python, and browser engines into a single container, eliminating the "it works on my machine" paradox.
5. **Maintenance Layer (`update-source.sh`)**: Automated update mechanism. It monitors version changes via GitHub API, enabling one-click source hot updates and cleanup of old images.

---

## 🤖 Slack Integration Guide

To enable Slack interaction, follow these steps to configure your Slack App:

### 1. Quick Setup (Recommended: Using Manifest)
1. Visit the [Slack API Console](https://api.slack.com/apps) and click **"Create New App"**.
2. Choose **"From an app manifest"** and select your target workspace.
3. Copy the contents of [`slack-manifest.json`](./slack-manifest.json) from the project root and paste it.
4. Generate an **App-level Token** (`xapp-...`) under **"Settings" -> "Socket Mode"** with the `connections:write` scope.
5. Install the app into your workspace to obtain the **Bot User OAuth Token** (`xoxb-...`).

### 2. Environment Configuration & Pairing
1. Add your tokens to the `.env` file. **OpenClaw will automatically enable the Slack channel upon startup when these variables are detected.**
2. **Execute Pairing**: Run `make pairing CMD="list slack"` to see pending pairing requests (verification codes).
3. **Complete Pairing**: Send the code to the bot in Slack, or run `make pairing CMD="approve slack CODE"`.

```bash
SLACK_BOT_TOKEN=xoxb-your-bot-token
# ...
```

### 3. Best Practices & Default Behavior
- **Auto-Enable**: As long as valid tokens exist in `.env`, the channel is enabled automatically without needing `enabled: true` in `openclaw.json`.
- **Privacy First (Default Allowlist)**: For security, channel messages default to `allowlist` mode (only responding in allowed channels). DMs default to `pairing` mode (requires running `make pairing` to approve).
- **Use Socket Mode**: This is the default for DevKit, allowing you to receive Slack events locally without network tunneling (no static IP or ngrok required).
- **Security Isolation**: In production, use `SLACK_PRIMARY_OWNER` to restrict access to sensitive administrative commands.

---

## ⚙️ Configuration Details

Edit the `.env` file in the project root for personalized configuration:

| Variable Name           | Description                     | Example Value                      |
| :---------------------- | :------------------------------ | :--------------------------------- |
| `OPENCLAW_CONFIG_DIR`   | Host configuration storage path | `~/.openclaw`                      |
| `OPENCLAW_IMAGE`        | Image variant (dev / dev-java)  | `openclaw:dev`                     |
| `SLACK_BOT_TOKEN`       | Slack Bot Token (xoxb)          | `xoxb-xxxx...`                     |
| `SLACK_APP_TOKEN`       | Slack App Token (xapp)          | `xapp-xxxx...`                     |
| `SLACK_PRIMARY_OWNER`   | Slack Primary Owner ID          | `U01234567`                        |
| `OPENCLAW_GATEWAY_PORT` | Gateway access port             | `18789`                            |
| `HTTP_PROXY`            | Proxy for container internet    | `http://host.docker.internal:7897` |
| `GITHUB_TOKEN`          | Token for `make update`         | `your_github_token`                |

---

## 🛠️ Maintenance Command Manual

| Category         | Command               | Description                                                 |
| :--------------- | :-------------------- | :---------------------------------------------------------- |
| **Lifecycle**    | `make up / down`      | Start / Stop services                                       |
|                  | `make onboard`        | Interactive setup wizard (LLM, Feishu, channels, etc.)       |
|                  | `make restart`        | Restart all services                                        |
|                  | `make status`         | View container status and access URLs                       |
| **Build/Update** | `make build`          | Build standard image (Dockerfile)                           |
|                  | `make build-java`     | Build Java enhanced image (Dockerfile.java)                 |
|                  | `make rebuild`        | Rebuild standard image and restart services                 |
|                  | `make rebuild-java`   | Rebuild Java image and restart services                     |
|                  | `make update`         | Fetch latest OpenClaw source from GitHub                    |
| **Diagnosis**    | `make logs`           | Follow Gateway service logs.                                |
|                  | `make shell`          | Enter container shell (bash).                               |
|                  | `make pairing`        | **Channel Pairing** (e.g., `make pairing CMD="list slack"`) |
|                  | `make test-proxy`     | **One-click test** for Google/Claude API.                   |
|                  | `make gateway-health` | Check gateway response status                               |

### 📖 More Details
For complete command descriptions and configuration details, please refer to: **[Detailed Reference Manual (REFERENCE.md)](./docs/REFERENCE_en.md)**.

| Category    | Command               | Description                                        |
| :---------- | :-------------------- | :------------------------------------------------- |
| **Backup**  | `make backup-config`  | Backup Agent configurations to host                |
|             | `make restore-config` | Interactively restore specific config files        |
| **Cleanup** | `make clean`          | Clean up orphan containers and dangling images     |
|             | `make clean-volumes`  | **WARNING**: Wipe all cache and persistent volumes |

---

## 🔌 Advanced Volume Mounts

> ⚠️ **Note**: Some paths in the "Host Path" column (e.g., `~/.gitconfig-hotplex`) are **examples only**. You need to adjust the corresponding paths in `docker-compose.yml` **based on your own setup**.

By default, OpenClaw automatically mounts the following directories to make host resources accessible within the container.

### Required Mounts (Essential for Basic Functionality)

> ⚠️ These mounts use variables defined in `.env` (`OPENCLAW_CONFIG_DIR`, `OPENCLAW_WORKSPACE_DIR`) - no manual modification needed

| Host Path (.env variable)       | Container Path                   | Purpose                                                    |
| :------------------------------ | :------------------------------- | :--------------------------------------------------------- |
| `${OPENCLAW_CONFIG_DIR}`        | `/home/node/.openclaw-seed:ro`   | Configuration seed (read-only, required for first startup) |
| `${OPENCLAW_WORKSPACE_DIR}`     | `/home/node/.openclaw/workspace` | Workspace files (AI working directory - required!)         |
| `openclaw-state` (Named Volume) | `/home/node/.openclaw`           | Persistent state (sessions, credentials, logs)             |

### Optional Mounts (Choose Based on Your Needs)

| Host Path                            | Container Path                    | Purpose                                                                             |
| :----------------------------------- | :-------------------------------- | :---------------------------------------------------------------------------------- |
| `~/.claude`                          | `/home/node/.claude`              | Claude Code session state (mount to share sessions)                                 |
| `~/.gitconfig-xxx` (adjust)          | `/home/node/.gitconfig:ro`        | **Dedicated Git identity** (gives AI its own identity, separate from your main one) |
| `openclaw-node-modules` (Volume)     | `/app/node_modules`               | Node.js dependency cache (speeds up restarts)                                       |
| `openclaw-go-mod` (Volume)           | `/home/node/go/pkg/mod`           | Go module cache (mount when using Go)                                               |
| `openclaw-playwright-cache` (Volume) | `/home/node/.cache/ms-playwright` | Playwright browser cache (mount when using browser automation)                      |
 
### 💾 Storage Persistence: Named Volumes vs Bind Mounts

This project uses a hybrid mounting strategy to balance performance and usability:

1. **Named Volumes**: e.g., `openclaw-state`.
   - **Pros**: Fully managed by Docker, high performance on macOS/Windows, persistent across container removals.
   - **Cons**: "Inaccessible" directly from the host filesystem (stored within Docker's internal subsystem).
2. **Bind Mounts**: e.g., `${OPENCLAW_WORKSPACE_DIR}`.
   - **Pros**: Maps directly to a host directory, allowing you to edit files using your favorite host tools (VS Code, etc.).
   - **Cons**: Slower performance on non-Linux systems due to filesystem sync overhead; subject to host permission issues.

> [!IMPORTANT]
> **Counter-intuitive Issue**: Named Volumes have an "initialization" feature. If the container image's internal path already contains files, they are copied to the volume *only during the first mount*. Subsequent image updates will **not** be reflected in the volume unless it is manually cleared. For more details, see the [Reference Manual (REFERENCE_en.md)](./docs/REFERENCE_en.md#💾-storage--persistence).

### Why Use `~/.gitconfig-xxx` Instead of `~/.gitconfig`?

**Core Reason**: Give OpenClaw a **separate Git identity**, distinct from your main development environment.

| Comparison   | Your Main Environment | OpenClaw Environment   |
| :----------- | :-------------------- | :--------------------- |
| Config File  | `~/.gitconfig`        | `~/.gitconfig-hotplex` |
| Git Username | `YourName`            | `HotPlexBot01`         |
| Git Email    | `you@example.com`     | `noreply@hotplex.dev`  |
| Purpose      | Daily development     | AI automation          |

**Benefits**:
1. **Clear distinction**: GitHub/GitLab commit history shows at a glance whether commits were made by "human" or "AI"
2. **Permission isolation**: You can configure different SSH keys or PATs for OpenClaw's Git account
3. **Avoid conflicts**: Prevent AI from accidentally modifying your human commit history

> 💡 **Tip**: Replace `xxx` with your identifier, e.g., `~/.gitconfig-openclaw`, `~/.gitconfig-bot`, etc.

### Adding Custom Mounts

To let OpenClaw access more host directories, modify `docker-compose.yml` directly:

#### Modify docker-compose.yml (Recommended)

Add new mount entries to the `openclaw-gateway` service's `volumes` section:

```yaml
services:
  openclaw-gateway:
    volumes:
      # ... existing mounts ...

      # Add custom mount
      - /your/project/path:/home/node/your/container/path:rw
```

### Common Extension Scenarios

| Scenario                      | Mount Example                                     |
| :---------------------------- | :------------------------------------------------ |
| Access host code repositories | `- ~/projects:/home/node/projects:rw`             |
| Access download files         | `- ~/Downloads:/home/node/Downloads:rw`           |
| Access sensitive configs      | `- ~/.aws:/home/node/.aws:ro` (read-only)         |
| Share team configurations     | `- /shared/team-config:/home/node/team-config:rw` |

### ⚠️ Important Notes

1. **Permission Issues**: The container runs as root by default (`user: "0:0"`), files created may appear as root ownership on host
2. **Path Format**: Windows paths need Docker-style format (e.g., `//c/Users/...`) or WSL paths
3. **Read-only Mounts**: Use `:ro` suffix for directories that don't need write access - more secure
4. **Restart Required**: Volume changes require `make down && make up` to take effect

---

## 📂 Directory Structure

| Path                      | Category      | Description                                                                                                  |
| :------------------------ | :------------ | :----------------------------------------------------------------------------------------------------------- |
| **`Makefile`**            | 🔧 Entry       | **Core Command Set**: Unifies container lifecycle, source updates, health checks, and config backups.        |
| **`docker-compose.yml`**  | 🐳 Orchestrate | **Dev Env Definition**: Declares Gateway, CLI, and proxy services; configures Named Volumes for persistence. |
| **`Dockerfile*`**         | 🏗️ Build       | **Environment Blueprint**: Defines different development spaces (Standard, Java, Office Pro).                |
| **`.openclaw_src/`**      | 📦 Source      | **OpenClaw Core**: Source code for the automation engine. Supports sync via `make update`.                   |
| **`roles/`**              | 🤖 Roles       | **Role Configs**: (Optional) Symlink this to your host's OpenClaw workspace for unified, private management. |
| **`docker-setup.sh`**     | 🚀 Setup       | **One-Click Logic**: Handles host permission fixes, network pre-checks, `.env` generation, and builds.       |
| **`update-source.sh`**    | 🔄 Sync Tool   | **Source Hot-Pull**: Called by Makefile to auto-sync latest OpenClaw release via GitHub API.                 |
| **`.env` (.example)**     | 🔑 Config      | **Environment Keys**: Stores proxy addresses, API tokens, host path mappings, etc.                           |
| **`docs/`**               | 📚 Resources   | **Project Assets**: Architecture diagrams, design drafts, and technical specifications.                      |
| **`CLAUDE.md`**           | 🤖 AI Context  | **Agent Guide**: Provides development standards and architectural context for AI assistants.                 |
| **`~/.openclaw`**         | 📂 Host Mount  | **Persistent State**: Stores logs, downloads, Agent configs, and user-defined workflows.                     |
| **`slack-manifest.json`** | 💬 Slack       | **App Manifest**: Format for importing App configurations into the Slack API dashboard.                      |
| **`.gitignore`**          | 🙈 Git Ignore  | **VC Filter**: Prevents `.env`, `node_modules`, and local caches from being committed.                       |

---

## ❓ FAQ

**Q: Cannot access the internet or Claude API from within the container?**
A: Ensure your host proxy service (e.g., Clash/V2Ray) has "Allow LAN Connections" enabled, and the port matches those in `.env`. Use `make test-proxy` to verify.

**Q: Got error "Cannot find module '@mariozechner/pi-ai/oauth" when starting?**
A: This is because the dependency version in the pre-built image doesn't match the source code. Run the following to clean and retry:

```bash
make down && docker volume rm openclaw-node-modules && make up
```

**Cause**: The named volume persists `node_modules`. When source code is updated, dependency versions may change, but the volume retains the old version, causing module not found errors.

**Q: How to update to the latest official OpenClaw release?**
A: Simply run `make update`. The script handles extraction and directory replacement automatically.

**Q: Changed image configuration but it's not taking effect?**
A: Use `make build` instead of `make up`, or run `make rebuild` directly.

---

## 📄 License

Based on the original license of [OpenClaw](https://github.com/openclaw/openclaw). Please refer to the LICENSE file in the core source for details.
