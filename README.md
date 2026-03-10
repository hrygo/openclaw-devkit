# 🛠️ OpenClaw 开发工具箱 (OpenClaw DevKit)

<p align="center">
  <a href="./README_en.md">English</a> | <b>简体中文</b>
</p>

<p align="center">
  <a href="https://github.com/openclaw/openclaw"><img src="https://img.shields.io/badge/Powered%20By-OpenClaw-blue" alt="OpenClaw"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/Env-Docker-blue?logo=docker" alt="Docker"></a>
  <a href="https://claude.ai/code"><img src="https://img.shields.io/badge/With-Claude%20Code-purple" alt="Claude Code"></a>
</p>

---

**OpenClaw 开发工具箱 (DevKit)** 是为 [OpenClaw](https://github.com/openclaw/openclaw) 量身定制的容器化全栈开发环境。它不仅解决了「环境一致性」的难题，更通过深度定制的工具链，为 AI 辅助编程、自动化网页操作和跨平台服务调度提供了「开箱即用」的顶级体验。

---

## ✨ 核心特性

- 📦 **一键就绪**：基于 Docker Compose，屏蔽繁琐的底层依赖安装，秒级进入开发状态。
- 🔧 **三重马力**：
    - **Standard (标准版)**：极致轻量，集成 Go、Node、Python 及主流 AI 编码工具。
    - **Office (Pro 办公版)**：专为**文字工作者**设计，强化 OCR、PDF 处理与 UI 自动化，移除开发密集型工具。
    - **Java Enhanced (Java 增强版)**：专为企业级应用设计，深度集成 JDK 21 及整套质量审计工具链。
- 🧠 **AI 原生集成**：内置 **Claude Code**, **OpenCode** 与 **Pi-Mono**，让 AI 直接在容器内为您编写和运行代码。
- 🌐 **跨境加速**：智能代理转发机制，针对 Google/Claude API 进行了专门优化。
- 💾 **数据持久化**：采用 **Named Volumes**，实现极速构建缓存与会话持久化。

---

## 🚥 快速开始

### 方式一：使用预构建镜像 ⭐（推荐）

跳过本地构建，最快体验：

```bash
# 1. 克隆项目
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit

# 2. 拉取预构建镜像
# Office 办公版 (推荐)
docker pull ghcr.io/hrygo/openclaw-devkit:latest-office

# 标准版
# docker pull ghcr.io/hrygo/openclaw-devkit:latest

# Java 增强版
# docker pull ghcr.io/hrygo/openclaw-devkit:latest-java

# 3. 配置环境变量
cp .env.example .env
# 重点：配置 OPENCLAW_IMAGE 为你选择的版本
# OPENCLAW_IMAGE=ghcr.io/hrygo/openclaw-devkit:latest-office

# 4. 启动服务
make up
```

> [!TIP]
> 使用预构建镜像可跳过本地构建 (约 20 分钟)，快速体验完整功能。

---

### 方式二：本地构建

需要更多时间，但可完全定制。**确保已安装 Docker (V2) 和 Make**。

```bash
# 1. 初始化项目
cp .env.example .env
make update             # 同步核心源码 (首次必做)

# 2. 选择版本并启动
# 标准版 (推荐)
make install

# Office 办公/自动化版
make install office

# Java 增强版
make install java
```

> [!TIP]
> 💡 为了最佳连通性，建议在 `hosts` 中解析 `127.0.0.1 host.docker.internal` 以共享宿主机代理。

---

### 验证与访问
- **Web UI**: [http://127.0.0.1:18789](http://127.0.0.1:18789)
- **连通性测试**: `make test-proxy`
- **实时日志**: `make logs`

---

## 📊 版本能力对比

| 特性           | Standard (标准版) | Java Enhanced (增强版) |  Office (Pro 办公版)  |
| :------------- | :---------------: | :--------------------: | :-------------------: |
| 适用人群       |     全栈开发      |    Java 企业级开发     |   文案与办公自动化    |
| 核心环境       | Node, Go, Python  |     同左 + JDK 21      |    Node 22, Python    |
| AI Coding 助手 |    ✅ 完整内置     |       ✅ 完整内置       |    Pi-Coding-Agent    |
| 网页自动化     |    Playwright     |       Playwright       | Playwright + Selenium |
| 文档转换       |   Pandoc, LaTeX   |     Pandoc, LaTeX      | Pandoc, LaTeX (Full)  |
| OCR 识别       |         ❌         |           ❌            | Tesseract-OCR (中/英) |
| 图像/PDF 处理  |      Pandoc       |         Pandoc         | ImageMagick, Poppler  |
| 数据分析       |         ❌         |           ❌            |     Pandas, Numpy     |
| 工程工具       |     pnpm, Bun     |     Gradle, Maven      |       pnpm, Bun       |
| 环境特点       |   轻量、聚焦 AI   |    深度集成审计工具    |  零门槛、全集成办公   |
| 镜像大小       |       6.4GB       |         8.08GB         |         4.7GB         |

---

## 🌍 全平台支持与分发 (Multi-Arch)

本项目通过 GitHub Actions 实现了全平台镜像自动构建：
- **支持架构**: `linux/amd64` (Intel/AMD), `linux/arm64` (Apple Silicon M1/M2/M3).
- **分发渠道**: [GitHub Packages (GHCR)](https://github.com/orgs/openclaw/packages).

> [!NOTE]
> **本地编译限制**: 直接在 MacBook 上运行 `make build` 产生的镜像仅限 ARM 架构。若需分发给不同平台的服务器，请参考 GitHub Actions 配置或使用 `buildx` 进行交叉编译。

---

## 🏗️ 架构与工作流

### 项目架构图
![架构图](docs/assets/architecture.svg)

---

## 🤖 Slack 集成

快速将 OpenClaw 引入 Slack 工作流：
1.  **导入配置**：在 Slack App 设置中导入 [`slack-manifest.json`](./slack-manifest.json)。
2.  **配置令牌**：在 `.env` 中填写 `SLACK_BOT_TOKEN` 和 `SLACK_APP_TOKEN`。
3.  **配对设备**：运行 `make pairing` 并按照终端提示操作。

---

## 🛠️ 常用指令速查

| 指令                 | 描述                          |
| :------------------- | :---------------------------- |
| `make up` / `down`   | 启动 / 停止服务               |
| `make status`        | 查看环境运行健康详情          |
| `make rebuild-java`  | 一键切换/重建到 Java 增强环境 |
| `make shell`         | 进入容器内部交互环境          |
| `make backup-config` | 备份 Agent 配置到宿主机       |
| `make clean`         | 深度清理残留镜像与容器        |

### 📖 更多细节
想要了解更完整的指令说明与配置细节，请查阅：**[详细参考手册 (REFERENCE.md)](./docs/REFERENCE.md)**。

---

## 🔌 高级挂载配置

> ⚠️ **注意**：下方「宿主机路径」列中的某些路径（如 `~/.gitconfig-hotplex`）仅为示例。你需要根据**自己的实际情况**修改 `docker-compose.yml` 中的对应路径。

默认情况下，OpenClaw 容器会自动挂载以下目录，使容器内可以访问宿主机资源。

### 必需挂载（确保基本功能）

> ⚠️ 这些挂载使用 `.env` 中定义的变量 (`OPENCLAW_CONFIG_DIR`, `OPENCLAW_WORKSPACE_DIR`)，无需手动修改

| 宿主机路径 (.env 变量)          | 容器内路径                       | 用途说明                           |
| :------------------------------ | :------------------------------- | :--------------------------------- |
| `${OPENCLAW_CONFIG_DIR}`        | `/home/node/.openclaw-seed:ro`   | 配置文件种子（只读，首次启动需要） |
| `${OPENCLAW_WORKSPACE_DIR}`     | `/home/node/.openclaw/workspace` | 工作区文件（AI 工作目录，必需）    |
| `openclaw-state` (Named Volume) | `/home/node/.openclaw`           | 持久化状态（会话、凭证、日志等）   |

### 可选挂载（根据需求选择）

| 宿主机路径                           | 容器内路径                        | 用途说明                                              |
| :----------------------------------- | :-------------------------------- | :---------------------------------------------------- |
| `~/.claude`                          | `/home/node/.claude`              | Claude Code 会话状态（需要共享会话时挂载）            |
| `~/.gitconfig-xxx` (需调整)          | `/home/node/.gitconfig:ro`        | **独立 Git 身份**（给 AI 一个专属身份，与你主体区分） |
| `openclaw-node-modules` (Volume)     | `/app/node_modules`               | Node.js 依赖缓存（加快二次启动）                      |
| `openclaw-go-mod` (Volume)           | `/home/node/go/pkg/mod`           | Go 模块缓存（使用 Go 时挂载）                         |
| `openclaw-playwright-cache` (Volume) | `/home/node/.cache/ms-playwright` | Playwright 浏览器缓存（使用浏览器自动化时挂载）       |
 
### 💾 存储持久化：具名卷 (Named Volumes) vs 绑定挂载 (Bind Mounts)

本项目混合使用了两种挂载方式以平衡性能与易用性：

1. **具名卷 (Named Volumes)**：如 `openclaw-state`。
   - **优势**：由 Docker 完全管理，在 macOS/Windows 上性能极高，且完全持久化（即使删除容器，数据依然存在）。
   - **缺点**：在宿主机文件系统中「不可见」（通常存储在 Docker 内部路径），不方便直接用物理机工具编辑。
2. **绑定挂载 (Bind Mounts)**：如 `${OPENCLAW_WORKSPACE_DIR}`。
   - **优势**：直接映射宿主机目录，方便你直接用 VS Code 或 Finder 访问和编辑。
   - **缺点**：在 macOS/Windows 上由于文件系统同步开销，性能略低于具名卷；且受宿主机文件权限影响。

> [!IMPORTANT]
> **反直觉问题**：具名卷具有「初始化保护」特性。如果容器镜像内部路径已有内容，首次挂载具名卷时内容会同步到卷中；但之后镜像更新内容，具名卷**不会**自动覆盖，除非手动清理卷。更多细节请参考 [详细参考手册 (REFERENCE.md)](./docs/REFERENCE.md#💾-存储与持久化-storage--persistence)。

### 为什么使用 `~/.gitconfig-xxx` 而非 `~/.gitconfig`？

**核心原因**：给 OpenClaw 一个**独立的 Git 身份标识**，与你的主体开发环境区分开来。

| 对比       | 你的主体环境      | OpenClaw 环境          |
| :--------- | :---------------- | :--------------------- |
| 配置文件   | `~/.gitconfig`    | `~/.gitconfig-hotplex` |
| Git 用户名 | `YourName`        | `HotPlexBot01`         |
| Git 邮箱   | `you@example.com` | `noreply@hotplex.dev`  |
| 用途       | 日常开发          | AI 自动操作            |

**优势**：
1. **清晰可辨**：GitHub/GitLab 提交记录可以一眼区分是"人"还是"AI"操作的
2. **权限隔离**：可以给 OpenClaw 的 Git 账号配置不同的 SSH key 或 PAT
3. **避免冲突**：避免 AI 意外修改你的人类提交历史

> 💡 **提示**：将 `xxx` 替换为你的标识，如 `~/.gitconfig-openclaw`、`~/.gitconfig-bot` 等。

### 添加自定义挂载

如需让 OpenClaw 访问更多宿主机目录，请直接修改 `docker-compose.yml`：

#### 修改 docker-compose.yml（推荐）

在 `openclaw-gateway` 服务的 `volumes` 区域添加新的挂载条目：

```yaml
services:
  openclaw-gateway:
    volumes:
      # ... 现有挂载 ...

      # 添加自定义挂载
      - /你的/项目路径:/home/node/你的容器内路径:rw
```

> ⚠️ **注意**：当前版本 **暂不支持** 通过 `.env` 文件的 `OPENCLAW_EXTRA_MOUNTS` 变量配置。如需此功能，请在 [`docker-compose.yml`](./docker-compose.yml) 中直接添加挂载条目。

### 常见扩展场景

| 场景               | 挂载示例                                        |
| :----------------- | :---------------------------------------------- |
| 访问宿主机代码仓库 | `- ~/projects:/home/node/projects:rw`           |
| 访问下载文件       | `- ~/Downloads:/home/node/Downloads:rw`         |
| 访问敏感配置       | `- ~/.aws:/home/node/.aws:ro`（只读）           |
| 共享团队配置       | `/shared/team-config:/home/node/team-config:rw` |

### ⚠️ 注意事项

1. **权限问题**：容器默认以 root 用户运行 (`user: "0:0"`)，写入的文件在宿主机可能显示为 root 所有权
2. **路径格式**：Windows 路径需要使用 Docker 风格（如 `//c/Users/...`）或 WSL 路径
3. **只读挂载**：对不需要写入的目录使用 `:ro` 后缀，更安全
4. **重启生效**：修改挂载配置后需要 `make down && make up` 重新启动

---

## 📂 核心文件解析

- **`Makefile`**: 项目的总指挥部，封装了所有复杂运维逻辑。
- **`docker-compose.yml`**: 编排中心，负责网络隔离与数据持久化。
- **`Dockerfile*`**: 环境的基因组，定义了不同侧重的开发空间。
- **`.openclaw_src/`**: 自动化引擎的核心阵地。
- **`roles/`**: (可选) 智能体角色配置，建议通过软链接关联至 OpenClaw Workspace 以实现统一管理。
- **`.env`**: 您的个性化中心，掌控代理、端口与安全令牌。

---

## ❓ 常见问题 (FAQ)

<details>
<summary><b>Q: 容器内网络连不通？</b></summary>
A: 检查宿主机代理是否开启「允许局域网」。使用 <code>make test-proxy</code> 诊断。
</details>

<details>
<summary><b>Q: 启动时报错 "Cannot find module '@mariozechner/pi-ai/oauth"？</b></summary>
A: 这是因为预构建镜像中的依赖版本与源码不匹配。执行以下命令清理后重试：

<pre><code>make down && docker volume rm openclaw-node-modules && make up</code></pre>

<b>原因</b>：named volume 会持久化 <code>node_modules</code>，当源码更新后，依赖版本可能发生变化，但 volume 仍保留旧版本，导致模块找不到。
</details>

<details>
<summary><b>Q: 如何手动更新 OpenClaw？</b></summary>
A: 运行 <code>make update</code>。它会调用 GitHub API 自动对比并同步最新代码。
</details>

---

## 📄 许可证

本项目基于 [OpenClaw](https://github.com/openclaw/openclaw) 的原始许可。
