# OpenClaw DevKit 技术规格与操作指南

本文档是 OpenClaw DevKit 的权威技术规格书与操作指南，为初学者提供入门路径，为架构师与资深开发者记录底层逻辑、安全模型与高性能编排机制。

---

## 核心导航

### 基础篇：快速启动
- [1. 极速模式](#1-极速模式) - 3 分钟全自动部署
- [2. 交互式配置](#2-交互式配置) - 获取 AI 连接凭证
- [3. 常用运维指令](#3-常用运维指令) - 从启动到重启的完整命令表

### 进阶篇：生产力调优
- [4. 版本切换](#4-版本切换) - Standard vs. Java vs. Office 规格表
- [5. 数据持久化](#5-数据持久化) - Bind Mount vs. Named Volumes
- [6. Roles 开发流](#6-roles-开发流) - 软链接隔离最佳实践
- [7. 自定义镜像](#7-自定义镜像) - 无侵入扩展机制
- [附：Slack 接入指南](SLACK_SETUP_BEGINNER.md) | [飞书接入指南](FEISHU_SETUP_BEGINNER.md)

### 架构篇：底层逻辑
- [8. 分层编排](#8-分层编排) - docker-compose 动态注入机制
- [9. 初始化生命周期](#9-初始化生命周期) - 权限修复与种子填充流程
- [10. 安全机制](#10-安全机制) - 沙盒与网络隔离

---

## 1. 极速模式

极速模式通过 GitHub Packages (GHCR) 预构建镜像实现快速部署。

**安装逻辑**：
执行 `make install` 时，系统自动执行以下操作：
1. **环境检查**：确认 Docker 及 Compose 插件可用
2. **配置初始化**：若宿主机缺少 `.env`，则从 `.env.example` 初始化，并生成 32 位 Gateway Token
3. **架构适配**：识别硬件架构（x86/ARM），拉取对应预构建层

```bash
# 克隆源码
git clone https://github.com/hrygo/openclaw-devkit.git && cd openclaw-devkit

# 一键安装
make install
```

---

## 2. 交互式配置

环境就绪后，OpenClaw 处于待机状态。需注入 LLM 供应商和通讯平台凭证。

```bash
make onboard
```

**配置清单**：
- **LLM API Key**：核心算力来源
- **App Token**：企业聊天机器人集成所需
- **Workspace ID**：AI 感知特定协作空间所需

> 配置完成后，`openclaw.json` 存储在 `~/.openclaw`，容器启动时自动热加载。

---

## 3. 常用运维指令

| 指令 | 说明 |
| :--- | :--- |
| `make start` / `make up` | 启动 openclaw-gateway 与 openclaw-cli |
| `make stop` / `make down` | 移除容器，保留 Data Volumes |
| `make logs` | 追踪任务分发、WebSocket 状态、错误堆栈 |
| `make logs-all` | 查看所有容器日志 |
| `make status` | 显示容器健康状态、运行时间、端口占用 |
| `make restart` | 执行 down + up，刷新配置 |
| `make shell` | 进入 Gateway 容器 |
| `make run` | 交互式进入容器 |
| `make exec CMD="..."` | 在容器中执行命令 |
| `make cli CMD="..."` | 执行 OpenClaw CLI 命令 |
| `make dashboard` | 一键直达仪表盘 |
| `make health` | 检查健康状态 |
| `make backup` | 备份配置文件 |
| `make restore FILE=...` | 恢复配置文件 |
| `make clean` | 清理容器和悬空镜像 |
| `make clean-volumes` | 清理所有数据卷 |

---

## 4. 版本切换

DevKit 提供四套垂直工具链：

| 版本 | 镜像大小 | 核心场景 |
| :--- | :--- | :--- |
| **Standard** | ~2.21 GB | 全栈开发、AI 插件、自动化脚本 |
| **Go** | ~2.30 GB | Go 后端、dlv 调试、静态分析 |
| **Java** | ~2.20 GB | 企业级 Java、Gradle/Maven 构建 |
| **Office** | ~4.04 GB | 文档转换、OCR、办公自动化 |

```bash
# 首次安装
make install go
make install java
make install office

# 后续切换
make rebuild go
make rebuild java
make rebuild office
```

| 操作 | 命令 | 场景 |
| :--- | :--- | :--- |
| 首次安装 | `make install <variant>` | 创建数据目录和配置 |
| 后续切换 | `make rebuild <variant>` | 已安装后切换版本 |

---

## 5. 数据持久化

双轨持久化设计保证容器非易失性：

1. **配置挂载 (Bind Mount)**
   - 路径：`~/.openclaw/`
   - 用途：存放 `openclaw.json`，允许宿主机直接编辑

2. **工作区 (双向同步)**
   - 路径：`~/.openclaw/workspace/`
   - 用途：开发案板，容器内外文件秒级同步

3. **状态卷 (Named Volume)**
   - `.openclaw-state`
   - 用途：数据库快照、Session 持久化，防止镜像更新导致记忆丢失

---

## 6. Roles 开发流

多人协作或 Git 管理时，采用软链接隔离法保护私有 Token：

```bash
# 创建软链接
ln -s ./my-private-roles ./roles

# 在 .gitignore 中忽略
```

---

## 7. 自定义镜像

### 方式 A：继承官方镜像

创建 `Dockerfile.custom`，基于官方镜像扩展：

```dockerfile
FROM ghcr.io/hrygo/openclaw-devkit:latest
USER root
RUN apt-get update && apt-get install -y ffmpeg
USER node
```

在 `.env` 中声明 `OPENCLAW_IMAGE=my-custom-openclaw:dev` 即可切换。

### 方式 B：Compose Override

创建 `docker-compose.override.yml`，追加 Volume 和参数，无需修改核心配置。

---

## 8. 分层编排

Makefile 根据环境变量动态重组 Compose 文件：

- **静态层** (`docker-compose.yml`)：定义拓扑
- **增强层** (`docker-compose.build.yml`)：`OPENCLAW_SKIP_BUILD=false` 时注入构建参数
- **动态覆盖**：`docker-setup.sh` 运行时生成 `docker-compose.dev.extra.yml`，处理自定义挂载点

---

## 9. 初始化生命周期

容器启动时，`docker-entrypoint.sh` 执行以下操作：

1. **UID 适配**：检测宿主机用户 ID，执行 `chown` 修复挂载目录权限
2. **种子填充**：工作区为空时，从 `/home/node/.openclaw-seed` 自动填充
3. **网络绑定**：锁定网关端口，绑定地址设为 `lan` 以穿透 Docker 桥接网卡

---

## 10. 安全机制

**最小特权原则**：
- 容器禁用 `NET_RAW` 和 `NET_ADMIN` 能力，防止 AI 探测宿主机局域网
- 启用 `no-new-privileges` 标志，切断提权路径
- Web UI 仅监听 `127.0.0.1`，通过 Docker 端口映射暴露

---

## 故障排查

### Q: 容器内 curl 超时或 SSL 握手失败？
1. 检查 `.env` 中 `HTTPS_PROXY` 是否指向 `http://host.docker.internal:[端口]`
2. 确认代理软件已开启 "Allow LAN"

### Q: 找不到 agent.json 配置文件？
检查 `OPENCLAW_CONFIG_DIR` 实际挂载路径，默认在 `~/.openclaw`

---

## 技术参数

| 分类 | 变量 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| **编排** | `COMPOSE_FILE` | `docker-compose.yml` | 定义编排分层 |
| | `OPENCLAW_SKIP_BUILD`| `true` | true=拉镜像, false=本地构建 |
| | `OPENCLAW_IMAGE` | `...:latest` | Docker 镜像标签 |
| **路径** | `OPENCLAW_CONFIG_DIR`| `~/.openclaw` | 配置目录 |
| | `OPENCLAW_WORKSPACE_DIR`| `.../workspace` | 工作区 |
| **网络** | `OPENCLAW_GATEWAY_PORT`| `18789` | 网关端口 |
| | `OPENCLAW_GATEWAY_TOKEN`| (Hex) | CLI-Gateway 握手凭证 |
| | `HTTP[S]_PROXY` | - | 容器外网出口 |
| **镜像加速** | `DOCKER_MIRROR` | `docker.io` | Docker Hub 加速 |
| | `APT_MIRROR` | `ustc` | Debian 包加速 |
| | `NPM_MIRROR` | - | pnpm 加速 |
| | `PYTHON_MIRROR` | - | pip 加速 |
| **扩展** | `OPENCLAW_HOME_VOLUME`| - | 命名卷持久化 `/home/node` |
| | `OPENCLAW_EXTRA_MOUNTS`| - | 额外挂载 `src:dst[:ro]` |
| **资源** | `deploy.resources` | 4G RAM | 内存上限 |

---

<p align="center">
  <b>OpenClaw Team | 技术规格书</b><br>
  <i>Empowering Human-AI Symbiosis Through Precise Engineering</i>
</p>
