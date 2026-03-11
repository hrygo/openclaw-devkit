# OpenClaw DevKit 技术白皮书与用户手册

本手册是 OpenClaw DevKit 的权威技术规格书与操作指南。它不仅为**初学者**提供零门槛的快速入门路径，更记录了为**架构师与资深开发者**设计的底层逻辑、安全模型与高性能编排机制。

---

## 📖 核心蓝图 (Quick Navigation)

### 🟢 基础篇：快速启动与上手
- [1. 极速模式：3 分钟全自动部署](#1-极速模式-全自动快车道) - 零基础首选方案。
- [2. 交互式 Onboarding](#2-交互式-onboarding-配置引导) - 获取 AI “灵魂”的必经环节。
- [3. 常用运维指令全集](#3-常用运维指令) - 从启动到热重启的完整命令表。

### 🔵 进阶篇：生产力调优与环境切换
- [4. 多维版本一键切换](#4-版本一键切换) - Standard vs. Java vs. Office 精确规格表。
- [5. 数据持久化深探](#5-深度解析数据挂载与持久化) - 理解 Host Bind vs. Named Volumes。
- [6. Roles 与开发流调优](#6-roles-与开发流优化) - 基于软链接的 Git 工作流最佳实践。
- [7. 高级玩法：自定义镜像与扩展编排](#7-高级玩法自定义镜像与扩展编排) - 深入最佳实践无缝扩展底层架构。
- [附：Slack 接入保姆级教程](SLACK_SETUP_BEGINNER.md) | [飞书 (Lark) 接入指南](#)

### 🔴 架构篇：底层逻辑与安全基座
- [8. 分层编排解析](#8-底层逻辑分层编排架构-layered-orchestration) - 揭秘 `docker-compose.build.yml` 的动态注入。
- [9. 环境初始化生命周期](#9-环境初始化生命周期-lifecycle-trace) - 权限修复与种子填充的 5 步走。
- [10. 安全沙盒与网络红线](#10-安全白皮书沙盒机制与网络模型) - 掉权、隔离与局域网绑定机制。
- [附录：编排流转可视化 (ORCHESTRATION.md)](ORCHESTRATION.md) - 深度内窥安装全流程。

---

## 🟢 基础篇：无障碍起步

### 1. 极速模式 (全自动快车道) ⭐
极速模式是 DevKit 的核心能力，通过 GitHub Packages (GHCR) 的预构建镜像，让您跳过繁琐的编译过程。

**安装逻辑**：
执行 `make install` 时，系统会自动执行以下原子操作：
1. **环境自检**：确认 Docker 及 Compose 插件已安装。
2. **种子补全**：如果宿主机缺少 [`.env`](.env)，则从 [`.env.example`](.env.example) 幂等初始化，并自动生成 32 位高强度 Gateway Token。
3. **镜像感应**：识别您的硬件架构（x86/ARM），并从远程拉取对应的预构建层（约 2GB）。

```bash
# 1. 克隆源码 (仅需编排层)
git clone https://github.com/hrygo/openclaw-devkit.git && cd openclaw-devkit

# 2. 一键智能适配
make install
```

### 2. 交互式 Onboarding 配置引导
环境就绪后，OpenClaw 处于“待机”状态。您需要注入 LLM 供应商（如 Anthropic, OpenAI）和通讯平台（如飞书, Slack）的凭证。

```bash
make onboard
```
**配置清单 (Pre-Onboarding Check)**：
- **LLM API Key**：您的核心算力来源。
- **App Token**：如果您要将 AI 接入企业聊天机器人。
- **Workspace ID**：如果您需要 AI 感知特定的协作空间。
> [!TIP]
> 配置完成后，`openclaw.json` 会安全存储在 `~/.openclaw` 中，容器启动时会自动热加载。

### 3. 常用运维指令
| 指令 | 目标 | 技术细节 |
| :--- | :--- | :--- |
| `make up` | 启动入口 | 后台运行 `openclaw-gateway` 与 `openclaw-cli` |
| `make down` | 优雅停止 | 移除容器，但保留 Data Volumes 和网络定义 |
| `make logs` | 实时监控 | 追踪网关的任务分发、WebSocket 状态及报错堆栈 |
| `make status` | 探针检查 | 显示各容器的健康状态、运行时间及端口占用 |
| `make restart` | 刷新环境 | 组合执行 `down` + `up`，用于强制刷新配置 |

---

## 🔵 进阶篇：生产力伸缩

### 4. 版本一键切换 (精准规格表)
DevKit 严选四套垂直工具链，以应对不同的开发场景：

| 规格名称 | 镜像大小 (Compressed) | 软件栈版本 (Baseline) | 核心场景 |
| :--- | :--- | :--- | :--- |
| **Standard** | **~2.21 GB** | Node 22, Go 1.26, Python 3.12, Bun | 全栈开发、AI 插件编写、自动化脚本 |
| **Go** | **~2.30 GB** | Standard + Go 1.26, golangci-lint, Go 工具 | Go 后端开发、dlv 调试、静态分析 |
| **Java** | **~2.20 GB** | Standard + JDK 21, Gradle 8.x, Maven | 企业级 Java 开发、大型项目构建与调试 |
| **Office** | **~4.04 GB** | Standard + LibreOffice, Tesseract OCR, PDF 工具 | 文档转换、网页爬虫、OCR 办公自动化 |

**首次安装**（仅需一次）：
```bash
# 首次安装指定版本
make install go        # Go 版
make install java      # Java 版
make install office    # Office 版
```

**后续切换镜像**（无需重复 install）：
```bash
# 修改 .env 中的 OPENCLAW_IMAGE，然后：
make rebuild go        # 拉取/构建并重启
make rebuild java      # 拉取/构建并重启
make rebuild office    # 拉取/构建并重启
```

| 操作 | 命令 | 适用场景 |
| :--- | :--- | :--- |
| **首次安装** | `make install <variant>` | 首次部署环境，创建数据目录和配置 |
| **后续切换** | `make rebuild <variant>` | 已安装后需要切换到不同版本 |

> **提示**：`make install` 仅用于首次安装。后续切换镜像只需修改 `.env` 并使用 `make build/rebuild` 即可，数据目录会被保留。
>
> 可用变体：`go`、`java`、`office`（默认：标准版）

### 5. 深度解析：数据挂载与持久化
为了保证 AI 容器的“非易失性”，我们设计了双轨持久化：

1. **配置主干 (Bind Mount)**：
   - 路径：`~/.openclaw/`
   - 作用：存放 `openclaw.json`。这是 Agent 的身份证，允许您在宿主机直接编辑 JSON。
2. **工作区 (Bidirectional Sync)**：
   - 路径：`~/.openclaw/workspace/`
   - 作用：您的开发案板。容器内外的所有文件变动均秒级同步。
3. **隔离卷 (Named Volume)**：
   - `.openclaw-state`：存放数据库快照、Session 持久化，防止镜像更新导致记忆丢失。

### 6. Roles 与开发流优化
在多人协作或 Git 管理时，为了避免泄露私有 Token，我们推荐 **“软链接隔离法”**：
1. 将 `roles` 目录设为项目的软链接：`ln -s ./my-private-roles ./roles`。
2. 在 [`.gitignore`](.gitignore) 中忽略该链接或实际路径，确保架构公开、凭证隐藏。

### 7. 高级玩法：自定义镜像与扩展编排
当预置的工具链无法满足特定的业务需求时，DevKit 提供了极其灵活的扩展能力。最佳实践**绝对不是**去修改官方源码的 `Dockerfile` 或 `docker-compose.yml`，而是利用其底层设计的无侵入扩展机制。

**最佳实践 A：安全定制业务镜像 (Custom Image)**
如果您需要安装特定的系统包（如 `ffmpeg`）或加入企业内部证书：
1. **继承体系**：创建一个全新的 `Dockerfile.custom`，并以官方镜像作为 Base Image 层。
   ```dockerfile
   FROM ghcr.io/hrygo/openclaw-devkit:dev
   USER root
   RUN apt-get update && apt-get install -y ffmpeg
   USER node
   ```
2. **平滑接入**：构建出自己维护的镜像后，仅需在 `.env` 中声明 `OPENCLAW_IMAGE=my-custom-openclaw:dev` 即可无缝切换底层环境，而不破坏任何官方启动脚本，保证未来能够平稳接收框架更新。

**最佳实践 B：无侵入的编排增强 (Compose Override)**
当您需要为容器网关挂载特定的业务目录，或是需要在内网增加伴生辅助服务（如挂载本地的 Redis Server）：
1. **建立 Override 文件**：在根目录下创建 `docker-compose.override.yml`。Docker Compose 引擎原生支持读取该文件从而对主配置（`docker-compose.yml`）进行合并与覆写增强。这能巧妙避开 Git 的代码冲突。
2. **安全挂载**：在 Override 文件中优雅内聚地注入您所需的 Volume 与额外参数，无需再去改动底层核心 YAML，真正实现配置与代码的隔离。

---

## ⚡ 扩展：第三方通讯平台接入
OpenClaw 支持通过 Socket Mode 接入多种办公平台。

> 💡 **为什么选择 Slack 和飞书？**
> 对于代码辅助这类高级生产力场景，**便捷体验**和**展现力**至关重要。区别于普通聊天工具，Slack 和飞书提供的**高阶富文本能力**（完美渲染 Markdown、代码块语法高亮、按键交互）能让查阅代码和确认 Diff 犹如在 IDE 中般自然。此外，它们原生支持的**长连接机制（Socket Mode / WebSocket）**更是极大降低了使用门槛——哪怕没有公网 IP、身处局域网深处，也彻底免去了配置复杂内网穿透（Webhook）的烦恼，真正实现了安全且极速的“开箱即联”。

- **Slack (推荐)**：请参阅 [Slack 接入保姆级教程](SLACK_SETUP_BEGINNER.md)。
- **飞书 (Lark)**：开发中，敬请期待。

---

## 🔴 架构篇：底层逻辑深度内窥

### 8. 底层逻辑：分层编排架构 (Layered Orchestration)
DevKit 的 `Makefile` 是一套精密的驱动引擎，它会根据环境变量动态重组 Compose 文件：
- **静态层** (`docker-compose.yml`)：定义拓扑。
- **增强层** (`docker-compose.build.yml`)：当 `OPENCLAW_SKIP_BUILD=false` 时，该层注入 Dockerfile 路径及构建所需的代理参数（`HTTP_PROXY`）。
- **动态覆盖**：`docker-setup.sh` 会在运行时动态生成 `docker-compose.dev.extra.yml`，处理用户自定义的额外挂载点（`OPENCLAW_EXTRA_MOUNTS`）。

### 9. 环境初始化生命周期 (Lifecycle Trace)
当您启动容器时，`docker-entrypoint.sh` 会接管初始 5 秒：
1. **UID 自适应**：检测宿主机用户 ID，执行 `chown` 修复挂载目录的写入权限，杜绝 `EACCES` 报错。
2. **种子注入**：若工作区为空，从内部 `/home/node/.openclaw-seed` 自动填充引导文件。
3. **网络对齐**：强制锁定容器网关端口，并将绑定地址设为 `lan` 以穿透 Docker 桥接网卡（`loopback` 模式无法被宿主机访问）。

**可视化架构参考**：极致精密的每一步流转细节请参阅 [ORCHESTRATION.md](ORCHESTRATION.md)。

### 10. 安全白皮书：沙盒机制与网络模型
> [!IMPORTANT]
> **最小特权原则 (Least Privilege)**：
> - 容器禁用了 `NET_RAW` 和 `NET_ADMIN` 能力，防止 AI 代理探测宿主机局域网。
> - 启用了 `no-new-privileges` 标志，切断了提权漏洞路径。
> - **网络绑定**：所有 Web UI 仅监听 `127.0.0.1`，通过 Docker 端口映射暴露，最大程度降低公网暴露面。

---

## ❓ 故障排查 (QA / FAQ)

<details>
<summary><b>Q: 容器内 curl 提示超时或 SSL 握手失败？</b></summary>
1. 检查 <code>.env</code> 中的 <code>HTTPS_PROXY</code> 是否指向 <code>http://host.docker.internal:[您的代理端口]</code>。
2. 确保您的代理软件（如 Clash/Stash）已开启 <b>"Allow LAN"</b> (允许局域网连接)。
</details>

<details>
<summary><b>Q: 为什么找不到我的 agent.json 配置文件？</b></summary>
A: 请检查 <code>OPENCLAW_CONFIG_DIR</code> 的实际挂载路径。默认在 <code>~/.openclaw</code>。您可以在宿主机直接搜索该文件进行验证。
</details>

---

## ⚙️ 全量技术参数矩阵 (Advanced Tuning)

| 变量分类 | 变量名 | 推荐值 | 说明 |
| :--- | :--- | :--- | :--- |
| **编排核心** | `COMPOSE_FILE` | `docker-compose.yml` | 定义编排分层。启用本地构建需加上 `:docker-compose.build.yml` |
| | `OPENCLAW_SKIP_BUILD`| `true` | 开关：`true` (极速模式拉镜像), `false` (开发模式本地构建) |
| | `OPENCLAW_IMAGE` | `...:latest` | 指定运行时的 Docker 镜像 Full Tag |
| **路径审计** | `OPENCLAW_CONFIG_DIR`| `~/.openclaw` | 宿主机配置根目录，包含 `openclaw.json` 与 `identity` |
| | `OPENCLAW_WORKSPACE_DIR`| `.../workspace` | 智能体操作的主战场，建议定期备份 |
| **网络隔离** | `OPENCLAW_GATEWAY_PORT`| `18789` | 外部访问网关监听端口 |
| | `OPENCLAW_GATEWAY_TOKEN`| (生成的 Hex) | 连接 CLI 与网关的唯一数字握手凭证。 |
| | `HTTP[S]_PROXY` | - | 容器外网出口。推荐使用 `http://host.docker.internal:端口` |
| **加速镜像** | `DOCKER_MIRROR` | `docker.io` | Docker Hub 加速，构建时生效 |
| | `APT_MIRROR` | `ustc` | Debian 包加速源，显著提升本地构建速度 |
| | `NPM_MIRROR` | - | 支持 pnpm 构建时的加速，推荐淘宝源 |
| | `PYTHON_MIRROR` | - | 支持 pip 安装依赖时的加速，推荐清华源 |
| **平台扩展** | `OPENCLAW_HOME_VOLUME`| - | (可选) 若设为命名卷名，则整个 `/home/node` 持久化 |
| | `OPENCLAW_EXTRA_MOUNTS`| - | (高级) 格式: `src:dst[:ro]`。支持动态挂载额外资源 |
| **性能调和** | `deploy.resources` | (Limits: 4G RAM) | 已在 YAML 中硬编码限制，防止 AI Agent 内存溢出导致系统崩溃。 |

---

<p align="center">
  <b>OpenClaw Team | 技术规格书</b><br>
  <i>Empowering Human-AI Symbiosis Through Precise Engineering</i>
</p>
