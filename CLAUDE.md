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
├── Dockerfile.java        # Java 版本镜像
├── Dockerfile.go          # Go 版本镜像
├── Dockerfile.office     # Office 版本镜像
├── docker-setup.sh       # 交互式初始化脚本
├── update-source.sh      # 从 GitHub Release 更新源码
└── .openclaw_src/       # OpenClaw 源码目录 (git submodule)
    ├── src/              # 核心源码
    ├── extensions/       # 扩展插件 (Discord, Slack, Zalo, Feishu 等)
    ├── apps/             # 移动端应用 (iOS, Android, macOS)
    └── docs/             # 文档
```

## Common Commands (Makefile)

```bash
# 生命周期管理
make install          # 首次安装/初始化环境
make up               # 启动服务 (Web UI: http://127.0.0.1:18789)
make down             # 停止服务
make restart          # 重启服务
make status           # 查看服务状态

# 构建与更新
make build            # 构建镜像 (无缓存)
make rebuild          # 重建镜像并重启服务
make update           # 从 GitHub Release 更新源码

# 调试诊断
make logs             # 查看 Gateway 日志
make logs-all         # 查看所有容器日志
make shell            # 进入 Gateway 容器 (bash)
make exec CMD="..."   # 在容器中执行命令
make gateway-health   # 检查 Gateway 健康状态
make test-proxy       # 测试代理连接 (Google, Claude API)

# 备份恢复
make backup-config    # 备份配置文件
make restore-config FILE=<file>  # 恢复配置

# 清理
make clean            # 清理容器和悬空镜像
make clean-volumes    # 清理所有数据卷 (危险!)
```

## Key Services

| Service          | Port  | Description                     |
| ---------------- | ----- | ------------------------------- |
| openclaw-gateway | 18789 | 主网关服务 (Web UI + WebSocket) |
| HTTP Proxy       | 7897  | 代理服务 (访问外网)             |
| Claude API Proxy | 15721 | Claude API 代理                 |

## Docker Image Variants

| Variant | Dockerfile    | Use Case                    |
|---------|---------------|------------------------------|
| dev     | Dockerfile    | 标准开发版 (Node.js + Go)   |
| go      | Dockerfile.go | Go 开发版 (包含 golangci-lint + Go 工具) |
| java    | Dockerfile.java | Java 支持 (包含 JDK)       |
| office  | Dockerfile.office | 办公环境集成 (PDF/OCR)    |

选择版本: `make install <variant>` 或 `make build <variant>`

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

## Source Code Notes

- 源码位于 `.openclaw_src/` 目录，是 OpenClaw 官方仓库的 git submodule
- 更新源码: `./update-source.sh` 或 `make update`
- 容器内源码路径: `/app/openclaw/` (mount 到此处)
- **修改源码后需运行 `make rebuild` 使更改生效**

## Development Workflow

1. 首次设置: `make install`
2. 启动服务: `make up`
3. 访问 Web UI: http://127.0.0.1:18789
4. 修改源码后: `make rebuild`
5. 查看日志: `make logs`

## OpenClaw Source Code Conventions

详见 `.openclaw_src/CLAUDE.md` (软链接到 `.openclaw_src/AGents.md`)。关键要点:

- 包管理器: pnpm (Node 22+, pnpm 10.23.0)
- 构建/测试: `pnpm build`, `pnpm test`, `pnpm check`
- TypeScript strict mode, 禁止 `any`, `@ts-nocheck`
- 代码格式化: Oxlint + Oxfmt (`pnpm check`)
- 测试框架: Vitest (`pnpm test`)

## Environment Variables

```bash
# 代理配置 (如需要)
HTTP_PROXY=http://host.docker.internal:7897
HTTPS_PROXY=http://host.docker.internal:7897

# GitHub Token (用于 update-source.sh)
GITHUB_TOKEN=xxx
```

## Tips

- 容器内已安装 `gh` CLI，可用于 GitHub 操作
- 使用 `make exec CMD="openclaw config list"` 查看 OpenClaw 配置
- Gateway 日志位于容器内 `/tmp/openclaw-gateway.log`
- 进入容器后可直接运行 `openclaw` 命令

## Gotchas

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
sed -i 's/\r$//' update-source.sh

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

### Version Verification
Before using specific versions in Dockerfile, verify download URLs exist:
```bash
# Check if URL returns 200
curl -fsSL -o /dev/null -w "%{http_code}" "https://nodejs.org/dist/v22.22.1/node-v22.22.1-linux-arm64.tar.xz"
```

### Syntax Validation
```bash
docker build --check -f Dockerfile.dev .  # Validate without full build
```

### Current Stable Versions
- Node.js: 22.x LTS (24.x not yet released)
- Go: 1.26.x (1.27.x not yet released)
- golangci-lint: 1.64.x
- Java: 21 LTS (via Eclipse Temurin)

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
