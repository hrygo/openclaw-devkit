# OpenClaw Development Kit (OpenClaw DevKit)

English | [简体中文](./README.md)

<p align="center">
  <a href="https://github.com/openclaw/openclaw"><img src="https://img.shields.io/badge/Powered%20By-OpenClaw-blue" alt="OpenClaw"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/Environment-Docker-blue?logo=docker" alt="Docker"></a>
  <a href="https://claude.ai/code"><img src="https://img.shields.io/badge/Built%20With-Claude%20Code-purple" alt="Claude Code"></a>
</p>

**OpenClaw DevKit** provides a complete containerized development, debugging, and runtime environment for the [OpenClaw](https://github.com/openclaw/openclaw) multi-channel AI productivity tool.

It integrates an out-of-the-box toolchain designed to help developers quickly build AI workflows based on OpenClaw, supporting automatic source updates, one-click environment setup, and built-in network optimization for various environments.

---

## ✨ Key Features

- 🚀 **One-Click Environment Setup**: Based on Docker Compose, start a complete development environment in seconds.
- 🛠️ **Dual Image Version Selection**:
    - **Standard Edition (Dockerfile.dev)**: Integrated with Go 1.26, Node 22 LTS, Python 3.13, pnpm, Bun, Playwright, etc.
    - **Java Enhanced Edition (Dockerfile.java)**: Deeply integrated with **JDK 25 (LTS)**, Google Java Format, Checkstyle, architectural checks, and other enterprise-grade tools on top of the standard edition.
- 🧠 **AI-Native Integration**: Built-in **Claude Code**, **OpenCode**, and **Pi-Mono**, allowing AI to write and run code directly within the container for you.
- 🌐 **Global Acceleration**: Intelligent proxy forwarding mechanism specifically optimized for Google and Claude APIs.
- 🎥 **Automation Capabilities**: Pre-installed Playwright and all browser dependencies, supporting complex web automation tasks.
- 📝 **Document Processing**: Integrated Pandoc and LaTeX, supporting high-quality document format conversion and generation.
- 💾 **Persistence**: Utilizes **Named Volumes** for extreme build speed and persistent session data.

---

## 🚥 Quick Start (From Scratch)

If you are cloning this project for the first time, follow these steps to ensure a complete environment setup:

### 1. Prerequisites
Ensure the host machine has:
- **Docker & Docker Compose (V2)**
- **Make** (standard on most Unix-like systems)
- **Network Proxy** (Optional, for accessing Claude/Google APIs in restricted environments)
    > [!TIP]
    > 💡 **Tip**: We recommend adding `127.0.0.1 host.docker.internal` to your host machine's `hosts` file. This allows both local and containerized development to share the same proxy configuration string (`http://host.docker.internal:port`), improving environment consistency.

### 2. Initialize Environment
```bash
# 1. Prepare environment variable file
cp .env.example .env

# 2. Pull OpenClaw core source (Must do for the first time, or image build will fail)
# The script automatically pulls the latest code from GitHub Releases and extracts it to .openclaw_src/
make update

# 3. Initialize Docker development image
# This step handles permission fixes, dependency checks, and image building
make install
```

### 3. Start & Verify
```bash
# 1. Start services
make up

# 2. Verify connectivity (Optional)
# Check connectivity to Google/Claude APIs from within the container
make test-proxy
```

### 4. Access Interface
- **Web Console**: [http://127.0.0.1:18789](http://127.0.0.1:18789)
- **Debug Logs**: `make logs`

### 💡 How to Switch to Java Enhanced Edition
If you need Java development capabilities, you can switch environments with one command:
```bash
# Automatically build the Java image and restart services
make rebuild-java
```
Or switch manually via environment variables:
1. Modify `.env` file: `OPENCLAW_IMAGE=openclaw:dev-java`
2. Run `make up`

---

### Project Architecture
![Architecture Diagram](docs/assets/architecture.svg)

---

## 🔁 Core Workflow & File Collaboration

To achieve an "out-of-the-box" experience, this project establishes a self-consistent file collaboration system:

1. **Entry Layer (`Makefile`)**: Serves as the primary interface for user operations, encapsulating complex Docker commands and hiding environment interaction complexity.
2. **Initialization Layer (`docker-dev-setup.sh`)**: Triggered by `make install`. It reads `.env` configurations, pre-creates host directory trees, handles permission fixes, and calls `Dockerfile.dev` to build the customized development image.
3. **Orchestration Layer (`docker-compose.dev.yml`)**: The central dispatch center. It defines network abstractions between containers, environment variable injection, and efficient `node_modules` caching using Named Volumes.
4. **Runtime Layer (`Dockerfile.dev`)**: The physical definition of the environment. It integrates Node.js, Go, Python, and Playwright into a single container, eliminating the "it works on my machine" paradox.
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
|                  | `make restart`        | Restart all services                                        |
|                  | `make status`         | View container status and access URLs                       |
| **Build/Update** | `make build`          | Build standard image (Dockerfile.dev)                       |
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

## 📂 Directory Structure

| Path                         | Category      | Description                                                                                                                |
| :--------------------------- | :------------ | :------------------------------------------------------------------------------------------------------------------------- |
| **`Makefile`**               | 🔧 Entry       | **Core Command Set**: Unifies container lifecycle, source updates, health checks, and config backups.                      |
| **`docker-compose.dev.yml`** | 🐳 Orchestrate | **Dev Env Definition**: Declares Gateway, CLI, and proxy services; configures Named Volumes for persistence.               |
| **`Dockerfile.dev`**         | 🏗️ Build       | **Standard Dev Image**: Integrates Go, Node, Python, Playwright, Claude Code, OpenCode, Pi-Mono, etc. Base for the DevKit. |
| **`Dockerfile.java`**        | ☕ Build       | **Java Enhanced Image**: Adds JDK 25, Gradle, Maven, Spring Boot CLI, and Java auditing tools.                             |
| **`.openclaw_src/`**         | 📦 Source      | **OpenClaw Core**: Source code for the automation engine. Supports sync via `make update`.                                 |
| **`docker-dev-setup.sh`**    | 🚀 Setup       | **One-Click Logic**: Handles host permission fixes, network pre-checks, `.env` generation, and builds.                     |
| **`update-source.sh`**       | 🔄 Sync Tool   | **Source Hot-Pull**: Called by Makefile to auto-sync latest OpenClaw release via GitHub API.                               |
| **`.env` (.example)**        | 🔑 Config      | **Environment Keys**: Stores proxy addresses, API tokens, host path mappings, etc.                                         |
| **`docs/`**                  | 📚 Resources   | **Project Assets**: Architecture diagrams, design drafts, and technical specifications.                                    |
| **`CLAUDE.md`**              | 🤖 AI Context  | **Agent Guide**: Provides development standards and architectural context for AI assistants.                               |
| **`~/.openclaw`**            | 📂 Host Mount  | **Persistent State**: Stores logs, downloads, Agent configs, and user-defined workflows.                                   |
| **`slack-manifest.json`**    | 💬 Slack       | **App Manifest**: Format for importing App configurations into the Slack API dashboard.                                    |
| **`.gitignore`**             | 🙈 Git Ignore  | **VC Filter**: Prevents `.env`, `node_modules`, and local caches from being committed.                                     |

---

## ❓ FAQ

**Q: Cannot access the internet or Claude API from within the container?**
A: Ensure your host proxy service (e.g., Clash/V2Ray) has "Allow LAN Connections" enabled, and the port matches those in `.env`. Use `make test-proxy` to verify.

**Q: How to update to the latest official OpenClaw release?**
A: Simply run `make update`. The script handles extraction and directory replacement automatically.

**Q: Changed image configuration but it's not taking effect?**
A: Use `make build` instead of `make up`, or run `make rebuild` directly.

---

## 📄 License

Based on the original license of [OpenClaw](https://github.com/openclaw/openclaw). Please refer to the LICENSE file in the core source for details.
