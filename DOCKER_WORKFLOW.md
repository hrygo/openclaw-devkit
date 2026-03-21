# Docker 构建架构与流程

采用分层运行时架构，分离静态 SDK 环境与动态应用。

---

## 1. 分层架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Layer III: Product Layer - 构建频率: 高                                        │
│ ghcr.io/hrygo/openclaw-devkit:latest | :go | :java | :office              │
│ 包含: OpenClaw 官方 Release (openclaw.ai)                                   │
│ Dockerfile: Dockerfile                                                      │
└───────────────────┬─────────────────────────────────┬─────────────────────┘
                    │ FROM                             │ FROM
┌───────────────────┴─────────────────────────────────┴─────────────────────┐
│ Layer II: Stack Runtimes - 构建频率: 低                                      │
│ ghcr.io/hrygo/openclaw-runtime:go | :java | :office                       │
│ 包含: Go 1.26, JDK 21, LibreOffice, Python IDP                             │
│ Dockerfile: Dockerfile.stacks                                                │
└───────────────────────────────────┬───────────────────────────────────────┘
                                    │ FROM
┌───────────────────────────────────┴───────────────────────────────────────┐
│ Layer I: Base Foundation - 构建频率: 极低                                   │
│ ghcr.io/hrygo/openclaw-runtime:base                                        │
│ 包含: Debian Bookworm, Node.js 22, Bun, uv, Playwright                     │
│ Dockerfile: Dockerfile.base                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Dockerfile 职责对比

| 特性 | Dockerfile.base | Dockerfile.stacks | Dockerfile |
| :--- | :--- | :--- | :--- |
| **层级** | Layer I (基础) | Layer II (技术栈) | Layer III (应用) |
| **Base 镜像** | `debian:bookworm-slim` | `${BASE_IMAGE}` | `${BASE_IMAGE}` |
| **构建目标** | 单一镜像 | 多阶段构建 | 单一镜像 |
| **构建命令** | `make build-base` | `make build-stacks` | `make build` |
| **包含内容** | | | |
| 系统工具 | yq, just, gh, lazygit | - | - |
| 运行时 | Node.js, Bun, uv | Go, JDK, Gradle, Maven | - |
| 浏览器依赖 | Playwright 依赖 | - | Playwright 浏览器 |
| Python 包 | - | pandoc, libreoffice 等 | notebooklm-py |
| AI 工具 | - | gopls, staticcheck 等 | OpenClaw, Claude Code |
| **持久化配置** | ❌ | ❌ | ✅ 全局工具目录 |
| **镜像标签** | `openclaw-runtime:base` | `openclaw-runtime:{go,java,office}` | `openclaw-devkit:{latest,go,java,office}` |

### 1.2 构建顺序

```bash
# 1. 构建基础镜像 (Layer I) - 首次或更新系统依赖时
make build-base
# → 产出: openclaw-runtime:base

# 2. 构建技术栈镜像 (Layer II) - 首次或更新 Go/Java/Office 时
make build-stacks
# → 产出: openclaw-runtime:go, openclaw-runtime:java, openclaw-runtime:office

# 3. 构建应用镜像 (Layer III) - 每次更新 OpenClaw 时
make build        # 标准版 (基于 base)
make build-go     # Go 版 (基于 go)
make build-java   # Java 版 (基于 java)
make build-office # Office 版 (基于 office)
# → 产出: openclaw-devkit:latest, :go, :java, :office
```

---

## 2. 本地构建

```bash
# 构建标准版
make build

# 构建指定版本
make build-go
make build-java
make build-office
```

**执行流程**:
```
make build-go
       │
       ▼
检查是否存在 openclaw-runtime:go
       │
       ▼
docker build -f Dockerfile
  --build-arg BASE_IMAGE=openclaw-runtime:go
  -t ghcr.io/hrygo/openclaw-devkit:go .
       │
       ▼
FROM openclaw-runtime:go (已包含 Go SDK)
RUN npm install -g openclaw
```

---

## 3. CI/CD 构建

由 `.github/workflows/docker-publish.yml` 驱动：

