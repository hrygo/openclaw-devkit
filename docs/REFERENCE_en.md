# OpenClaw DevKit Detailed Reference Manual

This manual provides in-depth technical details of the OpenClaw DevKit, supplementing the simplified information found in the main `README.md`.

---

## Guide to Version Selection

### Comparison of the Three Versions

| Feature         |        Standard         |    Java Enhanced     |      Office Pro       |
| :-------------- | :---------------------: | :------------------: | :-------------------: |
| Target Audience |     Full-stack Devs     | Java Enterprise Devs |   Office Automation   |
| Core Env        |    Node, Go, Python     |    Same + JDK 25     |    Node 22, Python    |
| AI Coding Asst  |     ✅ Full Built-in     |   ✅ Full Built-in    |    Pi-Coding-Agent    |
| Web Automation  |       Playwright        |      Playwright      | Playwright + Selenium |
| Doc Conversion  |      Pandoc, LaTeX      |    Pandoc, LaTeX     | Pandoc, LaTeX (Full)  |
| OCR Recognition |            ❌            |          ❌           | Tesseract-OCR (CN/EN) |
| Image/PDF Proc  |         Pandoc          |        Pandoc        | ImageMagick, Poppler  |
| Data Analysis   |            ❌            |          ❌           |     Pandas, Numpy     |
| Build Tools     |        pnpm, Bun        |    Gradle, Maven     |       pnpm, Bun       |
| Key Highlight   | Lightweight, AI-focused | Security/Audit Tools |   All-in-one Office   |
| Image Size      |          6.4GB          |        8.08GB        |         4.7GB         |

---

## 🛠️ Maintenance Command Manual

| Category            | Command               | Description                                                    |
| :------------------ | :-------------------- | :------------------------------------------------------------- |
| **Lifecycle**       | `make up`             | Start all dev containers (detached)                            |
|                     | `make down`           | Stop and remove all containers                                 |
|                     | `make install`        | **Standard** initialization (env check, permissions, build)    |
|                     | `make install office` | **Office Pro** initialization                                  |
|                     | `make install java`   | **Java Enhanced** initialization                               |
|                     | `make restart`        | Restart all services                                           |
|                     | `make status`         | View container health, image versions, and access URLs         |
| **Build & Update**  | `make build`          | Manually build the standard image                              |
|                     | `make build-java`     | Manually build the Java enhanced image                         |
|                     | `make build-office`   | Manually build the Office Pro image                            |
|                     | `make rebuild`        | Rebuild standard image + restart services                      |
|                     | `make rebuild-java`   | Rebuild Java image + restart services                          |
|                     | `make rebuild-office` | Rebuild Office Pro image + restart services                    |
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

| Path                  | Detailed Purpose                                      |
| :-------------------- | :---------------------------------------------------- |
| `Makefile`            | Core maintenance entry, wraps complex commands        |
| `docker-compose.yml`  | Docker Compose Configuration, networking, and volumes |
| `Dockerfile`          | Standard: Includes Go, Node, Python, Playwright, etc. |
| `Dockerfile.java`     | Java Enhanced: Adds JDK 25, Gradle, Maven, etc.       |
| `.openclaw_src/`      | Stores OpenClaw core source, managed by `make update` |
| `docker-dev-setup.sh` | Initialization script for dir tree and permissions    |
| `update-source.sh`    | Incremental version sync tool                         |
| `.env.example`        | Configuration template                                |
| `docs/`               | Project assets such as architecture diagrams          |
| `CLAUDE.md`           | Guidelines for AI development assistants              |
| `slack-manifest.json` | Manifest for quick Slack App configuration            |
 
---

## 🤖 Roles Directory & Symlink Management

The `roles/` directory stores specific configurations for various Agent roles (e.g., `IDENTITY.md`, `TOOLS.md`). To balance "convenient development" and "privacy," this project recommends using **Symbolic Links (Symlinks)** for management.

### 1. Why Use Symlinks?
*   **Unified Management**: By symlinking this directory to your host's OpenClaw configuration directory (usually `~/.openclaw/workspace`), you only need to edit files once on the host, and changes take effect immediately within the DevKit.
*   **Privacy & Security**: Agent role configurations often contain private prompts or business logic. Using symlinks keeps the directory "clean" within the DevKit repository, preventing accidental commits of personal configurations to public repositories.
*   **Developer Choice**: This is optional. You can choose to create symlinks or keep local physical files directly in the `roles/` directory.

