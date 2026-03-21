# Docker Build Architecture and Workflow

A layered runtime architecture that separates static SDK environments from dynamic applications.

---

## 1. Layered Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Layer III: Product Layer - Build Frequency: High                          │
│ ghcr.io/hrygo/openclaw-devkit:latest | :go | :java | :office            │
│ Contains: OpenClaw Official Release (openclaw.ai)                         │
│ Dockerfile: Dockerfile                                                     │
└───────────────────┬─────────────────────────────────┬─────────────────────┘
                    │ FROM                             │ FROM
┌───────────────────┴─────────────────────────────────┴─────────────────────┐
│ Layer II: Stack Runtimes - Build Frequency: Low                         │
│ ghcr.io/hrygo/openclaw-runtime:go | :java | :office                    │
│ Contains: Go 1.26, JDK 21, LibreOffice, Python IDP                        │
│ Dockerfile: Dockerfile.stacks                                             │
└───────────────────────────────────┬───────────────────────────────────────┘
                                    │ FROM
┌───────────────────────────────────┴───────────────────────────────────────┐
│ Layer I: Base Foundation - Build Frequency: Extremely Low                │
│ ghcr.io/hrygo/openclaw-runtime:base                                     │
│ Contains: Debian Bookworm, Node.js 22, Bun, uv, Playwright              │
│ Dockerfile: Dockerfile.base                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Dockerfile Responsibilities

| Feature | Dockerfile.base | Dockerfile.stacks | Dockerfile |
| :--- | :--- | :--- | :--- |
| **Layer** | Layer I (Base) | Layer II (Stack) | Layer III (App) |
| **Base Image** | `debian:bookworm-slim` | `${BASE_IMAGE}` | `${BASE_IMAGE}` |
| **Build Target** | Single image | Multi-stage | Single image |
| **Build Command** | `make build-base` | `make build-stacks` | `make build` |
| **Contains** | | | |
| System Tools | yq, just, gh, lazygit | - | - |
| Runtimes | Node.js, Bun, uv | Go, JDK, Gradle, Maven | - |
| Browser Deps | Playwright deps | - | Playwright browsers |
| Python Packages | - | pandoc, libreoffice etc | notebooklm-py |
| AI Tools | - | gopls, staticcheck etc | OpenClaw, Claude Code |
| **Persistence Config** | ❌ | ❌ | ✅ Global tools dir |
| **Image Tags** | `openclaw-runtime:base` | `openclaw-runtime:{go,java,office}` | `openclaw-devkit:{latest,go,java,office}` |

### 1.2 Build Order

```bash
# 1. Build base image (Layer I) - on first run or system dependency updates
make build-base
# → Output: openclaw-runtime:base

# 2. Build stack images (Layer II) - on first run or Go/Java/Office updates
make build-stacks
# → Output: openclaw-runtime:go, openclaw-runtime:java, openclaw-runtime:office

# 3. Build app image (Layer III) - on every OpenClaw update
make build        # Standard version (based on base)
make build-go     # Go version (based on go)
make build-java   # Java version (based on java)
make build-office # Office version (based on office)
# → Output: openclaw-devkit:latest, :go, :java, :office
```

---

## 2. Local Build

```bash
# Build standard version
make build

# Build specific version
make build-go
make build-java
make build-office
```

**Execution Flow:**
```
make build-go
       │
       ▼
Check if openclaw-runtime:go exists
       │
       ▼
docker build -f Dockerfile
  --build-arg BASE_IMAGE=openclaw-runtime:go
  -t ghcr.io/hrygo/openclaw-devkit:go .
       │
       ▼
FROM openclaw-runtime:go (already includes Go SDK)
RUN npm install -g openclaw
```

---

## 3. CI/CD Build

Driven by `.github/workflows/docker-publish.yml`:

```
[prepare] ─────────────────────────────┐
      │                                │
      ▼                                ▼
[build-base]                          │ Version aware
      │                                │
      ▼                                │
[build-stacks] ───────────────┐        │
      │                       │        │
      ▼                       ▼        ▼
[build-products] <───────────┴────────┘
      │
      ▼
Push to GHCR:
  ghcr.io/hrygo/openclaw-runtime:base
  ghcr.io/hrygo/openclaw-runtime:{go,java,office}
  ghcr.io/hrygo/openclaw-devkit:{latest,go,java,office}
  ghcr.io/hrygo/openclaw-devkit:v1.6.2
```

---

## 4. Build Arguments

| Argument | Default | Description |
| :----------------- | :--------------- | :-------------- |
| `HTTP_PROXY` | - | Network proxy |
| `APT_MIRROR` | `deb.debian.org` | Debian mirror |
| `OPENCLAW_VERSION` | `latest` | OpenClaw version |
| `INSTALL_BROWSER` | `0` | Install Playwright |

---

## 5. Runtime Variables

