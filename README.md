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

- 🔐 **安全隔离**：容器运行 + 独立 Git 身份 + 最小权限原则，网络仅暴露本地
- 📦 **一键就绪**：基于 Docker Compose，屏蔽繁琐依赖
- 🧠 **AI 原生集成**：内置 Claude Code、OpenCode、Pi-Mono
- 🌐 **跨境加速**：内置代理优化，直连 Google/Claude API
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
| **WSL2** | 必须安装 | [安装指南](https://docs.microsoft.com/zh-cn/windows/wsl/install) |
| **内存** | 推荐 8GB+ | Docker Desktop 最低 4GB |
| **虚拟化** | 需在 BIOS/UEFI 中启用 | Intel VT-x / AMD-V |

> [!TIP]
> Windows 推荐使用 **Docker Desktop**（自带 WSL2 集成），安装后需开启 WSL2 功能：
> ```powershell
> wsl --install
> ```

---

## 🚀 快速开始

### 预构建镜像 ⭐（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit

# 2. 配置
cp .env.example .env

# 3. 拉取预构建镜像
docker pull ghcr.io/hrygo/openclaw-devkit:latest

# 4. 启动服务
make up

# 5. 访问 Web UI
# 浏览器打开 http://127.0.0.1:18789

# 6. 首次配置（必做）
make onboard
```

**预构建镜像版本**（修改 `.env` 中的 `OPENCLAW_IMAGE`）：
| 版本 | 镜像标签 |
| :--- | :--- |
| 标准版 | `ghcr.io/hrygo/openclaw-devkit:latest` |
| Office 办公版 | `ghcr.io/hrygo/openclaw-devkit:latest-office` |
| Java 增强版 | `ghcr.io/hrygo/openclaw-devkit:latest-java` |

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
