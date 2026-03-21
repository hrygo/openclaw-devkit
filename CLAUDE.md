# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

openclaw-devkit 开发工具箱套件 - 为 [OpenClaw](https://github.com/openclaw/openclaw) 多通道 AI 生产力工具提供完整的容器化开发环境。集成开发、调试、测试于一体的工具链，助力快速迭代和部署。

## Project Structure

```
openclaw-devkit/
├── Makefile                # 主要命令入口 (build/up/down/logs 等)
├── docker-compose.yml      # 服务编排配置
├── docker-compose.build.yml # 本地构建覆盖配置 (可选)
├── Dockerfile              # 应用层镜像 (最终用户)
├── Dockerfile.base         # 基础镜像 (Debian + Node.js)
├── Dockerfile.stacks       # 技术栈镜像 (Go/Java/Office)
├── docker-entrypoint.sh    # 容器启动脚本 (配置修复/权限处理)
├── docker-setup.sh         # 宿主机初始化脚本 (交互式)
└── .env.example            # 环境变量模板
```

## Architecture

分层镜像架构：

1. **Dockerfile.base** → `openclaw-runtime:base` - 统一基础层（Debian + Node.js + 基础工具）
2. **Dockerfile.stacks** → `openclaw-runtime:{go,java,office}` - 技术栈层（Go/JDK/Office）
3. **Dockerfile** → `ghcr.io/hrygo/openclaw-devkit:{variant}` - 应用层（CLI 工具 + 配置）

构建顺序：`make build-base` → `make build-stacks` → `make build-{variant}`

## Common Commands (Makefile)

```bash
# 快速开始
make install          # 首次安装/初始化环境
make onboard          # 交互式配置 (LLM/API)

# 生命周期管理
make up               # 启动服务
make down             # 停止服务
make restart          # 重启服务
make status           # 查看服务状态

# 构建与更新
make build-base        # 构建统一基础镜像
make build-stacks      # 构建技术栈基座 (Go, Java, Office)
make build             # 构建标准版镜像
make build-go          # 构建 Go 版镜像
make build-java        # 构建 Java 版镜像
make build-office      # 构建 Office 版镜像
make upgrade           # 升级镜像并重启服务
make update            # 从 GitHub 同步最新代码

# 调试诊断
make logs             # 查看 Gateway 日志
make logs-all         # 查看所有容器日志
make shell            # 进入 Gateway 容器 (bash)
make exec CMD="..."   # 在容器中执行命令
make cli CMD="..."    # 执行 OpenClaw CLI 命令
make tui               # 🖥️ 启动 TUI 终端界面
make dashboard         # 🚀 一键直达仪表盘
make approve           # 🔐 一键批准最新的配对请求
make devices           # 列举所有配对设备及请求
make verify            # 验证镜像工具版本

# 健康与测试
make health           # 检查健康状态
make test-proxy       # 测试代理连接

# 备份恢复
make backup           # 备份配置文件
make restore FILE=<file>  # 恢复配置

# 清理
make clean            # 清理容器和悬空镜像
make clean-volumes    # 清理数据卷（⚠️ 会丢失所有工具链和缓存）
```

## Key Services

| Service          | Port  | Description                     |
| ---------------- | ----- | ------------------------------- |
| openclaw-gateway | 18789 | 主网关服务 (Web UI + WebSocket) |
|                  | 18790 | Bridge WebSocket 桥接           |
|                  | 18791 | Browser 浏览器调试端口          |

> **代理配置**: 通过 `HTTP_PROXY`/`HTTPS_PROXY` 环境变量配置外部代理，用于访问 Google 和 Claude API

## Configuration

- **环境变量**: `.env` 文件 (git-ignored)
- **时区**: 默认 `Asia/Shanghai`，可通过 `.env` 中 `TZ=...` 自定义
- **配置目录**: 容器内 `~/.openclaw/`

## Development Workflow

### 首次设置

```bash
make install          # 安装环境
make onboard          # 交互式配置 LLM/API
make up               # 启动服务
make dashboard        # 访问仪表盘 (自动带 token)
```

### 首次访问 UI 认证

1. **执行 `make dashboard`** - 生成带 token 的直通链接
2. **打开链接** - 浏览器自动保存 token 到 localStorage
3. **如需配对** - 执行 `make approve` 批准配对请求

```bash
make dashboard        # 一键直达仪表盘
make approve          # 如显示 "pairing required"
```

> Gateway token 由 `OPENCLAW_GATEWAY_TOKEN` 环境变量管理，entrypoint 自动同步到配置文件。

### 日常使用

```bash
make up               # 启动服务
make logs             # 查看日志
make down             # 停止服务
```

## Tips

- 容器内已安装 `gh` CLI，可用于 GitHub 操作
- 使用 `make exec CMD="openclaw config list"` 查看 OpenClaw 配置
- Gateway 日志位于容器内 `/tmp/openclaw-gateway.log`
- **gogcli**（Google Workspace CLI）：可选配置，详见 `docs/GOGCLI_SETUP.md`，支持 Gmail/Calendar/Drive/Sheets/Docs/Contacts

### 容器内已安装的 CLI 工具

| 工具 | 命令 | 说明 |
|------|------|------|
| OpenClaw | `openclaw` | 主 CLI |
| Claude Code | `claude` | Anthropic AI 编码助手 |
| Pi | `pi` | 终端编码工具 |
| OpenCode | `opencode` | OpenCode AI 助手 |
| gogcli | `gog` | Google Workspace CLI（可选，需手动配置，详见 `docs/GOGCLI_SETUP.md`）|

> 工具安装在 `/home/node/.global/bin/`，login shell 会自动加载 PATH。

## Troubleshooting

### Gateway Token 认证

**症状**: UI 报错 `unauthorized: gateway token missing` 或 `token mismatch`

**解决**:
```bash
make dashboard        # 使用直通链接
make approve          # 如显示 "pairing required"，然后刷新浏览器
```

### 配置错误修复

如遇 `Config invalid` 错误，可使用 `openclaw-config-fix` 技能自动诊断修复。

常见问题：
- `permissionMode` 枚举值非法 → 自动修复为 `approve-all`
- sentinel 阻止修复 → 删除 `/home/node/.openclaw_initialized`
- JSON 格式损坏 → 自动修复尾部逗号等

### Shell 脚本换行符问题

**症状**: `make up` 报错 `env: 'bash\r': No such file or directory` 或类似 `\r` 错误。

**原因**: Windows 下 Git 自动将换行符转为 CRLF。

**解决**:
DevKit 已内置 `.gitattributes` 强制执行 LF。若仍手动修改导致此问题，可执行：
```bash
sed -i 's/\r$//' docker-entrypoint.sh docker-setup.sh
make down && make up
```

## Dockerfile Development

### 工具架构映射表

| 工具 | amd64 命名 | arm64 命名 |
|------|-----------|-----------|
| yq | `amd64` | `arm64` |
| just | `x86_64` | `aarch64` |
| lazygit | `x86_64` | `arm64` |
| gh CLI | `amd64` | `arm64` |
| Go | `amd64` | `arm64` |

**推荐**: 在 RUN 命令中使用 `if-then-else-fi` 处理架构差异。

### 版本锁定原则

```bash
# ✅ 正确：锁定具体版本
ARG TOOL_VERSION=1.2.3
curl -fsSL "https://github.com/foo/bar/releases/download/v${TOOL_VERSION}/..."

# ❌ 错误：动态查询最新版本 (易触发 rate limit)
LATEST=$(curl -s https://api.github.com/repos/foo/bar/releases/latest | jq -r '.tag_name')
```

### Common Issues to Avoid

- **ARG scope**: 多阶段构建中，每个 stage 需重新声明 ARG
- **Package naming**: 使用 Debian Bookworm 标准包名 (无 `t64` 后缀)
- **Architecture in URLs**: 使用 `$(dpkg --print-architecture)` 动态获取架构