| Variable | Default | Description |
| :----------------------- | :------------------------------ | :----------- |
| `HOST_OPENCLAW_DIR` | `~/.openclaw` | Host config directory (direct bind mount) |
| `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway port |
| `OPENCLAW_GATEWAY_BIND` | `lan` | Gateway bind mode (lan=all interfaces, local=127.0.0.1 only) |

---

## 6. Image Update Mechanism

Image updates follow this priority logic:

### 6.1 Priority

1. **Local First (`make install`)**:
   - System first checks if local image with matching tag exists.
   - If exists, starts directly without checking remote version differences.
2. **Force Pull (`make upgrade`)**:
   - Calls `docker pull` to check Image Digest between local and remote.
   - If remote has updates, automatically downloads and replaces, then restarts container.

### 6.2 Common Commands

| Scenario | Command | Behavior |
| :------------------ | :-------------------- | :--------------------------------- |
| **First Install** | `make install` | Pulls image and initializes environment |
| **Daily Start** | `make up` | Quick start, no network overhead |
| **Update** | `make upgrade` | Checks updates, pulls and restarts |
| **Manual** | `docker pull <image>` | Updates image only, doesn't affect running container |

---

## 7. Troubleshooting

### Path Compatibility and Permissions
Traditional Docker mounts can cause `EACCES` or path errors due to host-container path mismatches. OpenClaw DevKit implements **fully automatic self-healing**:
- **Path Surgery**: Automatically migrates host paths (like `/Users/xxx`) in config/logs to container standard paths on startup.
- **Incremental Repair**: Uses marker files to ensure heavy full scans only run once; daily starts don't wait.
- **Leak Prevention**: Uses `OPENCLAW_HOME` etc to forcibly lock path generation for barrier-free execution.

### Directory Mapping and Mount Logic (Mount Hierarchy)

DevKit uses **layered named volumes + bind mount sharing**:

| Host Path | Container Path | Type | Purpose |
| :--- | :--- | :--- | :--- |
| `openclaw-devkit-home` | `/home/node/` | Named Volume | **Toolchain persistence**. npm/pnpm/bun packages, Go ecosystem, Playwright cache. |
| `openclaw-claude-home` | `/home/node/.claude/` | Named Volume | **Claude Code persistence**. Session, Memory, Skills state, survives rebuilds. |
| `~/.openclaw/` | `/home/node/.openclaw/` | Bind Mount (rw) | **User config sharing**. openclaw.json, identity, agents — real-time bidirectional sync. |
| `~/.notebooklm/` | `/home/node/.notebooklm/` | Bind Mount (rw) | NotebookLM CLI state |
| `~/.claude/settings.json` | `/home/node/.claude/settings.json` | Bind Mount (ro) | Claude Code config read-only share |
| `~/.claude/skills/` | `/home/node/.claude/skills/` | Bind Mount (ro) | Claude Code Skills read-only share |
| `~/.agents/skills/` | `/home/node/.agents/skills/` | Bind Mount (ro) | .agents Skills read-only share |

#### How to Modify Config?
- Edit **`~/.openclaw/openclaw.json`** directly on host, hot-loaded in container on save — no restart needed.

### Permission Migration
Container entrypoint script automatically fixes UID/GID permissions on host-mounted directories.

### Cleanup
```bash
make clean            # Containers and dangling images
make clean-volumes   # All data volumes (careful! loses npm/Go/Claude Code cache)
```

---

## 8. Cockpit Operations Engine

Cockpit provides the following operations:

### 8.1 Dashboard (One-Click Access)
- **Command**: `make dashboard`
- **Logic**: Auto-fetches container Gateway Token and generates URL with credentials.
- **Effect**: Bypasses `pairing required` interception for direct dashboard access.

### 8.2 Auto-Approval
- **Command**: `make approve`
- **Logic**: Automatically identifies latest `pending` request ID from Web UI and approves it.
- **Scenario**: When webpage shows "pending pairing" status, run this to immediately approve.

---

## 9. Windows / WSL Adaptation

Docker health check configuration for Windows / WSL environments:
- **Grace Period (`start_period`)**: 60s
- **Retries**: 10 times
- **Self-Healing**: Entrypoint automatically runs `doctor --fix` on startup

---

## 10. Architecture Advantages

- **DRY**: Build logic centralized in Makefile
- **Caching**: Layer I/II from local cache when updating versions
- **Independence**: Each layer can be tested and released independently

---

## 11. Global Tools Persistence

OpenClaw container supports installing any tools at runtime (npm/pnpm/bun/uv), automatically retained after restarts.

### 11.1 Persistence Principle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Named Volume: openclaw-devkit-home                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ /home/node/.global/  (npm/pnpm/bun tools)                            ││
│  │ /home/node/.local/    (Python CLI tools, uv pip install --user)       ││
│  │ /home/node/.cache/   (Playwright browser cache etc.)                   ││
│  │ /home/node/go/       (Go SDK and toolchain)                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│  Named Volume: openclaw-claude-home                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ /home/node/.claude/ (Session, Memory, Skills state)                   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Supported Package Managers

| Package Manager | Install Command Example | Persisted Location |
| :------ | :---------- | :-------- |
| **npm** | `npm install -g some-tool` | `/home/node/.global` |
| **pnpm** | `pnpm add -g some-tool` | `/home/node/.global` |
| **bun** | `bun install -g some-tool` | `/home/node/.global` |
| **uv (Python)** | `uv pip install --user some-tool` | `/home/node/.local` |

### 11.3 How It Works

- **At Image Build (Dockerfile)**: Pre-configures all package managers to use unified global directory
- **At Container Start (docker-compose.yml)**: Mounts named volumes to ensure data persistence
- **At Runtime (docker-entrypoint.sh)**: Auto-fixes permissions, ensures PATH is correct

### 11.4 Usage

No additional configuration needed - OpenClaw-installed tools automatically persist:

```bash
# Rebuild image then start
make down
make build
make up

# Install tools in container - survives restart
make shell
npm install -g my-tool
pnpm add -g another-tool
uv pip install --user python-tool

# Exit container, restart to verify
exit
make down && make up
make shell
which my-tool  # Tool still exists!
```

### 11.5 Notes

- **First Rebuild**: Configuration takes effect at image build time, works automatically after first `make build`
- **Tool Migration**: Previously installed tools in old locations won't auto-migrate, need manual reinstall
- **Cleanup**: To clear all persisted tools, run:
  ```bash
  docker volume rm openclaw-devkit-home openclaw-claude-home
  ```
