---
name: openclaw-config-fix
description: |
  OpenClaw 配置专家。当用户报告 OpenClaw 配置错误、容器启动失败、或日志出现
  Config invalid / permissionMode / doctor / invalid config 等关键词时激活。
  作为 OpenClaw 专家，主动完成：日志模式分析 → 错误字段定位 →
  官方文档/GitHub Issue 查询 → 在容器内或宿主机正确路径修复 →
  验证结果。不需要用户指明文件位置或错误原因 —
  自动探测配置路径，结合已知问题库诊断未知错误。
triggers:
  - "OpenClaw 配置"
  - "openclaw.json"
  - "Config invalid"
  - "permissionMode"
  - "doctor --fix"
  - "previously repaired"
  - "invalid config"
  - "openclaw doctor"
  - "配置文件"
  - "OpenClaw 启动"
  - "OpenClaw 错误"
  - "gateway token"
  - "unauthorized"
---

# OpenClaw 配置诊断与修复

## 诊断工作流

```
1. 读日志 → 2. 定位字段 → 3. 查官方资料 → 4. 修复 → 5. 验证
```

不假设问题，按优先级验证每一步。

## 脚本工具说明

本技能包含 4 个 Python 脚本工具，位于 `scripts/` 目录：

| 脚本 | 功能 | 关键特性 |
|------|------|---------|
| `read_config.py` | 读取配置 | 支持 `--field` 指定字段、`--tree` 树形输出、`--keys` 键列表 |
| `fix_enum_field.py` | 修复枚举值 | 自动从日志解析错误、备份原配置、回滚机制 |
| `fix_json.py` | 修复 JSON 格式 | 迭代修复、最多 5 轮、自动备份 |
| `check_health.py` | 健康检查 | 支持 `--nagios`/`--json` 输出、容器状态检测 |

**脚本自动适配**：
- 自动检测 `docker compose` vs `docker-compose`
- 自动查找项目目录（当前目录 → `~/openclaw` → `~/openclaw-devkit` → 环境变量）
- 超时控制（日志 30s、doctor 60s、healthz 10s）

## Step 1: 读日志

```bash
cd ~/openclaw && docker compose logs --tail=100 openclaw-gateway 2>&1
```

常见错误模式（按优先级）：

| 模式 | 含义 | 优先级 |
|------|------|--------|
| `invalid config: must be equal to one of the allowed values` | 枚举字段非法 | P0 |
| `JSONDecodeError` / `SyntaxError` | JSON 格式损坏 | P0 |
| `previously repaired, skipping` | sentinel 阻止修复 | P1 |
| `EACCES` / `ENOENT` | 路径/权限问题 | P1 |
| `Config invalid` (无具体字段) | schema 校验失败 | P1 |
| `unauthorized` / `token` | 认证配置问题 | P1 |

保存关键错误行，供后续分析。

## Step 2: 读取配置并定位问题字段

**在容器内读取配置**（使用 `read_config.py`）：

```bash
# 完整配置
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- \
  python3 /home/node/.claude/skills/openclaw-config-fix/scripts/read_config.py

# 指定字段（如日志报告 permissionMode 问题）
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- \
  python3 /home/node/.claude/skills/openclaw-config-fix/scripts/read_config.py \
  --field plugins.entries.acpx.config.permissionMode

# 树形结构（快速浏览）
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- \
  python3 .../read_config.py --tree --max-depth 2
```

**检查 sentinel**（判断 entrypoint 是否跳过了自动修复）：

```bash
cd ~/openclaw && docker compose exec -T openclaw-gateway \
  test -f /home/node/.openclaw_initialized && \
  echo "sentinel 存在（修复被跳过）" || echo "sentinel 不存在"
```

## Step 3: 查询官方资料确认根因

### 已知问题库（优先查阅）

`references/known-issues.md` 包含所有已知问题的错误信息、根因和修复方法。
先查这里 — 大多数问题可以快速定位。

### GitHub Issue 搜索

如果已知问题库没有答案，搜索 GitHub：

```bash
# 搜索相关 Issue（用 MCP 或 gh CLI）
gh issue list --repo hrygo/openclaw --search "permissionMode" --limit 10

# 精确匹配错误
gh issue list --repo hrygo/openclaw \
  --search "must be equal to one of the allowed values" --limit 10
```

