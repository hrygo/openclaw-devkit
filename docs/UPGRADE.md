# OpenClaw 升级指南

> 本指南适用于 openclaw-devkit v1.11.0 及更高版本。
> 涵盖 OpenClaw 核心从任意旧版本升级到最新版本（当前：**2026.3.23**）的全流程。

---

## 一、版本系统说明

openclaw-devkit 涉及两套独立版本体系：

| 体系 | 说明 | 版本示例 |
|------|------|---------|
| **openclaw 核心** | OpenClaw CLI 工具版本，由 `${OPENCLAW_VERSION}` 控制安装 | `2026.3.23` |
| **openclaw-devkit** | 容器化开发环境版本，由 Git tag 控制 | `v1.11.0` |

两者独立演进：
- **openclaw 核心**：跟随 OpenClaw 官方 releases（`YYYY.M.D` 或 `YYYY.M.D-N` 格式）
- **openclaw-devkit**：跟随 GitHub tag（`v{Major}.{Minor}.{Patch}` 语义化版本）

**本指南聚焦于 openclaw 核心的升级**（即 OpenClaw CLI 版本从 2026.3.13 → 2026.3.23）。

---

## 二、升级路径概览

```
旧架构（v1.7.x ~ v1.9.x）
┌─────────────────────────────────────────────────────────┐
│  镜像构建: openclaw@${OPENCLAW_VERSION}                  │
│  扩展目录: ~/.openclaw/extensions/openclaw-lark@v2026.3.17 │
│                          ↓                               │
│  用户 bind mount ~/.openclaw → 容器 ~/.openclaw         │
│                          ↓                               │
│  旧扩展使用 stale SDK → normalizeAccountId 报错 ❌        │
└─────────────────────────────────────────────────────────┘

新架构（v1.11.0+）
┌─────────────────────────────────────────────────────────┐
│  镜像构建: openclaw@${OPENCLAW_VERSION}                 │
│             + @larksuite/openclaw-lark@latest         │
│                          ↓                               │
│  ~/.global/ 安装（镜像层）                              │
│                          ↓                               │
│  entrypoint 自动同步到 ~/.openclaw/extensions/         │
│                          ↓                               │
│  版本自动对齐 → 插件正常加载 ✅                          │
└─────────────────────────────────────────────────────────┘
```

---

## 三、升级前检查

### 3.1 查看当前版本

```bash
# 容器内查看 OpenClaw 核心版本
make exec CMD="openclaw --version"

# 查看容器镜像版本
docker inspect openclaw-gateway --format='{{.Config.Image}}'

# 查看 openclaw-devkit 版本
git describe --tags --always HEAD

# 查看镜像构建时使用的 openclaw 版本（如果知道镜像 tag）
docker run --rm ghcr.io/hrygo/openclaw-devkit:go openclaw --version
```

### 3.2 确认需升级的功能

| 症状 | 原因 | 是否需要升级 |
|------|------|------------|
| `normalizeAccountId is not a function` | openclaw-lark 版本过旧 | ✅ 需要 |
| OpenClaw 版本低于目标版本 | 核心版本过旧 | ✅ 需要 |
| 健康检查超时 | 配置或网络问题 | ❌ 不需要 |

---

## 四、升级步骤

### 方式一：从源码构建（推荐，适用于所有版本）

#### Step 1：拉取最新代码

```bash
cd ~/openclaw-devkit
git fetch origin
git checkout main
git pull origin main
```

#### Step 2：确认最新 tag

```bash
git tag -l --sort=-v:refname | head -5
# v1.11.0
# v1.10.7
# v1.9.0
# ...

git checkout v1.11.0
```

#### Step 3：更新 .env 配置（首次设置）

```bash
cp .env.example .env   # 如果没有 .env 文件

# 编辑 .env，确保以下关键变量已设置：
# OPENCLAW_GATEWAY_TOKEN=your_token_here
# OPENCLAW_GATEWAY_URL=http://localhost:18789
```

