# OpenClaw DevKit 用户安装手册

本文档描述了从克隆仓库到完成配置的完整执行流程。

## 1. 极速起步

```bash
# 1. 安装与配置流程
make install    # 环境初始化（不启动服务）
make onboard    # 引导式配置（使用隔离容器，极其稳健）
make up         # 启动网关服务
```

> **提示**: 首次安装后，日常启动只需执行 `make up`

---

## 2. 安装执行全流程

```
git clone https://github.com/hrygo/openclaw-devkit.git
cd openclaw-devkit
make install [flavor]
       │
       ├─> 检查 Docker 运行环境
       ├─> 生成 .env 配置文件
       ├─> 准备宿主机目录 ~/.openclaw
       ├─> 获取最新容器镜像
       └─> 提示后续命令 (make onboard & make up)
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
make onboard
       │
       ▼
┌──────────────────────────────┐
│  Ephemeral Onboard Container │ ◄── 隔离容器 (docker run --rm)
│  $ openclaw onboard          │     不依赖正在运行的网关
│  交互式配置密钥与设置          │
└──────────┬───────────────────┘
           │ 配置保存至 ~/.openclaw
           ▼
┌──────────────────────────────┐
│  openclaw-gateway           │ ◄── 长期运行的主服务 (make up)
│  健康检查: 自动自愈 (Healing) │     
│  - 自动修复 host 路径泄露     │     
│  - 自动清理缺失 Secret 的模型  │     
└──────────────────────────────┘
```

### 5.2 端口说明

| 端口  | 服务             | 说明             |
| :---- | :--------------- | :--------------- |
| 18789 | Gateway Web UI   | HTTP 访问        |
| 18790 | Bridge           | WebSocket 桥接   |
| 18791 | Browser          | 浏览器调试端口   |

> **代理配置**: 通过环境变量 `HTTP_PROXY`/`HTTPS_PROXY` 配置外部代理访问

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
- **功能**：
  - 自动从环境变量 `OPENCLAW_GATEWAY_TOKEN` 获取 token
  - 生成带身份认证的直通 URL（格式：`http://127.0.0.1:18789/#token=xxx`）
  - 自动打开浏览器访问
- **效果**：绕过 `gateway token missing` 拦截，一键直达仪表盘

### 6.2 自动化配对 (Approve)
- **命令**：`make approve`
- **逻辑**：自动识别 Web UI 发出的最新 `pending` 请求 ID 并批准
- **使用场景**：首次访问 UI 时如显示 "pairing required"

### 6.3 Token 认证机制

Gateway token 由以下机制自动管理：

| 组件 | 说明 |
| :--- | :--- |
| 环境变量 | `OPENCLAW_GATEWAY_TOKEN`（自动生成） |
| 配置文件 | `~/.openclaw/openclaw.json` 中的 `gateway.auth.token` |
| 同步机制 | `docker-entrypoint.sh` 启动时自动同步环境变量到配置文件 |

**认证流程**：
```
make dashboard
      │
      ▼
生成带 token 的 URL ──► 浏览器打开 ──► token 保存到 localStorage
                                              │
                                              ▼
                                        认证成功 ✓
```

**常见问题**：

| 错误信息 | 原因 | 解决方案 |
| :--- | :--- | :--- |
| `gateway token missing` | 浏览器未保存 token | 使用 `make dashboard` 获取带 token 的链接 |
| `gateway token mismatch` | token 不一致 | 重启服务：`make restart`，再执行 `make dashboard` |
| `pairing required` | 需要配对授权 | 执行 `make approve` |

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
