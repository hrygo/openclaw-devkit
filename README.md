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
- 🌐 **跨境加速**：内置代理优化，直连 Google/Claude API
- 💾 **数据持久化**：会话、配置自动保存，重启不丢失

---

## 🚀 快速开始

### 最快方式：预构建镜像 ⭐

```bash
# 1. 克隆项目
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit

# 2. 初始化并启动
cp .env.example .env
make install

# 3. 访问 Web UI
# 浏览器打开 http://127.0.0.1:18789

# 4. 首次配置（必做）
make onboard
```

> [!TIP]
> 首次运行 `make install` 会自动选择最佳镜像版本（标准版/Office 办公版/Java 增强版）。

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
