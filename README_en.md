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
- 🧠 **AI-Native Integration**: Built-in Claude Code, OpenCode, Pi-Mono
- 🔧 **Out-of-the-Box**: Pre-configured development environment, no manual setup needed
- 🚀 **Rapid Startup**: One-click deployment, start the full development stack in seconds
- 🔒 **Secure Isolation**: Containerized execution, secure and controllable environment isolation
- 📱 **Multi-Platform**: Support for macOS, Windows, and Linux
- 💾 **Data Persistence**: Sessions and configs auto-saved, survive restarts

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
# 1. Clone project
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit

# 2. One-click install & initialize (Fast Mode)
make install

# 3. First-time setup (Required)
make onboard

# 4. Access Web UI
# Open http://127.0.0.1:18789 in browser
```

> [!NOTE]
> `make install` automates: directory creation, `.env` config generation, pulling the latest images, and fixing host permissions.

---

### 2. Version Choice

Choose the right version for your development needs:

| Edition | Image Tag | Use Case | Core Tools |
| :--- | :--- | :--- | :--- |
| **Standard** | `latest` | General web development | Node.js 22, Bun, Claude Code, Playwright, Python 3 |
| **Go** | `go` | Go backend development | Standard + Go 1.26, golangci-lint, gopls, dlv |
| **Java** | `java` | Java backend development | Standard + JDK 21, Gradle, Maven |
| **Office** | `office` | Document processing/RAG | Standard + LibreOffice, pandoc, LaTeX, Docling, Marker-PDF |

**Install specific version:**

```bash
# Standard (default)
make install

# Go edition
make install go

# Java edition
make install java

# Office edition
make install office
```

**Switch version:** After initial install, modify `OPENCLAW_IMAGE` in `.env`, then run `make rebuild`

Available image tags: `latest`, `go`, `java`, `office`

---

### After Startup

| Step        | Command                                          | Description                                 |
| :---------- | :----------------------------------------------- | :------------------------------------------ |
| 1️⃣ Start     | `make up`                                        | Start container services                    |
| 2️⃣ Configure | `make onboard`                                   | Interactive setup for LLM, Feishu, channels |
| 3️⃣ Access    | [http://127.0.0.1:18789](http://127.0.0.1:18789) | Web console                                 |

---

## 🛠️ Common Commands

| Command            | Description              |
| :----------------- | :----------------------- |
| `make up` / `down` | Start / Stop services    |
| `make restart`    | Restart services (down + up) |
| `make onboard`     | Interactive setup wizard (LLM, Feishu, Slack) |
| `make status`      | View runtime status      |
| `make logs`        | View real-time logs      |
| `make shell`       | Enter container shell    |

> 📖 Complete command reference → [Detailed Reference Manual](./docs/REFERENCE.md)

---

## ❓ FAQ

<details>
<summary><b>Q: Shows "Unable to connect" after startup?</b></summary>

Ensure your proxy has "Allow LAN Connections" enabled. Run `make test-proxy` to diagnose.
</details>

<details>
<summary><b>Q: How to switch versions?</b></summary>

```bash
# Go edition
make rebuild go

# Java edition
make rebuild java

# Office edition
make rebuild office
```
</details>

<details>
<summary><b>Q: Where are config files?</b></summary>

In container at `~/.openclaw/`, persisted on host via `openclaw-state` volume.
</details>

---

---

## 📚 Technical Documentation

| Document | Description | Key Points |
| :--- | :--- | :--- |
| [Image Variants](./docs/IMAGE_VARIANTS.md) | 1+3 architecture and version differences | `latest`, `go`, `java`, `office` tags |
| [Docker Workflow](./docs/DOCKER_WORKFLOW.md) | Local development and CI/CD process | `make` commands, GitHub Actions logic |
| [Quick Start Guide](./docs/USER_ONBOARDING.md) | Configuration and environment variables | `.env` setup, Claude API configuration |
| [Feishu/Slack Setup](./docs/FEISHU_SETUP_BEGINNER_en.md) | Chat app and AI Agent integration | Bot creation, Webhook configuration |
| [Reference Manual](./docs/REFERENCE_en.md) | Detailed Makefile command reference | Advanced ops, Troubleshooting |

---

## 📄 License

Based on the original license of [OpenClaw](https://github.com/openclaw/openclaw).