### 2. How to Create a Symlink?
Run a command similar to the following from the project root (adjust paths according to your actual setup):
```bash
# Example: Linking the roles directory to the local OpenClaw workspace
ln -s ~/.openclaw/workspace/roles roles
```

---
 
### 4. Long-term Memory System
 Using instructions in `identity.rules` to have the Agent periodically update `memory.md` within the workspace, ensuring context continuity for long-running tasks.
 
---

## 💾 Storage & Persistence

OpenClaw DevKit employs a hybrid storage strategy to accommodate various development and runtime requirements.

### 1. Named Volumes
These volumes are managed directly by the Docker engine (e.g., `openclaw-state`, `openclaw-node-modules`).
*   **High Performance**: On macOS/Windows, they bypass Docker Desktop's filesystem synchronization layers (gRPC-FUSE/Virtio-FS), providing significantly faster I/O than bind mounts.
*   **Persistence**: Data is independent of the container lifecycle. Running `make down` does not delete volumes; only `make clean-volumes` will destroy them.
*   **Initialization Behavior (Gotcha)**: When a volume is created and mounted for the **first time**, Docker copies the contents from the image's internal path to the volume. **However, once the volume exists, subsequent image updates will not overwrite the volume's contents**. This can cause "new code, old dependencies" issues (e.g., in `node_modules`). Use `make clean-volumes` to resolve such conflicts.

### 2. Bind Mounts
These map absolute paths from the host directly into the container (e.g., `workspace`, `.env`).
*   **Real-time Visibility**: Modifications made on the host (e.g., via VS Code) are immediately reflected in the container and vice versa.
*   **Permission Challenges**: On Linux hosts, UID/GID mismatches can lead to permission errors. The `docker-setup.sh` script includes automatic fixes for common scenarios.

### 3. Key Considerations & Best Practices
*   **Avoid high-frequency I/O in Bind Mounts**: Operations like `node_modules` installs or heavy Git indexing are extremely slow on macOS/Windows when using bind mounts.
*   **Data Migration**: Named volume data is stored within Docker's internal subsystem. To export data, it's recommended to use `make shell` to enter the container and then copy the files out.

---

## ⚡ Pre-installed Skills

The OpenClaw DevKit images come with a wide array of pre-installed skills to provide an out-of-the-box AI experience.

### 1. Skill Highlights
Over 50 official skills are integrated into the images (located in `/app/skills`), including:
*   **Core Tools**: `summarize`, `weather`, `skill-creator`, `model-usage`
*   **GitHub Integration**: `gh-issues`, `github`
*   **Knowledge Management**: `nano-pdf`, `obsidian`, `notion`
*   **Automation**: `tmux`, `browser-automation`
*   **Social & Communication**: `slack`, `discord`, `imsg`

### 2. Loading Mechanism
By default, the `nativeSkills` setting in `openclaw.json` is set to `auto`. Upon startup, OpenClaw automatically scans and loads all available skills from the built-in directory.

### 3. Important Notes
*   **Updates**: Pre-installed skills are updated whenever you run `make update` and rebuild your images.
*   **Custom Skills**: To add your own skills, place them in the `workspace/skills` directory. This directory is mounted into the container and automatically discovered by OpenClaw.

---
 
## 🔁 Core Logic & Workflow

1. **Makefile (Entry)** -> **docker-dev-setup.sh (Init)** -> **Dockerfile (Runtime)**.
2. **Cache Optimization**: `node_modules` and Go caches use `Named Volumes` for extreme build speed.
3. **Security**: Runs as the `node` user (UID 1000). Permissions are automatically managed by the entrypoint and setup scripts.

### Important Considerations

1. **Permission Control**: The container runs as the `node` user (UID 1000) by default.
   - **macOS/Windows**: Docker Desktop handles permission mapping automatically (usually transparent).
   - **Linux**: Files written will typically be owned by UID 1000. If you encounter permission issues, refer to the auto-fix logic in `docker-entrypoint.sh`.
2. **Path Format**: Windows paths should use Docker style (e.g., `//c/Users/...`) or WSL paths.
3. **Read-Only Mounts**: Use the `:ro` suffix for directories that don't need write access for better security.
4. **Restart Required**: Modifications to mount configurations require `make down && make up` to take effect.

---
<p align="center">
  <a href="../README_en.md">← Back to main README</a>
</p>