#### Step 4：清理旧容器和卷（可选但推荐）

> ⚠️ 以下命令会删除所有工具链缓存和 OpenClaw 配置。如果有重要数据，请先备份。

```bash
# 备份配置（重要！）
make backup

# 停止并清理容器
make down

# 清理卷（重新开始，工具链会从镜像重新安装）
make clean-volumes
```

#### Step 5：重启服务

```bash
make restart
```

#### Step 6：验证升级结果

```bash
# 检查 OpenClaw 版本
make exec CMD="openclaw --version"
# 预期输出：OpenClaw 2026.3.23 (ccfeecb)

# 检查服务健康状态
docker inspect openclaw-gateway --format='{{.State.Health.Status}}'
# 预期输出：healthy

# 检查插件加载
docker logs openclaw-gateway --since 2m 2>&1 | grep -E "openclaw-lark|feishu\["
# 预期输出：feishu[default]: WebSocket connected
```

---

### 方式二：直接拉取最新镜像（不需要从源码构建）

适用于不想从源码构建、仅需使用最新版本的用户。

#### Step 1：拉取最新镜像

```bash
# 标准版
docker pull ghcr.io/hrygo/openclaw-devkit:latest

# Go 版（含 Go 工具链）
docker pull ghcr.io/hrygo/openclaw-devkit:go

# Java 版（含 JDK）
docker pull ghcr.io/hrygo/openclaw-devkit:java

# Office 版（含 LibreOffice）
docker pull ghcr.io/hrygo/openclaw-devkit:office
```

#### Step 2：停止旧容器

```bash
make down
```

#### Step 3：重启服务

```bash
make restart
```

> 注意：如果之前有旧版 `openclaw-lark` 扩展（v2026.3.17），entrypoint 会自动检测版本差异，将其备份并替换为镜像中的最新版本（v2026.3.25）。

---

## 五、关键配置说明

### 5.1 .env 关键变量

```bash
# Gateway 访问
OPENCLAW_GATEWAY_URL=http://localhost:18789
OPENCLAW_GATEWAY_TOKEN=your_token_here

# LLM Provider（必须配置至少一个）
ANTHROPIC_AUTH_TOKEN=sk-ant-...      # Anthropic API
OPENAI_API_KEY=sk-...                 # OpenAI API
GOOGLE_APPLICATION_CREDENTIALS=...   # Google Cloud

# 代理（如果需要访问外网）
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890

# OpenClaw 版本（由 CI 自动设置，一般不需手动修改）
OPENCLAW_VERSION=2026.3.23

# 时区
TZ=Asia/Shanghai
```

### 5.2 宿主机目录映射

```
宿主机                          容器内
~/.openclaw/    ──────────→    /home/node/.openclaw/      # 配置文件（持久化）
~/.claude/      ──────────→    /home/node/.claude/        # Claude Code 配置
/home/node/.global/                             # OpenClaw 工具（来自镜像层）
```

---

## 六、扩展同步机制（v1.11.0+ 新增）

### 6.1 工作原理

当使用 bind mount 将宿主机 `~/.openclaw` 挂载到容器时，镜像中预装的扩展内容会被完全覆盖。

为解决此问题，v1.11.0 引入 **entrypoint 扩展同步机制**：

```
容器启动
    ↓
检查 ~/.global/lib/node_modules/@larksuite/openclaw-lark
    ↓
对比 ~/.openclaw/extensions/openclaw-lark 的版本
    ↓
版本不一致？
    ├── 是 → 备份旧扩展 → 复制新扩展到 volume → 设置 root 所有权
    └── 否 → 跳过
```

### 6.2 相关日志

```bash
# 查看 entrypoint 扩展同步日志
docker logs openclaw-gateway 2>&1 | grep -E "Syncing|Backing up|synced to"
```

### 6.3 扩展备份

每次同步前，旧版本扩展会被备份到：

