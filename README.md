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
- 🧠 **AI 原生集成**：内置 Claude Code、OpenCode、Pi-Mono
- 🔧 **开箱即用**：预配置开发环境，无需手动搭建
- 🚀 **快速启动**：一键部署，分秒间启动完整开发栈
- 🔒 **安全隔离**：容器化运行，环境隔离安全可控
- 📱 **多端支持**：支持 macOS、Windows、Linux 全平台
- 💾 **数据持久化**：会话、配置自动保存，重启不丢失

---

## 前置条件

### 通用要求
- **Docker**: V2 (Docker Desktop for macOS/Windows, Docker Engine for Linux)
- **Docker Compose**: V2 (内置于 Docker Desktop)
- **Make**: macOS/Linux 自带，Windows 需安装 [Make for Windows](https://gnuwin32.sourceforge.net/packages/make.htm) 或使用 [Git Bash](https://git-scm.com/download/win)

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
# 1. 克隆项目
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit

# 2. 一键安装并初始化 (极速模式)
make install

# 3. 首次配置（必做）
make onboard

# 4. 访问 Web UI
# 浏览器打开 http://127.0.0.1:18789
```

> [!NOTE]
> `make install` 会自动完成：创建数据目录、生成 `.env` 配置、拉取最新镜像以及修复宿主机权限。

---

### 2. 版本选择

如果您需要特定环境，可以在安装时指定（或修改 `.env` 中的 `OPENCLAW_IMAGE`）：

| 版本 | 安装命令 | 说明 |
| :--- | :--- | :--- |
| **标准版** | `make install` | 默认版本 (Node + Go + Python + Playwright) |
| **Office 版** | `make install office` | 含 pandoc + LaTeX + OCR |
| **Java 版** | `make install java` | 含 JDK 21 + Gradle + Maven |

---

### 启动后的操作

| 步骤 | 命令 | 说明 |
| :--- | :--- | :--- |
| 1️⃣ 启动 | `make up` | 启动容器服务 |
| 2️⃣ 配置 | `make onboard` | 交互式配置 LLM、飞书、频道等 |
| 3️⃣ 访问 | [http://127.0.0.1:18789](http://127.0.0.1:18789) | Web 控制台 |

---

## 🛠️ 常用指令

| 指令 | 描述 |
| :--- | :--- |
| `make up` / `down` | 启动 / 停止服务 |
| `make onboard` | 交互式配置向导 |
| `make status` | 查看运行状态 |
| `make logs` | 查看实时日志 |
| `make shell` | 进入容器 Shell |
| `make update` | 更新 OpenClaw 源码 |

> 📖 更完整的命令说明 → [详细参考手册](./docs/REFERENCE.md)

---

## ❓ 常见问题

<details>
<summary><b>Q: 启动后显示"无法连接"？</b></summary>

确保代理开启「允许局域网」连接，运行 `make test-proxy` 诊断网络。
</details>

<details>
<summary><b>Q: 如何切换版本？</b></summary>

```bash
# Office 办公版
make rebuild office

# Java 增强版
make rebuild java
```
</details>

<details>
<summary><b>Q: 配置文件在哪？</b></summary>

容器内 `~/.openclaw/`，宿主机通过 `openclaw-state` 卷持久化。
</details>

---

## 📄 许可证

基于 [OpenClaw](https://github.com/openclaw/openclaw) 原始许可。
