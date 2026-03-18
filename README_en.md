# OpenClaw DevKit

<p align="center">
  English | <a href="./README.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/openclaw/openclaw"><img src="https://img.shields.io/badge/Powered%20By-OpenClaw-blue" alt="OpenClaw"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/Env-Docker-blue?logo=docker" alt="Docker"></a>
  <a href="https://claude.ai/code"><img src="https://img.shields.io/badge/With-Claude%20Code-purple" alt="Claude Code"></a>
</p>

---

**OpenClaw DevKit** is a containerized development environment for [OpenClaw](https://github.com/openclaw/openclaw). One-click startup, seconds to AI-assisted programming and automation.

---

## ✨ Key Features

- 📦 **One-Click Ready**: Based on Docker Compose, no more messy dependency installation
- 🧩 **1+3 Tier Architecture**: Efficient "1 base + 3 stacks" design,极致 DRY
- 🧠 **AI-Native Integration**: Built-in Claude Code, OpenCode, Pi-Mono
- 🔧 **Out-of-the-Box**: Pre-configured development environment, no manual setup needed
- 🚀 **Rapid Startup**: One-click deployment, start the full development stack in seconds
- 🔒 **Secure Isolation**: Containerized execution, secure and controllable environment isolation
- 💾 **Data Persistence**: Sessions and configs auto-saved, survive restarts
- 🩹 **Self-Healing Engine**: Entrypoint automatically fixes path leaks and cleans stale secrets for 100% startup success

---

## Prerequisites

### General Requirements
- **Docker**: V2 (Docker Desktop for macOS/Windows, Docker Engine for Linux)
- **Docker Compose**: V2 (built into Docker Desktop)
- **Make**: Pre-installed on macOS/Linux. Windows users are **strongly recommended** to install and use [Git Bash](https://git-scm.com/download/win) (Native Windows CLI tools may have compatibility issues)

### Windows-Specific Requirements

| Component          | Requirement                    | Notes                                                                      |
| :----------------- | :----------------------------- | :------------------------------------------------------------------------- |
| **OS**             | Windows 10 21H2+ or Windows 11 |                                                                            |
| **Backend**        | WSL2 (Recommended) or Hyper-V  | [Installation Guide](https://docs.microsoft.com/en-us/windows/wsl/install) |
| **Memory**         | 8GB+ recommended               | Docker Desktop minimum 4GB                                                 |
| **Virtualization** | Must enable in BIOS/UEFI       | Intel VT-x / AMD-V                                                         |

> [!TIP]
> Windows users are recommended to run **Docker Desktop** with the WSL2 backend for better performance. If using WSL2, enable it via PowerShell:
> ```powershell
> wsl --install
> ```
> *(Note: Windows 10/11 Pro editions and above can alternatively use the legacy Hyper-V backend without needing WSL2.)*

---

## 🚀 Quick Start

### 1. Standard Installation ⭐ (Recommended - Fast Mode)

Suitable for most users, pulls optimized pre-built images from the GitHub Registry—**no local compilation required**.

```bash
# 1. Download & Install (Fast Mode)
git clone https://github.com/hrygo/openclaw-devkit.git && cd openclaw-devkit
make install

# 2. Interactive Setup (First-time)
make onboard

# 3. Start Service
make up

# 4. Direct Access Dashboard (auto with token)
make dashboard

# 5. If "pairing required" shown, approve pairing
make approve
```

> [!NOTE]
> `make install` automates: directory creation, `.env` config generation, image synchronization, and fixing host permissions.
> **Note**: `make install` only performs setup and preparation; it **does not start services**. After installation, follow the flow to run `make onboard` and `make up`.

### First-time UI Authentication Flow

OpenClaw uses token authentication to protect the Gateway. On first UI access:

| Step | Command | Description |
| :--- | :--- | :--- |
| 1 | `make dashboard` | Generate direct link with token, auto-open browser |
| 2 | Refresh page | If "pairing required" shown, continue to next step |
| 3 | `make approve` | Approve pairing request |
| 4 | Refresh page | Authentication complete, ready to use |

### Version Choice

Choose the right version for your development needs:

| Edition | Image Tag | Use Case | Core Tools |
| :--- | :--- | :--- | :--- |
| **Standard** | `latest` | General web development | Node.js 22, Bun, Claude Code, Playwright, Python 3 |
| **Go** | `go` | Go backend development | Standard + Go 1.26, golangci-lint, gopls, dlv |
| **Java** | `java` | Java backend development | Standard + JDK 21, Gradle, Maven |
| **Office** | `office` | Document processing/RAG | Standard + LibreOffice, pandoc, LaTeX, Docling, Marker-PDF |

```bash
# Install specific version
make install go
make install java
make install office
```

After initial install, modify `OPENCLAW_IMAGE` in `.env`, then run `make upgrade` to switch versions.

### Daily Operations

| Scenario | Command |
| :--- | :--- |
| Start services | `make up` |
| Stop services | `make down` |
| Restart services | `make restart` |
| View status | `make status` |
| View logs | `make logs` |
| Enter container | `make shell` |
| Force update image | `make upgrade` |

---

## ❓ FAQ

<details>
<summary><b>Q: Shows "Unable to connect" after startup?</b></summary>

Ensure your proxy has "Allow LAN Connections" enabled. Run `make test-proxy` to diagnose.
</details>

<details>
<summary><b>Q: How to force update images to the latest version?</b></summary>

`make install` uses local cache by default. To detect and update remote images, run:
```bash
make upgrade
```
Or manually execute `docker pull ghcr.io/hrygo/openclaw-devkit:latest`.
</details>

<details>
<summary><b>Q: How to switch versions?</b></summary>

Modify `OPENCLAW_IMAGE` in `.env`, then execute `make upgrade <variant>`.
</details>

<details>
<summary><b>Q: Where are config files? How to modify them from host?</b></summary>

DevKit uses **direct bind mount sharing**:

| Host Path | Container Path | Purpose |
|:----------|:--------|:------------|
| `~/.openclaw/` | `/home/node/.openclaw/` | Config files, real-time bidirectional sync |

**Modify config**: Edit `~/.openclaw/openclaw.json` directly on host, hot-loaded on startup.
</details>

<details>
<summary><b>Q: Host already has OpenClaw installed, how to resolve conflict?</b></summary>

Container and host modes compete for port 18789. `./docker-setup.sh` automatically detects and attempts to stop the host service.

To handle manually:
```bash
# View uninstall guide
make uninstall-host

# Recommended one-command uninstall
npx -y openclaw uninstall --all --yes --non-interactive
```
</details>

---

## 📚 Technical Documentation

| Document | Description | Key Points |
| :--- | :--- | :--- |
| [Image Variants](./docs/IMAGE_VARIANTS.md) | 1+3 architecture and version differences | `latest`, `go`, `java`, `office` tags |
| [Docker Workflow](./docs/DOCKER_WORKFLOW.md) | Local development and CI/CD process | `make` commands, GitHub Actions logic |
| [Quick Start Guide](./docs/USER_ONBOARDING.md) | Configuration and environment variables | `.env` setup, Claude API configuration |
| [Feishu Setup](./docs/FEISHU_SETUP_en.md) | Feishu chat app integration | Bot creation, Webhook configuration |
| [Slack Setup](./docs/SLACK_SETUP_BEGINNER_en.md) | Slack integration with OpenClaw | Bot creation, Socket Mode setup |
| [NotebookLM Skill](./docs/NOTEBOOKLM_SKILL_en.md) | NotebookLM CLI integration guide | Podcast generation, source management, export |
| [Reference Manual](./docs/REFERENCE_en.md) | Detailed Makefile command reference | Advanced ops, Troubleshooting |

**External Resources**: [OpenClaw Docs](https://docs.openclaw.ai) | [Claude Code Docs](https://docs.anthropic.com/en/docs/claude-code) | [notebooklm-py GitHub](https://github.com/teng-lin/notebooklm-py)

---

## 📄 License

Based on the original license of [OpenClaw](https://github.com/openclaw/openclaw).
