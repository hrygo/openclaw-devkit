# OpenClaw DevKit 用户安装手册

本文档描述了从克隆仓库到完成配置的完整执行流程。

## 1. 极速起步

```bash
# 1. 安装并启动
make install

# 2. 交互式配置（设置 LLM、Slack、飞书等）
make onboard
```

> **提示**: 首次安装后，日常启动只需执行 `make up`

---

## 2. 安装执行全流程

```
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit
make install [flavor]
       │
       ├─> 检查 Docker/Compose 环境
       ├─> 生成 .env（基于 .env.example）
       ├─> 创建配置目录 ~/.openclaw
       ├─> 拉取镜像 ghcr.io/hrygo/openclaw-devkit:latest
       ├─> 启动 openclaw-init（配置迁移）
       ├─> 启动 openclaw-gateway
       └─> 输出访问地址 http://127.0.0.1:18789
```

---

## 3. 版本选择

| 版本      | 镜像标签 | 适用场景      |
| :-------- | :------- | :------------ |
| 标准版    | `latest` | Web 开发      |
| Go 版     | `go`     | Go 后端开发   |
| Java 版   | `java`   | Java 后端开发 |
| Office 版 | `office` | 文档处理/RAG  |

```bash
# 安装指定版本
make install go
make install java
make install office
```

---

## 4. 进阶操作

### 4.1 日常维护

```bash
make up          # 启动服务
make down        # 停止服务
make restart     # 重启服务
make status      # 查看状态
```

### 4.2 诊断与排错

```bash
make logs              # 查看 Gateway 日志
make shell             # 进入容器 Shell
make test-proxy        # 测试代理连接
docker logs openclaw-init  # 查看配置迁移日志
```

### 4.3 构建与更新

```bash
make build            # 构建镜像（本地）
make rebuild          # 强制重建并重启
make clean            # 清理容器和悬空镜像
```

---

## 5. 容器运行时架构

### 5.1 启动流程

```
make install / make up
       │
       ▼
┌──────────────────────────────┐
│  openclaw-init              │ ◄── 一次性容器
│  $ openclaw doctor --fix   │     仅首次或配置问题时运行
│  修复过时配置字段           │
└──────────┬───────────────────┘
           │ 完成后自动删除
           ▼
┌──────────────────────────────┐
│  openclaw-gateway           │ ◄── 主服务
│  健康检查: curl 127.0.0.1:   │
│           18789/healthz      │
└──────────┬───────────────────┘
           │ depends_on: service_healthy
           ▼
┌──────────────────────────────┐
│  openclaw-cli               │ ◄── 按需启动
│  $ make onboard             │     交互式配置
│  $ make cli                 │     执行命令
└──────────────────────────────┘
```

### 5.2 端口说明

| 端口  | 服务             | 说明             |
| :---- | :--------------- | :--------------- |
| 18789 | Gateway Web UI   | HTTP 访问        |
| 18790 | Bridge           | WebSocket 桥接   |
| 7897  | HTTP Proxy       | 代理服务（可选） |
| 15721 | Claude API Proxy | API 代理（可选） |

### 5.3 数据持久化

| 数据类型 | 存储位置                    |
| :------- | :-------------------------- |
| 配置文件 | `~/.openclaw/openclaw.json` |
| 会话数据 | Docker 卷 `openclaw-state`  |
| 工作区   | `~/.openclaw/workspace`     |

---

## 6. Cockpit 运维引擎

### 6.1 一键直达 (Dashboard)
- **命令**：`make dashboard`
- **逻辑**：自动获取容器内 Gateway Token 并生成带身份的 URL。
- **效果**：绕过 `pairing required` 拦截，一键直达仪表盘。

### 6.2 自动化配对 (Approve)
- **命令**：`make approve`
- **逻辑**：自动识别 Web UI 发出的最新 `pending` 请求 ID 并批准。

---

## 7. Windows / WSL 适配

Windows / WSL 环境的 Docker 健康检查配置：
- **宽限期 (`start_period`)**：60s
- **重试 (`retries`)**：10 次
- **自愈**：容器入口脚本启动时自动执行 `doctor --fix`

---

## 8. 常见问题

### Q: 启动失败显示 "container is unhealthy"？

**原因**: 旧版本配置文件不兼容

**解决**:
```bash
# 方式 1: 自动修复（推荐）
make install

# 方式 2: 手动修复
docker logs openclaw-init    # 查看错误
docker exec openclaw-gateway openclaw doctor --fix
```

### Q: `make install` 会删掉我的数据吗？

**不会**。`make install` 是幂等操作，仅负责环境适配：
- 更新 `.env` 配置
- 检查 Docker 权限
- 修复过时的配置文件

### Q: 如何切换版本？

```bash
# 方式 1: 推荐（自动同步 .env 并重启）
make install go

# 方式 2: 强制拉取最新镜像
make rebuild
```

### Q: 访问地址是什么？

- **Web UI**: http://127.0.0.1:18789
- **Token**: 首次运行 `make install` 时生成的 Token