### Context7 文档查询

```bash
# 如果有 Context7 MCP，查询 OpenClaw 配置 schema
mcp__plugin_context7_context7__query-docs \
  --libraryId "/openclaw/openclaw" \
  --query "plugin config schema permissionMode valid values"
```

## Step 4: 修复

### P0: 枚举字段非法

使用 `fix_enum_field.py` — 自动从日志解析字段路径和允许值：

```bash
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- \
  python3 /home/node/.claude/skills/openclaw-config-fix/scripts/fix_enum_field.py
```

**特性**：
- 自动从日志提取错误 → 解析字段路径和允许值
- 将当前值改为第一个允许值 → 写入配置
- 自动备份到 `.bak`
- 失败时自动回滚

如需手动指定：
```bash
python3 fix_enum_field.py --field plugins.entries.acpx.config.permissionMode \
  --allowed approve-all approve-reads deny-all --dry-run
```

### P0: JSON 格式损坏

使用 `fix_json.py`：

```bash
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- \
  python3 /home/node/.claude/skills/openclaw-config-fix/scripts/fix_json.py
```

**特性**：
- 迭代修复（最多 5 轮）
- 自动备份带时间戳
- 修复失败可回滚

常见问题：尾部逗号、注释（`//` 和 `/* */`）、不规范空格

### P1: sentinel 阻止修复

```bash
cd ~/openclaw && docker compose exec -T openclaw-gateway rm -f /home/node/.openclaw_initialized
echo "sentinel 已删除，下次容器启动将重新执行 surgical repair"
```

### P1: 未知错误

先确认：
1. 错误字段在配置中是否存在
2. 插件版本与 OpenClaw 主版本兼容性
3. 搜索 GitHub Issue

```bash
# 版本兼容性检查
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- openclaw --version

# 搜索错误关键词
gh issue list --repo hrygo/openclaw --search "config invalid" --limit 10
```

## Step 5: 验证

### 诊断式验证（快速）

使用 `check_health.py`：

```bash
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- \
  python3 /home/node/.claude/skills/openclaw-config-fix/scripts/check_health.py
```

**输出模式**：
- 默认：人类可读
- `--nagios`：Nagios 格式（适合监控）
- `--json`：JSON 格式（适合脚本集成）
- `--doctor`：只运行 doctor

### 完整验证

```bash
# 1. 运行 doctor
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- \
  openclaw doctor --fix 2>&1 | grep -E "(error|invalid|Errors:|complete)"

# 2. 重启容器
cd ~/openclaw && docker compose restart openclaw-gateway
sleep 8

# 3. 观察日志
cd ~/openclaw && docker compose logs --tail=30 openclaw-gateway

# 4. 检查健康端点
cd ~/openclaw && curl -sf http://127.0.0.1:18789/healthz && echo " Gateway 健康"
```

**成功标志**：无 `Config invalid` / `invalid config` 错误，healthz 返回 200。

## 诊断报告

完成诊断后输出结构化报告：

```
## 诊断报告

### 错误
[关键日志行]

### 根因
[日志 + 配置 + 官方资料分析]

### 修复
[执行的命令]

### 验证
[doctor / 重启结果]
```

## 路径速查

> 详见 `references/config-paths.md`

| 操作 | 位置 |
|------|------|
| 读写配置 | 容器内 `/home/node/.openclaw/openclaw.json`（`runuser -u node`） |
| 查看日志 | 宿主机 `docker compose logs` |
| 删除 sentinel | 容器内 `rm /home/node/.openclaw_initialized` |
| 宿主机路径 | `~/.openclaw/openclaw.json` |

## 脚本错误处理

所有脚本包含以下错误处理机制：

| 机制 | 说明 |
|------|------|
| 超时控制 | 日志 30s、doctor 60s、healthz 10s |
| 自动备份 | 修复前备份到 `.bak` 或 `.bak.<timestamp>` |
| 回滚机制 | 写入失败时尝试恢复备份 |
| 友好错误 | 路径不存在时提示可用键列表 |
| 多 docker 版本 | 自动检测 `docker compose` / `docker-compose` |
| 项目目录查找 | 当前目录 → `~/openclaw` → 环境变量 |
