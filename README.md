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
- 🔧 **双重马力**：
    - **Standard (标准版)**：极致轻量，集成 Go、Node、Python 及主流 AI 编码工具。
    - **Office (Pro 办公版)**：专为**文字工作者**设计，强化 OCR、PDF 处理与 UI 自动化，移除开发密集型工具。
    - **Java Enhanced (Java 增强版)**：专为企业级应用设计，深度集成 JDK 21 及整套质量审计工具链。
- 🧠 **AI 原生集成**：内置 **Claude Code**, **OpenCode** 与 **Pi-Mono**，让 AI 直接在容器内为您编写和运行代码。
- 🌐 **跨境加速**：智能代理转发机制，针对 Google/Claude API 进行了专门优化。
- 💾 **数据持久化**：采用 **Named Volumes**，实现极速构建缓存与会话持久化。

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

# 构建 Office 办公/自动化版
make install office

# 或者构建 Java 增强版
make install java
```

### 4. 验证与访问
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

## 📂 核心文件解析

- **`Makefile`**: 项目的总指挥部，封装了所有复杂运维逻辑。
- **`docker-compose.yml`**: 编排中心，负责网络隔离与数据持久化。
- **`Dockerfile*`**: 环境的基因组，定义了不同侧重的开发空间。
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
