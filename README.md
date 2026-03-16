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

**OpenClaw 开发工具箱**是为 [OpenClaw](https://github.com/openclaw/openclaw) 量身定制的容器化开发环境。一键启动，秒级进入 AI 辅助编程与自动化工作状态。

---

## ✨ 核心特性

- 📦 **一键就绪**：基于 Docker Compose，屏蔽繁琐依赖
- 🧩 **1+3 阶梯架构**：采用高效的「1个基座 + 3类堆栈」设计，极致 DRY
- 🧠 **AI 原生集成**：内置 Claude Code、OpenCode、Pi-Mono
- 🔧 **开箱即用**：预配置开发环境，无需手动搭建
- 🚀 **快速启动**：一键部署，分秒间启动完整开发栈
- 🔒 **安全隔离**：容器化运行，环境隔离安全可控
- 💾 **数据持久化**：会话、配置自动保存，重启不丢失

---

## 前置条件

### 通用要求
- **Docker**: V2 (Docker Desktop for macOS/Windows, Docker Engine for Linux)
- **Docker Compose**: V2 (内置于 Docker Desktop)
- **Make**: macOS/Linux 自带，Windows 用户**强烈推荐**安装并使用 [Git Bash](https://git-scm.com/download/win)（Windows 原生命令行存在兼容性问题）

### Windows 用户特殊要求

| 组件 | 要求 | 说明 |
| :--- | :--- | :--- |
| **操作系统** | Windows 10 21H2+ 或 Windows 11 | |
| **后端引擎** | WSL2 (推荐) 或 Hyper-V | [安装指南](https://docs.microsoft.com/zh-cn/windows/wsl/install) |
| **内存** | 推荐 8GB+ | Docker Desktop 最低 4GB |
| **虚拟化** | 需在 BIOS/UEFI 中启用 | Intel VT-x / AMD-V |

> [!TIP]
> Windows 推荐使用 **Docker Desktop** 基于 WSL2 后端运行（性能更佳）。若使用 WSL2，需在 PowerShell 中执行以下命令启用：
> ```powershell
> wsl --install
> ```
> *(注：Windows 10/11 专业版及更高版本用户也可选择使用传统的 Hyper-V 后端，此时无需安装 WSL2。)*

---

## 🚀 快速开始

### 1. 标准安装 ⭐（推荐 - 极速模式）

适用于大多数用户，直接从 GitHub 注册表拉取经过优化的预构建镜像，**无需本地编译**。

```bash
# 1. 下载并安装 (极速模式)
git clone https://github.com/hrygo/openclaw-devkit.git && cd openclaw-devkit
make install

# 2. 交互式配置 (初次使用)
make onboard

# 3. 开启全人工直联 (推荐)
make dashboard

# 4. 批准配对请求 (首次访问 Web UI)
make approve
```

> [!NOTE]
> `make install` 会自动完成：创建数据目录、生成 `.env` 配置、同步镜像以及修复宿主机权限。
> **注意**：为了保证安装速度，`make install` 优先使用本地已有的镜像。**如果您不是首次安装，建议执行 `make rebuild` 以拉取最新镜像版本。**

### 版本选择

根据您的开发需求选择合适的版本：

| 版本 | 镜像标签 | 适用场景 | 核心工具 |
| :--- | :--- | :--- | :--- |
| **标准版** | `latest` | 通用 Web 开发 | Node.js 22, Bun, Claude Code, Playwright, Python 3 |
| **Go 版** | `go` | Go 后端开发 | 标准版 + Go 1.26, golangci-lint, gopls, dlv |
| **Java 版** | `java` | Java 后端开发 | 标准版 + JDK 21, Gradle, Maven |
| **Office 版** | `office` | 文档处理/RAG | 标准版 + LibreOffice, pandoc, LaTeX, Docling, Marker-PDF |

```bash
# 安装指定版本
make install go
make install java
make install office
```

首次安装后修改 `.env` 中的 `OPENCLAW_IMAGE`，然后执行 `make rebuild` 切换版本。

### 日常运维

| 场景 | 命令 |
| :--- | :--- |
| 启动服务 | `make up` |
| 停止服务 | `make down` |
| 重启服务 | `make restart` |
| 查看状态 | `make status` |
| 查看日志 | `make logs` |
| 进入容器 | `make shell` |
| 强制更新镜像 | `make rebuild` |

---

## ❓ 常见问题

<details>
<summary><b>Q: 启动后显示"无法连接"？</b></summary>

确保代理开启「允许局域网」连接，运行 `make test-proxy` 诊断网络。
</details>

<details>
<summary><b>Q: 如何强制更新镜像到最新版本？</b></summary>

`make install` 默认使用本地缓存。若要检测并更新远程镜像，请运行：
```bash
make rebuild
```
或手动执行 `docker pull ghcr.io/hrygo/openclaw-devkit:latest`。
</details>

<details>
<summary><b>Q: 如何切换版本？</b></summary>

修改 `.env` 中的 `OPENCLAW_IMAGE`，然后执行 `make rebuild <variant>`。
</details>

<details>
<summary><b>Q: 配置文件在哪？</b></summary>

容器内 `~/.openclaw/`，宿主机通过 `openclaw-state` 卷持久化。
</details>

---

## 📚 技术文档

| 文档名称 | 描述 | 关键点 |
| :--- | :--- | :--- |
| [镜像变体指南](./docs/IMAGE_VARIANTS.md) | 详解 1+3 架构与各版本差异 | `latest`, `go`, `java`, `office` 区别 |
| [Docker 工作流](./docs/DOCKER_WORKFLOW.md) | 本地开发与 CI/CD 流程 | `make` 命令、GitHub Actions 逻辑 |
| [快速入门指南](./docs/USER_ONBOARDING.md) | 详细的配置与环境变量说明 | `.env` 配置、Claude API 设置 |
| [飞书配置](./docs/FEISHU_SETUP.md) | 聊天应用与 AI Agent 联动 | 机器人创建、Webhook 配置 |
| [Slack 配置](./docs/SLACK_SETUP_BEGINNER.md) | Slack 接入 OpenClaw | 机器人创建、Socket Mode 配置 |
| [NotebookLM 技能](./docs/NOTEBOOKLM_SKILL.md) | NotebookLM CLI 集成指南 | 播客生成、来源管理、内容导出 |
| [详细参考手册](./docs/REFERENCE.md) | 完整的 Makefile 命令参考 | 进阶运维指令、故障排查 |

**外部资源**：[OpenClaw 官方文档](https://docs.openclaw.ai) | [Claude Code 文档](https://docs.anthropic.com/en/docs/claude-code) | [notebooklm-py GitHub](https://github.com/teng-lin/notebooklm-py)

---

## 📄 许可证

基于 [OpenClaw](https://github.com/openclaw/openclaw) 原始许可。
