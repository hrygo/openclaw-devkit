# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

openclaw-devkit 开发工具箱套件 - 为 [OpenClaw](https://github.com/openclaw/openclaw) 多通道 AI 生产力工具提供完整的容器化开发环境。集成开发、调试、测试于一体的工具链，助力快速迭代和部署。

## Architecture

```
openclaw-devkit/
├── Makefile                # Docker 运维命令入口
├── docker-compose.yml      # Docker Compose 配置 (支持 dev/go/java/office)
├── Dockerfile             # 开发环境镜像定义 (标准版)
├── Dockerfile.base        # 基础镜像 (Debian + Node.js)
├── Dockerfile.stacks      # 技术栈镜像 (Go/Java/Office 变体)
└── docker-setup.sh       # 交互式初始化脚本
```

## Common Commands (Makefile)

```bash
# 快速开始
make install          # 首次安装/初始化环境
make onboard          # 交互式配置 (LLM/API)

# 生命周期管理
make up               # 启动服务
make start            # 启动服务 (make up 的别名)
make down             # 停止服务
make stop             # 停止服务 (make down 的别名)
make restart          # 重启服务
make status           # 查看服务状态

# 构建与更新
make build            # 构建标准版镜像
make build-go         # 构建 Go 版镜像
make build-java       # 构建 Java 版镜像
make build-office     # 构建 Office 版镜像
make rebuild          # 重建镜像并重启服务
make rebuild-go       # 重建 Go 版并重启
make rebuild-java     # 重建 Java 版并重启
make rebuild-office   # 重建 Office 版并重启
make update           # 从 GitHub 同步最新代码

# 调试诊断
make logs             # 查看 Gateway 日志
make logs-all         # 查看所有容器日志
make shell            # 进入 Gateway 容器 (bash)
make run              # 交互式进入容器
make exec CMD="..."   # 在容器中执行命令
make cli CMD="..."    # 执行 OpenClaw CLI 命令
make dashboard        # 一键直达仪表盘
make devices          # 列举配对设备
make approve          # 批准配对请求
make pairing          # 频道配对
make pair             # 频道配对 (别名)
make verify           # 验证镜像工具版本

# 健康与测试
make health           # 检查健康状态
make test-proxy       # 测试代理连接

# 备份恢复
make backup           # 备份配置文件
make backup-config    # 备份配置 (同上)
make restore FILE=<file>  # 恢复配置

# 清理
make clean            # 清理容器和悬空镜像
make clean-volumes    # 清理所有数据卷 (危险!)
```

## Key Services

| Service          | Port  | Description                     |
| ---------------- | ----- | ------------------------------- |
| openclaw-gateway | 18789 | 主网关服务 (Web UI + WebSocket) |
|                  | 18790 | Bridge WebSocket 桥接           |
|                  | 18791 | Browser 浏览器调试端口          |

> **代理配置**: 通过 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量配置外部代理，用于访问 Google 和 Claude API

## Docker Image Variants

| Variant | Image                      | Use Case                    |
|---------|----------------------------|-----------------------------|
| latest  | ghcr.io/hrygo/openclaw-devkit:latest | 标准开发版 (Node.js + Python) |
| go      | ghcr.io/hrygo/openclaw-devkit:go    | Go 开发版 (包含 Go 1.26 + 工具) |
| java    | ghcr.io/hrygo/openclaw-devkit:java  | Java 支持 (包含 JDK 21)       |
| office  | ghcr.io/hrygo/openclaw-devkit:office | 办公环境集成 (PDF/OCR)    |

选择版本: `make install <variant>` 或 `make rebuild <variant>`

## Configuration

- 环境变量: `.env` 文件 (git-ignored)
- 代理配置: 通过 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量配置，用于访问 Google 和 Claude API
- 配置目录: 容器内 `~/.openclaw/`

## Setup Script

`docker-setup.sh` 是交互式初始化脚本，用于:
- 检测宿主机环境 (Docker/Podman)
- 配置代理和网络设置
- 生成必要的配置文件 (.env)
- 选择并拉取 Docker 镜像版本

首次使用建议运行 `make install` 或直接运行 `./docker-setup.sh`

## Development Workflow

1. 首次设置: `make install`
2. 交互式配置: `make onboard`
3. 启动服务: `make up`
4. 访问仪表盘: `make dashboard`
5. 查看日志: `make logs`

## Environment Variables

```bash
# 代理配置 (如需要)
HTTP_PROXY=http://host.docker.internal:7897
HTTPS_PROXY=http://host.docker.internal:7897

# GitHub Token (用于 gh CLI)
GITHUB_TOKEN=xxx
```

## Tips

- 容器内已安装 `gh` CLI，可用于 GitHub 操作
- 使用 `make exec CMD="openclaw config list"` 查看 OpenClaw 配置
- Gateway 日志位于容器内 `/tmp/openclaw-gateway.log`
- 进入容器后可直接运行 `openclaw` 命令

### CI 调试命令

```bash
# 查看最近的 CI 运行
gh run list --repo hrygo/openclaw-devkit --limit 5

# 查看特定运行的详细信息
gh run view <run-id> --repo hrygo/openclaw-devkit

# 获取完整 CI 日志
gh run view <run-id> --repo hrygo/openclaw-devkit --log

# 搜索日志中的错误
gh run view <run-id> --repo hrygo/openclaw-devkit --log 2>&1 | grep -E "(ERROR|failed|process \")"
```

## Gotchas

### Shell 条件执行陷阱 (Dockerfile)

**问题**: 在 Dockerfile RUN 命令中使用 `&&` 链时，条件测试 `[ condition ] && cmd` 如果返回 false 会中断整个链条。

**错误示例**:
```dockerfile
RUN ARCH=$(dpkg --print-architecture) && \
    JUST_ARCH="${ARCH}" && \
    [ "$ARCH" = "amd64" ] && JUST_ARCH="x86_64" && \  # 如果 ARCH=arm64，这里不会执行
    [ "$ARCH" = "arm64" ] && JUST_ARCH="aarch64" && \  # 如果 ARCH=amd64，这里断链!
    curl ... # 不会执行
```

**正确做法**: 使用 `if-then-elif-else-fi` 语法：
```dockerfile
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then JUST_ARCH="x86_64"; \
    elif [ "$ARCH" = "arm64" ]; then JUST_ARCH="aarch64"; \
    else JUST_ARCH="${ARCH}"; fi && \
    curl ...
```

### Shell 脚本换行符问题

**症状**: 执行 `make up` 时报错 `env: 'bash\r': No such file or directory`

**原因**: Windows 和 Linux 换行符不兼容 (CRLF vs LF)

**排查**:
```bash
# 检查文件是否有 CRLF
hexdump -C docker-entrypoint.sh | grep "0d 0a"
file docker-entrypoint.sh  # Windows 文件会显示 "CRLF"

# 查看容器日志
docker compose logs openclaw-gateway
```

**解决**:
```bash
# 转换换行符 (推荐)
sed -i 's/\r$//' docker-entrypoint.sh
sed -i 's/\r$//' docker-setup.sh

# 重启服务
make down
make up
```

**预防**:
```bash
# Git 全局配置
git config --global core.autocrlf input

# 克隆后检查
git diff --check
```

## Dockerfile Development

### 工具架构映射表

不同工具使用不同的架构命名约定，需要正确映射：

| 工具 | amd64 命名 | arm64 命名 | 示例 URL |
|------|-----------|-----------|----------|
| yq | `amd64` | `arm64` | `yq_linux_amd64` |
| just | `x86_64` | `aarch64` | `just-1.47.0-x86_64-unknown-linux-musl.tar.gz` |
| lazygit | `x86_64` | `arm64` | `lazygit_0.49.0_Linux_x86_64.tar.gz` |
| gh CLI | `amd64` | `arm64` | `gh_2.67.0_linux_amd64.deb` |
| Go | `amd64` | `arm64` | `go1.26.1.linux-arm64.tar.gz` |

**推荐**: 在 RUN 命令中使用 `if-then-else-fi` 处理架构差异。

### Version Verification
Before using specific versions in Dockerfile, verify download URLs exist:
```bash
# Check if URL returns 200
curl -fsSL -o /dev/null -w "%{http_code}" "https://nodejs.org/dist/v22.22.1/node-v22.22.1-linux-arm64.tar.xz"
```

### Syntax Validation
```bash
docker build --check -f Dockerfile .  # Validate without full build
```

### Current Stable Versions
- Node.js: 22.x LTS (24.x not yet released)
- Go: 1.26.x (1.27.x not yet released)
- golangci-lint: 1.64.x
- Java: 21 LTS (via Eclipse Temurin)

### 版本锁定原则

**必须锁定版本**: 所有工具版本必须锁定，避免因上游更新导致构建失败。

```bash
# ❌ 错误: 动态查询最新版本 (消耗 GitHub API 配额，易触发 rate limit)
LATEST=$(curl -s https://api.github.com/repos/foo/bar/releases/latest | jq -r '.tag_name')

# ✅ 正确: 锁定具体版本
ARG TOOL_VERSION=1.2.3
curl -fsSL "https://github.com/foo/bar/releases/download/v${TOOL_VERSION}/..."
```

**好处**: 可重复构建 + 避免 API rate limit + 便于追踪回滚

### Installation Methods
- **Node.js**: Use NodeSource APT repository (not direct nodejs.org download)
  - More reliable for multi-architecture builds (amd64 + arm64)
- **Java**: Use Eclipse Temurin APT repository (not SDKMAN)
  - SDKMAN has reliability issues in Docker builds
  - `apt-get install temurin-21-jdk`
- **Gradle/Maven**: Download binaries directly, not via SDKMAN

### Download Source Alternatives
- Spring Boot CLI: Use `repo1.maven.org` (repo.spring.io requires auth)
  - `https://repo1.maven.org/maven2/org/springframework/boot/spring-boot-cli/${VER}/spring-boot-cli-${VER}-bin.tar.gz`

### Common Issues to Avoid
- Duplicate ARG/ENV declarations (causes warnings)
- Duplicate ENV variable settings (GOPATH set twice)
- Using non-existent version numbers
- **ARG scope in multi-stage builds**: ARG must be redeclared in each stage that uses it
- **Package naming**: Use standard Debian Bookworm packages (no `t64` suffix - that's for Trixie/testing)
- **Architecture in URLs**: Always use dynamic `$(dpkg --print-architecture)` for downloads, never hardcode `x64`
