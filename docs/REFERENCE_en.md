# OpenClaw DevKit Detailed Reference Manual

This manual provides in-depth technical details of the OpenClaw DevKit, supplementing the simplified information found in the main `README.md`.

---

## 🛠️ Maintenance Command Manual

| Category            | Command               | Description                                                    |
| :------------------ | :-------------------- | :------------------------------------------------------------- |
| **Lifecycle**       | `make up`             | Start all dev containers (detached)                            |
|                     | `make down`           | Stop and remove all containers                                 |
|                     | `make install`        | **Standard** initialization (env check, permissions, build)    |
|                     | `make install java`   | **Java Enhanced** initialization                               |
|                     | `make restart`        | Restart all services                                           |
|                     | `make status`         | View container health, image versions, and access URLs         |
| **Build & Update**  | `make build`          | Manually build the standard image                              |
|                     | `make build-java`     | Manually build the Java enhanced image                         |
|                     | `make rebuild`        | Rebuild standard image + restart services                      |
|                     | `make rebuild-java`   | Rebuild Java image + restart services                          |
|                     | `make update`         | Automatically fetch latest source from GitHub Releases         |
| **Diagnosis**       | `make logs`           | Follow Gateway service logs                                    |
|                     | `make logs-all`       | Follow all container logs                                      |
|                     | `make shell`          | Enter Gateway container bash                                   |
|                     | `make pairing`        | **Channel Pairing** (e.g., `make pairing CMD="list slack"`)    |
|                     | `make test-proxy`     | **One-click test** (Google/Claude API connectivity)            |
|                     | `make gateway-health` | Deep check for Gateway API response status                     |
| **Config & Backup** | `make backup-config`  | Backup Agents and config to `~/.openclaw-backups`              |
|                     | `make restore-config` | Interactively restore from backup files                        |
| **Cleanup**         | `make clean`          | Clean up orphan containers and dangling images                 |
|                     | `make clean-volumes`  | **WARNING**: Wipe all persistent volumes (deletes cached data) |

---

## ⚙️ Configuration Details

Defined in the `.env` file at the project root:

| Variable                | Default/Description | Explanation                                        |
| :---------------------- | :------------------ | :------------------------------------------------- |
| `OPENCLAW_CONFIG_DIR`   | `~/.openclaw`       | Path to store configuration on the host            |
| `OPENCLAW_IMAGE`        | `openclaw:dev`      | Docker image version to run                        |
| `HTTP_PROXY`            | -                   | HTTP proxy address for internal container use      |
| `HTTPS_PROXY`           | -                   | HTTPS proxy address for internal container use     |
| `SLACK_BOT_TOKEN`       | -                   | Slack Bot Token (xoxb format)                      |
| `SLACK_APP_TOKEN`       | -                   | Slack App Token (xapp format / Socket Mode)        |
| `SLACK_PRIMARY_OWNER`   | -                   | ID of the primary owner for privileged commands    |
| `OPENCLAW_GATEWAY_PORT` | `18789`             | Web access port for the Gateway                    |
| `GITHUB_TOKEN`          | -                   | Token to increase rate limits for GitHub API calls |

---

## 📂 Directory Structure Details

| Path                     | Detailed Purpose                                      |
| :----------------------- | :---------------------------------------------------- |
| `Makefile`               | Core maintenance entry, wraps complex commands        |
| `docker-compose.dev.yml` | Defins orchestration, networking, and volumes         |
| `Dockerfile.dev`         | Standard: Includes Go, Node, Python, Playwright, etc. |
| `Dockerfile.java`        | Java Enhanced: Adds JDK 25, Gradle, Maven, etc.       |
| `.openclaw_src/`         | Stores OpenClaw core source, managed by `make update` |
| `docker-dev-setup.sh`    | Initialization script for dir tree and permissions    |
| `update-source.sh`       | Incremental version sync tool                         |
| `.env.example`           | Configuration template                                |
| `docs/`                  | Project assets such as architecture diagrams          |
| `CLAUDE.md`              | Guidelines for AI development assistants              |
| `slack-manifest.json`    | Manifest for quick Slack App configuration            |

---

## 🔁 Core Collaboration Logic

1. **Makefile (Entry)** -> **docker-dev-setup.sh (Init)** -> **Dockerfile (Runtime)**.
2. **Source Persistence**: Host's `.openclaw_src` is synced with container `/app` for instant changes.
3. **Cache Optimization**: `node_modules` and Go caches use `Named Volumes` for extreme build speed.
4. **Security**: Runs as the `node` user (UID 1000). Permissions are auto-corrected by the setup script during startup using a root container.

---
<p align="center">
  <a href="../README_en.md">← Back to main README</a>
</p>
