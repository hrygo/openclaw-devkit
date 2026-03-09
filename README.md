# 🛠️ OpenClaw 开发工具箱 (OpenClaw DevKit)

<p align="center">
  <a href="./README_en.md">English</a> | <b>简体中文</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" alt="Maintained">
  <a href="https://github.com/openclaw/openclaw"><img src="https://img.shields.io/badge/Powered%20By-OpenClaw-blue?style=flat-square" alt="OpenClaw"></a>
  <a href="https://www.docker.com/"><img src="https://img.shields.io/badge/Env-Docker-blue?logo=docker&style=flat-square" alt="Docker"></a>
  <a href="https://claude.ai/code"><img src="https://img.shields.io/badge/With-Claude%20Code-purple?style=flat-square" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">
</p>

---

**OpenClaw 开发工具箱 (DevKit)** 是为 [OpenClaw](https://github.com/openclaw/openclaw) 量身定制的容器化全栈开发环境。它不仅解决了「环境一致性」的难题，更通过深度定制的工具链，为 AI 辅助编程、自动化网页操作和跨平台服务调度提供了「开箱即用」的顶级体验。

---

## ✨ 核心特性

- 📦 **一键就绪**：基于 Docker Compose，屏蔽繁琐的底层依赖安装，秒级进入开发状态。
- 🔧 **双重马力**：
    - **Standard (标准版)**：极致轻量，集成 Go、Node、Python 及主流 AI 编码工具。
    - **Java Enhanced (Java 增强版)**：专为企业级应用设计，深度集成 JDK 25 及整套质量审计工具链。
- 🧠 **AI 原生集成**：内置 **Claude Code**, **OpenCode** 与 **Pi-Mono**，让 AI 直接在容器内为您编写和运行代码。
- 🌐 **跨境加速**：智能代理转发机制，针对 Google/Claude API 进行了专门优化。
- 💾 **数据持久化**：采用 **Named Volumes**，实现极速构建缓存与会话持久化。

---

## 📊 版本能力对比

| 特性             |       Standard (标准版)        |     Java Enhanced (增强版)      |
| :--------------- | :----------------------------: | :-----------------------------: |
| **基础语言**     | Node 22, Go 1.26, Python 3.13  |             ✅ 同左              |
| **包管理器**     |         pnpm, Bun, pip         |             ✅ 同左              |
| **AI 助手**      | Claude Code, OpenCode, Pi-Mono |             ✅ 同左              |
| **浏览器自动化** |     Playwright + Chromium      |             ✅ 同左              |
| **文档处理**     |         Pandoc + LaTeX         |             ✅ 同左              |
| **Java 核心**    |               ❌                |        **JDK 25 (LTS)**         |
| **工程工具**     |               ❌                |    Gradle, Maven, Spring CLI    |
| **静态分析**     |               ❌                |    PMD, Checkstyle, SpotBugs    |
| **架构治理**     |               ❌                | ArchUnit (通过 Java 工具链支持) |

---

## 🚥 快速开始

### 1. 准备环境
确保已安装 **Docker (V2)** 和 **Make**。
> [!TIP]
> 💡 为了最佳连通性，建议在 `hosts` 中解析 `127.0.0.1 host.docker.internal` 以共享宿主机代理。

### 2. 初始化项目
```bash
cp .env.example .env    # 配置环境变量
make update             # 同步核心源码 (首次必做)
```

### 3. 一键部署
```bash
# 构建并启动标准版 (推荐)
make install

# 或者构建 Java 增强版
make install java
```

### 4. 验证与访问
- **Web UI**: [http://127.0.0.1:18789](http://127.0.0.1:18789)
- **连通性测试**: `make test-proxy`
- **实时日志**: `make logs`

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

## 📂 核心文件解析

- **`Makefile`**: 项目的总指挥部，封装了所有复杂运维逻辑。
- **`docker-compose.dev.yml`**: 编排中心，负责网络隔离与数据持久化。
- **`Dockerfile.*`**: 环境的基因组，定义了两个不同侧重的开发空间。
- **`.openclaw_src/`**: 自动化引擎的核心阵地。
- **`.env`**: 您的个性化中心，掌控代理、端口与安全令牌。

---

## ❓ 常见问题 (FAQ)

<details>
<summary><b>Q: 容器内网络连不通？</b></summary>
A: 检查宿主机代理是否开启「允许局域网」。使用 <code>make test-proxy</code> 诊断。
</details>

<details>
<summary><b>Q: 如何手动更新 OpenClaw？</b></summary>
A: 运行 <code>make update</code>。它会调用 GitHub API 自动对比并同步最新代码。
</details>

---

## 📄 许可证

本项目基于 [OpenClaw](https://github.com/openclaw/openclaw) 的原始许可。
