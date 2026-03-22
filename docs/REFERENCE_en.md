# OpenClaw DevKit Technical Specification & Operation Guide

This document serves as the definitive technical specification and operational guide for OpenClaw DevKit, providing an entry path for beginners and documenting underlying logic, security models, and orchestration mechanisms for architects and senior developers.

---

## Core Navigation

### Beginner Tier: Quick Start
- [1. Fast Mode](#1-fast-mode) - 3-minute automated deployment
- [2. Interactive Configuration](#2-interactive-configuration) - Acquire AI credentials
- [3. Common Commands](#3-common-commands) - Complete command reference

### Power User Tier: Productivity
- [4. Version Switching](#4-version-switching) - Standard vs. Java vs. Office specs
- [5. Data Persistence](#5-data-persistence) - Bind Mount vs. Named Volumes
- [6. Roles Workflow](#6-roles-workflow) - Symlink isolation best practices
- [7. Custom Images](#7-custom-images) - Non-intrusive extensibility
- [Appendix: Slack Setup](SLACK_SETUP_BEGINNER_en.md) | [Feishu Setup](FEISHU_SETUP_BEGINNER_en.md) | [gogcli Setup](GOGCLI_SETUP_en.md)

### Architect Tier: Architecture
- [8. Layered Orchestration](#8-layered-orchestration) - Docker Compose dynamic injection
- [9. Initialization Lifecycle](#9-initialization-lifecycle) - Permission fixing and seed population
- [10. Security](#10-security) - Sandbox and network isolation

---

## 1. Fast Mode

Fast Mode leverages GitHub Packages (GHCR) pre-built images for rapid deployment.

**Installation Logic**:
Executing `make install` triggers the following operations:
1. **Environment Check**: Verify Docker and Compose plugin availability
2. **Config Initialization**: If `.env` is missing, initialize from `.env.example` and generate 32-digit Gateway Token
3. **Architecture Detection**: Identify hardware (x86/ARM) and prepare corresponding pre-built layers.
> [!IMPORTANT]
> `make install` only performs setup and preparation; it **does not start services**. After installation, follow the flow to run `make onboard` and `make up`.

```bash
# Clone source
git clone https://github.com/hrygo/openclaw-devkit.git && cd openclaw-devkit

# One-command install
make install
```

---

## 2. Interactive Configuration

After deployment, OpenClaw remains in standby. Inject credentials for LLM providers and communication platforms.

```bash
make onboard
```

**Configuration Checklist**:
- **LLM API Key**: Primary compute source
- **App Token**: Required for enterprise chat bot integration
- **Workspace ID**: Required if AI needs awareness of specific collaborative spaces

> Once complete, `openclaw.json` is stored in container's `/home/node/.openclaw/` (maps to host's `~/.openclaw/`, directly shared via bind mount) and hot-loaded on startup.

---

## 3. Common Commands

### Quick Start

| Command | Description |
| :--- | :--- |
| `make help` | Show all available commands |
| `make install` | Environment initialization (does not start services) |
| `make onboard` | Interactive configuration (uses ephemeral container for stability) |

### Lifecycle Management

| Command | Description |
| :--- | :--- |
| `make up` / `make start` | Start openclaw-gateway service |
| `make down` / `make stop` | Remove containers, preserve Data Volumes |
| `make restart` | Execute down + up, refresh configuration |
| `make status` | Display container health, uptime, port occupancy |

### Build & Update

| Command | Description |
| :--- | :--- |
| `make build` | Build standard image |
| `make build-go` | Build Go variant image |
| `make build-java` | Build Java variant image |
| `make build-office` | Build Office variant image |
| `make upgrade` | Upgrade image and restart service |
| `make update` | Sync latest code from GitHub |

### Debugging

| Command | Description |
| :--- | :--- |
| `make logs` | Trace task distribution, WebSocket states, error stacks |
| `make logs-all` | View all container logs |
| `make shell` | Enter Gateway container |
| `make run` | Interactive container access |
| `make exec CMD="..."` | Execute command in container |
| `make cli CMD="..."` | Execute OpenClaw CLI command |
| `make verify` | Verify image tool versions |
| `make test-proxy` | Test proxy connection |

### Device Management

| Command | Description |
| :--- | :--- |
| `make devices` | List paired devices |
| `make approve` | Approve pairing request |
| `make pairing` / `make pair` | Channel pairing |
| `make dashboard` | Quick access to dashboard |
| `make health` | Check health status |

### Backup & Restore

| Command | Description |
| :--- | :--- |
| `make backup` | Backup configuration files |
| `make restore FILE=...` | Restore configuration |
| `make clean` | Clean containers and dangling images |
| `make clean-volumes` | Clean all data volumes (dangerous!) |

---

## 4. Version Switching

DevKit offers four vertical toolchains:

| Flavor | Image Size | Core Use Case |
| :--- | :--- | :--- |
| **Standard** | ~2.21 GB | Full-stack dev, AI plugins, automation |
| **Go** | ~2.30 GB | Go backend, dlv debugging, static analysis |
| **Java** | ~2.20 GB | Enterprise Java, Gradle/Maven builds |
| **Office** | ~4.04 GB | Document conversion, OCR, office automation |

```bash
# First-time install
make install go
make install java
make install office

# Switch later
make upgrade go
make upgrade java
make upgrade office
```

| Operation | Command | When |
| :--- | :--- | :--- |
| First Install | `make install <variant>` | Create data dirs and config |
| Switch Version | `make upgrade <variant>` | Already installed, need different flavor |

---

## 5. Data Persistence

Layered named volumes + bind mount sharing:

1. **Named Volume: openclaw-claude-home**
   - Container path: `~/.claude/`
   - Purpose: Claude Code Session, Memory, Skills state — **survives image rebuilds**

2. **Named Volume: openclaw-devkit-home**
   - Container path: `~/.global/`, `~/.local/`, `~/.cache/`, `~/.go/`
   - Purpose: Runtime-installed CLI tools (npm/pnpm/bun/uv/Go) — **survives image rebuilds**

3. **Bind Mount: HOST_OPENCLAW_DIR** (default `~/.openclaw/`)
   - Host `~/.openclaw/` ↔ Container `/home/node/.openclaw/`
   - Purpose: Config file real-time bidirectional sync — **edit host's `openclaw.json` for hot-reload**

4. **Read-only Bind Mounts**
   - `~/.claude/settings.json` → Container `~/.claude/settings.json` (ro)
   - `~/.claude/skills/` → Container `~/.claude/skills/` (ro)
   - `~/.agents/skills/` → Container `~/.agents/skills/` (ro)

5. **Skills System**
   - Skills are stored in `~/.agents/skills/` (container path: `/home/node/.agents/skills/`)
   - OpenClaw config `skills.load.extraDirs` points to the centralized skills directory
   - **Security Note**: OpenClaw 2026-03-07+ security update rejects skills with symlinks pointing outside `~/.openclaw/skills/` root (triggers `Skipping skill path that resolves outside its configured root` warning)
   - **ClawHub Install Tip**: Run `clawhub install` from your home directory (`~`) not from `~/.openclaw/`

---

## 6. Roles Workflow

For team collaboration or Git management, use symlink isolation to protect private tokens:

```bash
# Create symlink
ln -s ./my-private-roles ./roles

# Add to .gitignore
```

---

## 7. Custom Images

### Approach A: Extend Official Image

Create `Dockerfile.custom` based on official image:

```dockerfile
FROM ghcr.io/hrygo/openclaw-devkit:latest
USER root
RUN apt-get update && apt-get install -y ffmpeg
USER node
```

Declare `OPENCLAW_IMAGE=my-custom-openclaw:dev` in `.env` to switch.

### Approach B: Compose Override

Create `docker-compose.override.yml` to add volumes and parameters without modifying core configuration.

---

## 8. Layered Orchestration

Makefile dynamically reassembles Compose files based on environment variables:

- **Static Layer** (`docker-compose.yml`): Defines topology
- **Enhancement Layer** (`docker-compose.build.yml`): Activates when `OPENCLAW_SKIP_BUILD=false`, injects build parameters
- **Dynamic Overrides**: `docker-setup.sh` generates `docker-compose.dev.extra.yml` at runtime to handle custom mounts

---

## 9. Initialization Lifecycle

On container start, `docker-entrypoint.sh` executes:

1. **Host OpenClaw Conflict Detection**: Detects launchd/systemd/processes, auto-stops and prompts uninstall guide.
2. **UID Adaptation**: Detect host User ID, execute `chown` to fix mounted directory permissions.
3. **Hot Initialization**: If `~/.openclaw/openclaw.json` does not exist, run `openclaw onboard --non-interactive` to initialize.
4. **.claude.json Protection**: If `~/.claude.json` does not exist, automatically create empty placeholder.
5. **Self-Healing Mechanics**:
   - **Path Surgery**: Automatically migrates leaked host paths (Mac/Linux) to container-standard paths, preventing `EACCES`.
   - **Phantom Secret Cleanup**: Automatically prunes invalid model configs referencing missing environment variables, ensuring 100% gateway startup success.
6. **Gateway Config Hardening**: Locks `gateway.bind=lan`, `gateway.mode=local`, auto-appends allowedOrigins.
7. **Global Tools Directories**: Ensures `/home/node/.global/`, `/home/node/.local/` exist and fixes permissions.

---

## 10. Security

**Least Privilege Principle**:
- Containers drop `NET_RAW` and `NET_ADMIN` capabilities to prevent AI from probing host LAN
- Enable `no-new-privileges` flag to block privilege escalation paths
- Web UI listens only on `127.0.0.1`, exposed via Docker port mapping

---

## Troubleshooting

### Q: curl inside container timed out or SSL handshake failed?
1. Check if `HTTPS_PROXY` in `.env` points to `http://host.docker.internal:[PORT]`
2. Verify proxy software has "Allow LAN" enabled

### Q: Why is my agent.json config file missing?
Check actual path of `HOST_OPENCLAW_DIR`, defaults to `~/.openclaw`

---

## Technical Parameters

| Category | Variable | Default | Description |
| :--- | :--- | :--- | :--- |
| **Orchestration** | `COMPOSE_FILE` | `docker-compose.yml` | Defines orchestration layers |
| | `OPENCLAW_SKIP_BUILD`| `true` | true=pull, false=build |
| | `OPENCLAW_IMAGE` | `...:latest` | Docker image tag |
| **Host Paths** | `HOST_OPENCLAW_DIR`| `~/.openclaw` | Host config directory (direct bind mount share) |
| **Container Paths** | `OPENCLAW_HOME` | `/home/node` | Container root home |
| **Network** | `OPENCLAW_GATEWAY_PORT`| `18789` | Gateway port |
| | `OPENCLAW_GATEWAY_BIND`| `lan` | Bind mode (lan=all interfaces, local=127.0.0.1 only) |
| | `OPENCLAW_GATEWAY_TOKEN`| (Hex) | CLI-Gateway handshake |
| | `HTTP[S]_PROXY` | - | Container outbound proxy |
| **Acceleration** | `DOCKER_MIRROR` | `docker.io` | Docker Hub mirror |
| | `APT_MIRROR` | `ustc` | Debian mirror |
| | `NPM_MIRROR` | - | pnpm mirror |
| | `PYTHON_MIRROR` | - | pip mirror |
| **Extension** | `OPENCLAW_HOME_VOLUME`| - | Named volume for `/home/node` |
| | `OPENCLAW_EXTRA_MOUNTS`| - | Extra mounts `src:dst[:ro]` |
| **Resources** | `deploy.resources` | 4G RAM | Memory limit |

---

<p align="center">
  <b>OpenClaw Team | Technical Specification</b><br>
  <i>Empowering Human-AI Symbiosis Through Precise Engineering</i>
</p>