```
[prepare] ─────────────────────────────┐
      │                                │
      ▼                                ▼
[build-base]                          │ 感知版本
      │                                │
      ▼                                │
[build-stacks] ───────────────┐        │
      │                       │        │
      ▼                       ▼        ▼
[build-products] <───────────┴────────┘
      │
      ▼
推送至 GHCR:
  ghcr.io/hrygo/openclaw-runtime:base
  ghcr.io/hrygo/openclaw-runtime:{go,java,office}
  ghcr.io/hrygo/openclaw-devkit:{latest,go,java,office}
  ghcr.io/hrygo/openclaw-devkit:v1.6.2
```

---

## 4. 构建参数

| 参数               | 默认值           | 说明            |
| :----------------- | :--------------- | :-------------- |
| `HTTP_PROXY`       | -                | 网络代理        |
| `APT_MIRROR`       | `deb.debian.org` | Debian 镜像     |
| `OPENCLAW_VERSION` | `latest`         | OpenClaw 版本   |
| `INSTALL_BROWSER`  | `0`              | 安装 Playwright |

---

## 5. 运维变量

| 变量                     | 默认值                          | 说明         |
| :----------------------- | :------------------------------ | :----------- |
| `HOST_OPENCLAW_DIR`       | `~/.openclaw`                   | 宿主机配置目录 (直接 bind mount) |
| `OPENCLAW_GATEWAY_PORT`  | `18789`                         | Gateway 端口         |
| `OPENCLAW_GATEWAY_BIND`  | `lan`                           | Gateway 监听模式 (lan=所有网卡，local=仅 127.0.0.1) |

---

## 6. 镜像更新机制

镜像更新采用以下优先级逻辑：

### 6.1 优先级

1. **本地优先 (`make install`)**：
   - 系统首先检查本地是否存在对应标签的镜像。
   - 存在时直接启动，不主动联机检查版本差异。
2. **强制拉取 (`make upgrade`)**：
   - 调用 `docker pull`，检查本地与远程 Registry 的 Image Digest。
   - 远程存在更新时自动下载并替换，随后重启容器。

### 6.2 常用命令

| 场景                | 命令                  | 行为                               |
| :------------------ | :-------------------- | :--------------------------------- |
| **首次安装**        | `make install`        | 拉取镜像并初始化环境               |
| **日常启动**        | `make up`             | 快速启动，无网络开销               |
| **跟进新特性/修复** | `make upgrade`        | 检测更新、拉取并重启               |
| **手动维护**        | `docker pull <image>` | 仅手动更新镜像，不影响运行中的容器 |

---

## 7. 故障处理

### 处理路径兼容性与权限
传统 Docker 挂载容易因宿主机与容器路径不一致导致 `EACCES` 或路径报错。OpenClaw DevKit 已实现**全自动自愈机制**：
- **环境路径手术 (Path Surgery)**：启动时自动将配置/日志中的宿主机路径（如 `/Users/xxx`）迁移为容器标准路径。
- **增量式修复**：通过标记文件确保沉重的全量扫描仅在首次运行，日常启动无需等待。
- **防止泄露**：通过 `OPENCLAW_HOME` 等变量强制锁定路径生成，确保无障碍执行。

### 目录映射与挂载逻辑 (Mount Hierarchy)

DevKit 采用**分层命名卷 + Bind Mount 共享**架构：

| 宿主机路径 (Host Path) | 容器路径 (Container Path) | 类型 | 用途 (Purpose) |
| :--- | :--- | :--- | :--- |
| `openclaw-devkit-home` | `/home/node/` | 命名卷 | **工具链持久化**。npm/pnpm/bun 全局包、Go 生态、Playwright 缓存。 |
| `openclaw-claude-home` | `/home/node/.claude/` | 命名卷 | **Claude Code 持久化**。Session、Memory、Skills 状态，重建不丢失。 |
| `~/.openclaw/` | `/home/node/.openclaw/` | Bind Mount (rw) | **用户配置共享**。openclaw.json、identity、agents，宿主机与容器实时双向同步。 |
| `~/.notebooklm/` | `/home/node/.notebooklm/` | Bind Mount (rw) | NotebookLM CLI 状态 |
| `~/.claude/settings.json` | `/home/node/.claude/settings.json` | Bind Mount (ro) | Claude Code 配置只读共享 |
| `~/.claude/skills/` | `/home/node/.claude/skills/` | Bind Mount (ro) | Claude Code Skills 只读共享 |
| `~/.agents/skills/` | `/home/node/.agents/skills/` | Bind Mount (ro) | .agents Skills 只读共享 |