```
~/.openclaw/extensions/openclaw-lark.backup_YYYYMMDD_HHMMSS/
```

用户可随时查看备份内容，如需回滚可手动恢复。

---

## 七、常见问题排查

### 7.1 服务启动失败

```bash
# 查看完整日志
make logs

# 查看容器状态
docker ps -a

# 检查健康检查
docker inspect openclaw-gateway --format='{{json .State.Health}}' | python3 -m json.tool

# 检查端口是否被占用
lsof -i :18789 -i :18790 -i :18791
```

### 7.2 `normalizeAccountId is not a function` 错误

**原因**：旧版 `openclaw-lark` 扩展未升级。

**解决**：

```bash
# 方式 A：重启容器（entrypoint 自动同步）
make restart

# 方式 B：手动检查同步状态
docker logs openclaw-gateway 2>&1 | grep -E "Syncing|synced to"
# 如果没有同步日志，执行：
docker exec openclaw-gateway rm -f /home/node/.openclaw/extensions/openclaw-lark/.synced_from_image
make restart
```

### 7.3 健康检查超时

```bash
# 检查 Gateway 是否真正在运行
docker exec openclaw-gateway curl -s http://127.0.0.1:18789/healthz

# 查看 Gateway 进程
docker exec openclaw-gateway ps aux | grep openclaw

# 增加 health check 超时（编辑 docker-compose.yml 或 .env）
OPENCLAW_HEALTH_TIMEOUT=120
```

### 7.4 升级后配置丢失

**原因**：执行了 `make clean-volumes`。

**解决**：

```bash
# 恢复配置
make restore FILE=./openclaw-backup-YYYYMMDD.tar.gz

# 或手动恢复
tar -xzf openclaw-backup-YYYYMMDD.tar.gz -C ~/
```

### 7.5 Feishu WebSocket 连接失败

```bash
# 检查 Feishu 配置
make exec CMD="openclaw config get channels.feishu"

# 测试 Feishu 连接
make exec CMD="openclaw feishu probe"
```

---

## 八、回滚方案

### 8.1 回滚到旧版 openclaw-devkit

```bash
cd ~/openclaw-devkit
git checkout v1.10.7    # 替换为你要回滚的版本
make down
make restart
```

### 8.2 回滚 openclaw-lark 扩展

```bash
# 找到备份目录
ls -d ~/.openclaw/extensions/openclaw-lark.backup_*/

# 恢复
mv ~/.openclaw/extensions/openclaw-lark ~/.openclaw/extensions/openclaw-lark.new
cp -r ~/.openclaw/extensions/openclaw-lark.backup_YYYYMMDD_HHMMSS ~/.openclaw/extensions/openclaw-lark

# 重启
make restart
```

### 8.3 回滚 openclaw 核心版本

编辑 `.env`：

```bash
OPENCLAW_VERSION=2026.3.13    # 替换为你要回滚的版本
```

然后重建镜像：

```bash
make build && make restart
```

---

## 九、版本对照表

### openclaw-devkit 版本 vs openclaw 核心版本

| openclaw-devkit | openclaw 核心 | 主要变更 |
|----------------|--------------|---------|
| v1.7.x | ~2026.3.13 | 初始版本 |
| v1.8.x | ~2026.3.17 | Feishu 插件集成 |
| v1.9.x | ~2026.3.18 | 插件 SDK 更新 |
| v1.10.x | ~2026.3.22 | 性能优化 |
| **v1.11.0** | **2026.3.23** | **扩展同步架构修复** |

> **注意**：openclaw-devkit 版本与 openclaw 核心版本无严格一一对应关系。表格仅供参考。

---

## 十、快速命令参考

```bash
# 查看当前版本
openclaw --version

# 完整升级流程
make down && make pull && make up

# 仅重启服务
make restart

# 查看日志
make logs

# 备份配置
make backup

# 进入容器
make shell

# 执行 CLI 命令
make cli CMD="openclaw doctor"
```
