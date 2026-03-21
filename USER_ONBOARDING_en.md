# OpenClaw DevKit User Onboarding Manual

This document describes the complete workflow from cloning the repository to finishing the configuration.

## 1. Quick Start

```bash
# 1. Installation & Configuration Flow
make install    # Environment initialization (does not start services)
make onboard    # Guided configuration (using isolated container, extremely robust)
make up         # Start Gateway service
```

> **Tip**: After the initial installation, you can just run `make up` for daily startup.

---

## 2. Complete Installation Flow

```
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit
make install [flavor]
       │
       ├─> Check Docker runtime environment
       ├─> Generate .env config file
       ├─> Prepare host directory ~/.openclaw
       ├─> Pull latest container image
       └─> Prompt for subsequent commands (make onboard & make up)
```

---

## 3. Version Choice

| Version   | Image Tag | Use Case            |
| :-------- | :-------- | :------------------ |
| Standard  | `latest`  | Web Development     |
| Go        | `go`      | Go Backend          |
| Java      | `java`    | Java Backend        |
| Office    | `office`  | Document Processing |

```bash
# Install specific version
make install go
make install java
make install office
```

---

## 4. Advanced Operations

### 4.1 Daily Maintenance

```bash
make up          # Start services
make down        # Stop services
make restart     # Restart services
make status      # View status
```

### 4.2 Diagnosis & Troubleshooting

```bash
make logs              # View Gateway logs
make shell             # Enter container Shell
make test-proxy        # Test proxy connection
docker logs openclaw-init  # View config migration logs
```

### 4.3 Build & Update

```bash
make build            # Build image (local)
make upgrade          # Upgrade image and restart service
make clean            # Clean containers and dangling images
```

---

## 5. Container Runtime Architecture

### 5.1 Startup Flow

```
make onboard
       │
       ▼
┌──────────────────────────────┐
│  Ephemeral Onboard Container │ ◄── Isolated container (docker run --rm)
│  $ openclaw onboard          │     Independent of running gateway
│  Interactive Setup           │
└──────────┬───────────────────┘
           │ Config saved to ~/.openclaw
           ▼
┌──────────────────────────────┐
│  openclaw-gateway           │ ◄── Main long-running service (make up)
│  Health Check & Self-Healing │     
│  - Auto-fix host path leaks  │     
│  - Auto-clean stale models   │     
└──────────────────────────────┘
```

### 5.2 Ports

| Port  | Service          | Description      |
| :---- | :--------------- | :--------------- |
| 18789 | Gateway Web UI   | HTTP Access      |
| 18790 | Bridge           | WebSocket Bridge |
| 18791 | Browser          | Browser Debug    |

> **Proxy Configuration**: Configure external proxy via `HTTP_PROXY`/`HTTPS_PROXY` environment variables.

### 5.3 Data Persistence

| Data Type | Host Path | Description |
| :------- | :-------------------------- | :--- |
| **Config** | `~/.openclaw/openclaw.json` | Direct edit, hot-reload |
| **Session** | `~/.claude/` (Named Vol) | Claude Code Session/Memory, auto-persisted |
| **Toolchain** | `openclaw-devkit-home` (Vol) | npm/Go/Playwright cache, auto-persisted |

---

## 6. Cockpit Ops Engine

### 6.1 One-Click Access (Dashboard)
- **Command**: `make dashboard`
- **Features**:
  - Auto-fetch token from `OPENCLAW_GATEWAY_TOKEN`
  - Generate authenticated direct URL (`http://127.0.0.1:18789/#token=xxx`)
  - Auto-open browser
- **Effect**: Bypass `gateway token missing` and reach dashboard directly.

### 6.2 Automation Pairing (Approve)
- **Command**: `make approve`
- **Logic**: Automatically identify and approve the latest `pending` request ID from Web UI.
- **Scenario**: When "pairing required" is shown on first UI access.

### 6.3 Token Authentication Mechanism

Gateway token is automatically managed:

| Component | Description |
| :--- | :--- |
| Env Var | `OPENCLAW_GATEWAY_TOKEN` (Auto-generated) |
| Config File | `gateway.auth.token` in `openclaw.json` |
| Sync | `docker-entrypoint.sh` syncs env var to config on startup |

**Auth Flow**:
```
make dashboard
      │
      ▼
Generate URL with token ──► Open browser ──► Token saved to localStorage
                                               │
                                               ▼
                                         Auth Success ✓
```

**FAQ**:

| Error | Reason | Solution |
| :--- | :--- | :--- |
| `gateway token missing` | Browser no token | Use `make dashboard` |
| `gateway token mismatch` | Token mismatch | `make restart` then `make dashboard` |
| `pairing required` | Needs approval | `make approve` |

---

## 7. Windows / WSL Optimization

Docker Health Check on Windows / WSL:
- **Grace Period**: 60s
- **Retries**: 10
- **Self-Healing**: Entrypoint script runs `doctor --fix` automatically.

---

## 8. FAQ

### Q: Startup failed with "container is unhealthy"?

**Reason**: Incompatible legacy config file.

**Fix**:
```bash
# Option 1: Auto-fix (Recommended)
make install

# Option 2: Manual fix
docker logs openclaw-init    # Check errors
docker exec openclaw-gateway openclaw doctor --fix
```

### Q: Will `make install` delete my data?

**No**. `make install` is idempotent:
- Updates `.env`
- Checks Docker permissions
- Fixes outdated config files

### Q: How to switch versions?

```bash
# Option 1: Recommended (Sync .env and restart)
make install go

# Option 2: Force pull latest image
make upgrade
```

### Q: What is the access address?

- **Web UI**: http://127.0.0.1:18789
- **Token**: Generated during first `make install`