#### 如何修改配置文件？
- 直接编辑宿主机的 **`~/.openclaw/openclaw.json`**，容器内实时热加载，无需重启。
- 配置变更通过 bind mount 自动同步，无需手动拷贝。

### 权限迁移
容器入口脚本会自动修复宿主机挂载目录的 UID/GID 权限。

### 清理
```bash
make clean            # 容器和悬空镜像
make clean-volumes   # 所有数据卷（慎用，会丢失 npm/Go/Claude Code 缓存）
```

---

## 8. Cockpit 运维引擎

Cockpit 运维引擎提供以下操作：

### 8.1 一键直达 (Dashboard)
- **命令**：`make dashboard`
- **逻辑**：自动获取容器内 Gateway Token 并生成带身份的 URL。
- **效果**：绕过 `pairing required` 拦截，一键直达仪表盘。

### 8.2 自动化配对 (Approve)
- **命令**：`make approve`
- **逻辑**：自动识别 Web UI 发出的最新 `pending` 请求 ID 并批准。
- **场景**：网页处于"待配对"状态时，运行此命令可立即放行。

---

## 9. Windows / WSL 适配

Windows / WSL 环境的 Docker 健康检查配置：
- **宽限期 (`start_period`)**：60s
- **重试 (`retries`)**：10 次
- **自愈**：容器入口脚本启动时自动执行 `doctor --fix`

---

## 10. 架构优势

- **DRY**: 构建逻辑收拢在 Makefile
- **缓存**: 更新版本时 Layer I/II 来自本地缓存
- **独立**: 各层可独立测试和发布

---

## 11. 全局工具持久化

OpenClaw 容器支持在运行时安装任何工具（npm/pnpm/bun/uv），重启后自动保留。

### 11.1 持久化原理

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Named Volume: openclaw-devkit-home                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ /home/node/.global/  (npm/pnpm/bun 工具)                              ││
│  │ /home/node/.local/    (Python CLI 工具, uv pip install --user)          ││
│  │ /home/node/.cache/   (Playwright 浏览器缓存等)                          ││
│  │ /home/node/go/       (Go SDK 和工具链)                                  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│  Named Volume: openclaw-claude-home                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ /home/node/.claude/ (Session, Memory, Skills 状态)                    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.2 支持的包管理器

| 包管理器 | 安装命令示例 | 持久化位置 |
| :------ | :---------- | :-------- |
| **npm** | `npm install -g some-tool` | `/home/node/.global` |
| **pnpm** | `pnpm add -g some-tool` | `/home/node/.global` |
| **bun** | `bun install -g some-tool` | `/home/node/.global` |
| **uv (Python)** | `uv pip install --user some-tool` | `/home/node/.local` |

### 11.3 工作机制

- **镜像构建时 (Dockerfile)**：预配置所有包管理器使用统一全局目录
- **容器启动时 (docker-compose.yml)**：挂载命名卷确保数据持久化
- **运行时 (docker-entrypoint.sh)**：自动修复权限，确保 PATH 正确

### 11.4 使用方式

无需任何额外配置，OpenClaw 安装的工具会自动持久化：

```bash
# 重建镜像后启动
make down
make build
make up

# 在容器内安装工具 - 重启后依然存在
make shell
npm install -g my-tool
pnpm add -g another-tool
uv pip install --user python-tool

# 退出容器，重启验证
exit
make down && make up
make shell
which my-tool  # 工具仍在!
```

### 11.5 注意事项

- **首次重建**：需要在镜像构建时执行配置，首次 `make build` 后自动生效
- **工具迁移**：之前在旧位置安装的工具不会自动迁移，需手动重新安装
- **清理数据**：如需清除所有持久化工具，执行:
  ```bash
  docker volume rm openclaw-devkit-home openclaw-claude-home
  ```
