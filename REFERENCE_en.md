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
- [Appendix: Slack Setup](SLACK_SETUP_BEGINNER_en.md) | [Feishu Setup](FEISHU_SETUP_BEGINNER_en.md)

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
3. **Architecture Detection**: Identify hardware (x86/ARM) and pull corresponding pre-built layers

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

> Once complete, `openclaw.json` is stored in `~/.openclaw` and hot-loaded on container startup.

---

## 3. Common Commands

| Command | Description |
| :--- | :--- |
| `make up` | Start openclaw-gateway and openclaw-cli |
| `make down` | Remove containers, preserve Data Volumes |
| `make logs` | Trace task distribution, WebSocket states, error stacks |
| `make status` | Display container health, uptime, port occupancy |
| `make restart` | Execute down + up, refresh configuration |

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
make rebuild go
make rebuild java
make rebuild office
```

| Operation | Command | When |
| :--- | :--- | :--- |
| First Install | `make install <variant>` | Create data dirs and config |
| Switch Version | `make rebuild <variant>` | Already installed, need different flavor |

---

## 5. Data Persistence

Dual-track persistence ensures container non-volatility:

1. **Configuration (Bind Mount)**
   - Path: `~/.openclaw/`
   - Purpose: Stores `openclaw.json`, enables direct host editing

2. **Workspace (Bidirectional Sync)**
   - Path: `~/.openclaw/workspace/`
   - Purpose: Development workbench, millisecond-level sync between host and container

3. **State (Named Volume)**
   - `.openclaw-state`
   - Purpose: DB snapshots, session persistence prevents memory loss during image updates

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

1. **UID Adaptation**: Detect host User ID, execute `chown` to fix mounted directory permissions
2. **Seed Population**: If workspace is empty, automatically populate from `/home/node/.openclaw-seed`
3. **Network Binding**: Lock gateway port, set bind address to `lan` to bypass Docker bridge isolation

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
Verify actual mount path of `OPENCLAW_CONFIG_DIR`, defaults to `~/.openclaw`

---

## Technical Parameters

| Category | Variable | Default | Description |
| :--- | :--- | :--- | :--- |
| **Orchestration** | `COMPOSE_FILE` | `docker-compose.yml` | Defines orchestration layers |
| | `OPENCLAW_SKIP_BUILD`| `true` | true=pull, false=build |
| | `OPENCLAW_IMAGE` | `...:latest` | Docker image tag |
| **Paths** | `OPENCLAW_CONFIG_DIR`| `~/.openclaw` | Config directory |
| | `OPENCLAW_WORKSPACE_DIR`| `.../workspace` | Workspace |
| **Network** | `OPENCLAW_GATEWAY_PORT`| `18789` | Gateway port |
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
