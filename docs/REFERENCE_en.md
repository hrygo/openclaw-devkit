# OpenClaw DevKit Technical Whitepaper & User Manual (2026 Industrial Grade)

This manual is the definitive technical specification and operational guide for the OpenClaw DevKit. It provides a zero-friction entry path for **beginners** and documents the underlying logic, security models, and high-performance orchestration mechanisms designed for **architects and senior developers**.

---

## 📖 Core Blueprint (Quick Navigation)

### 🟢 Beginner Tier: Fast Start & Onboarding
- [1. Fast Mode: 3-Minute Automated Deployment](#1-fast-mode-fully-automated-deployment) - Recommended for first-time setup.
- [2. Interactive Onboarding](#2-interactive-onboarding-config-guide) - Essential step to acquire AI "Soul".
- [3. Common Operation Commands](#3-common-operation-commands) - Full command table from start to hot-restart.

### 🔵 Power User Tier: Productivity Tuning & Flavor Switching
- [4. One-Click Flavor Switching](#4-one-click-version-switching) - Standard vs. Java vs. Office technical specs.
- [5. Data Persistence Deep Dive](#5-deep-dive-data-mounting--persistence) - Understanding Host Binds vs. Named Volumes.
- [6. Roles & Dev flow Optimization](#6-roles--dev-flow-optimization) - Git workflow best practices with symlinks.

### 🔴 Architect Tier: Core Logic & Security Foundation
- [7. Layered Orchestration Analysis](#7-architecture-layered-orchestration) - The mechanics of `docker-compose.build.yml` dynamic injection.
- [8. Initialization Lifecycle](#8-initialization-deep-trace) - 5 phases of permission fixing and seed populating.
- [9. Security Sandbox & Network Borders](#9-security-whitepaper-sandbox--network-binding) - Capabilities, isolation, and LAN binding.
- [Appendix: Orchestration Logic Flow (ORCHESTRATION.md)](ORCHESTRATION.md) - Deep dive into the installation lifecycle.

---

## 🟢 Beginner Tier: Seamless Start

### 1. Fast Mode (Fully Automated Deployment) ⭐
Fast Mode is the core capability of DevKit, leveraging pre-built images from GitHub Packages (GHCR) to skip the cumbersome compilation process.

**Installation Logic**:
When executing `make install`, the system automatically performs several atomic operations:
1. **Environment Audit**: Verifies that Docker and the Compose plugin are installed and healthy.
2. **Seed Population**: If the host lacks a [`.env`](.env) file, it idempotently initializes one from [`.env.example`](.env.example) and generates a 32-digit high-entropy Gateway Token.
3. **Hardware Detection**: Identifies your architecture (x86/ARM) and pulls the corresponding pre-built layers (approx. 2GB).

```bash
# 1. Clone Source (Orchestration Layer only)
git clone https://github.com/hrygo/openclaw-devkit.git && cd openclaw-devkit

# 2. Intelligent Installation
make install
```

### 2. Interactive Onboarding (Config Guide)
After deployment, OpenClaw remains in "Standby". You must inject credentials for LLM providers (e.g., Anthropic, OpenAI) and communication platforms (e.g., Feishu, Slack).

```bash
make onboard
```
**Pre-Onboarding Check**:
- **LLM API Key**: Your primary compute source.
- **App Token**: Required if integrating with enterprise chat bots.
- **Workspace ID**: Required if the AI needs to be aware of specific collaborative spaces.
> [!TIP]
> Once completed, `openclaw.json` is securely stored in `~/.openclaw` and hot-loaded by the container on startup.

### 3. Common Operation Commands
| Command | Goal | Technical Detail |
| :--- | :--- | :--- |
| `make up` | Start Services | Runs `openclaw-gateway` and `openclaw-cli` in the background. |
| `make down` | Graceful Stop | Removes containers but preserves Data Volumes and Network definitions. |
| `make logs` | Real-time Audit | Traces task distribution, WebSocket states, and error stacks. |
| `make status` | Health Probe | Displays container health, uptime, and port occupancy. |
| `make restart` | Environment Flush | Combined `down` + `up` to force config refreshes. |

---

## 🔵 Power User Tier: Productivity Scaling

### 4. Flavor Switching (Technical Matrix)
DevKit offers three curated toolchains to handle different development scenarios:

| Flavor Name | Image Size (Compressed) | Software Stack (2026 Baseline) | Core use Case |
| :--- | :--- | :--- | :--- |
| **Standard** | **~2.21 GB** | Node 22, Go 1.2x, Python 3.12, Bun | Full-stack dev, AI plugin writing, automation scripts. |
| **Office** | **~4.04 GB** | Standard + Pandoc, LaTeX, Playwright | Doc conversion, web scraping, OCR, office automation. |
| **Java** | **~2.20 GB** | Standard + JDK 25, Gradle 8.x, Maven | Enterprise Java dev, large project building & debugging. |

**How to switch**:
```bash
# Switch to Office environment
make install office
# Switch to Java environment
make install java
```

### 5. Deep Dive: Data Mounting & Persistence
To ensure AI containers are "non-volatile," we designed a dual-track persistence model:

1. **Configuration Backbone (Bind Mount)**:
   - Path: `~/.openclaw/`
   - Purpose: Stores `openclaw.json`. This is the Agent's "Identity Card," allowing direct JSON editing from the host.
2. **Workspace (Bi-directional Sync)**:
   - Path: `~/.openclaw/workspace/`
   - Purpose: Your development workbench. All file changes are synced between host and container in milliseconds.
3. **State Isolation (Named Volume)**:
   - `.openclaw-state`: Stores DB snapshots and session persistence, preventing memory loss during image updates.

### 6. Roles & Dev flow Optimization
For team collaboration or Git management, we recommend the **"Symlink Isolation Method"**:
1. Set the `roles` directory as a symbolic link to your project: `ln -s ./my-private-roles ./roles`.
2. Add the actual path or the link to [`.gitignore`](.gitignore) to keep architectures public and credentials hidden.

---

## 🔴 Architect Tier: Deep Architectural Insights

### 7. Core Logic: Layered Orchestration
The DevKit `Makefile` is a precision engine that dynamically reassembles Compose files based on environment variables:
- **Static Layer** (`docker-compose.yml`): Defines the topology.
- **Enhancement Layer** (`docker-compose.build.yml`): Activated when `OPENCLAW_SKIP_BUILD=false`, injecting Dockerfile paths and build-time proxies.
- **Dynamic Overrides**: `docker-setup.sh` generates `docker-compose.dev.extra.yml` at runtime to handle custom user mounts (`OPENCLAW_EXTRA_MOUNTS`).

### 8. Initialization Lifecycle (Deep Trace)
When you start a container, `docker-entrypoint.sh` takes over for the first 5 seconds:
1. **UID Adaptation**: Detects the host User ID and performs `chown` to fix permissions on mounted volumes, eliminating `EACCES` errors.
2. **Seed Injection**: If the workspace is empty, it automatically populates it from the internal `/home/node/.openclaw-seed`.
3. **Network Alignment**: Locks the gateway port and sets the bind address to `lan` to bypass Docker bridge network isolation.

**Visual Architecture Reference**: For precision details on every decision step, refer to [ORCHESTRATION.md](ORCHESTRATION.md).

### 9. Security Whitepaper: Sandbox & Network Binding
> [!IMPORTANT]
> **Least Privilege Principle**:
> - Containers have `NET_RAW` and `NET_ADMIN` capabilities dropped to prevent AI agents from probing host LANs.
> - `no-new-privileges` flag is enabled to cut off privilege escalation paths.
> - **Network Binding**: All Web UIs listen on `127.0.0.1` internally and are exposed via Docker port mapping to minimize the public attack surface.

---

## ❓ Troubleshooting (QA / FAQ)

<details>
<summary><b>Q: curl inside container timed out or SSL handshake failed?</b></summary>
1. Check if <code>HTTPS_PROXY</code> in <code>.env</code> points to <code>http://host.docker.internal:[PORT]</code>.
2. Ensure your host proxy software has <b>"Allow LAN"</b> enabled.
</details>

<details>
<summary><b>Q: Why is my agent.json config file missing?</b></summary>
A: Please verify the actual mount path of <code>OPENCLAW_CONFIG_DIR</code>. It defaults to <code>~/.openclaw</code>. You can verify by searching for the file directly on the host.
</details>

---

## ⚙️ Full Technical Parameter Matrix (Advanced Tuning)

| Category | Variable | Recommended | Architectural Purpose |
| :--- | :--- | :--- | :--- |
| **Orchestration** | `COMPOSE_FILE` | `docker-compose.yml` | Defines orchestration layers. Append `:docker-compose.build.yml` for local building. |
| | `OPENCLAW_SKIP_BUILD`| `true` | `true` for Pull mode, `false` for Build mode. |
| | `OPENCLAW_IMAGE` | `...:latest` | Full Tag of the target Docker image. |
| **Path Audit** | `OPENCLAW_CONFIG_DIR`| `~/.openclaw` | Path for `openclaw.json` and identity data. |
| | `OPENCLAW_WORKSPACE_DIR`| `~/path/to/ws` | The physical workbench for AI agents. |
| **Network** | `OPENCLAW_GATEWAY_TOKEN`| (Hex Token) | The unique digital handshake credential connecting CLI and Gateway. |
| **Performance** | `deploy.resources` | (Limits: 4G RAM) | Hardcoded in YAML to prevent AI agents from crashing the system via OOM. |

---

<p align="center">
  <b>OpenClaw Team | 2026 Technical Whitepaper</b><br>
  <i>Empowering Human-AI Symbiosis Through Precise Engineering</i>
</p>
