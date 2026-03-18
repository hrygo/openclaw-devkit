# OpenClaw 已知配置问题

本文档记录所有已知的 openclaw.json 配置问题、根因和官方推荐修复方法。
按错误类型组织，每条包含：错误信息、触发条件、根因、修复、验证方法。

---

## 1. permissionMode 枚举值非法

**错误信息**：
```
plugins.entries.acpx.config.permissionMode: invalid config: must be equal to one of the allowed values (allowed: "approve-all", "approve-reads", "deny-all")
```

**触发条件**：acpx 插件早期版本写入的 `bypassPermissions` / `skipPermissions` 等废弃值

**根因**：acpx 插件升级后 schema 收紧了 `permissionMode` 的枚举范围

**修复**：
```bash
python3 scripts/fix_enum_field.py
# 自动从日志解析并修复
```

**验证**：`grep permissionMode ~/.openclaw/openclaw.json` 确认值为 `approve-all`

---

## 2. sentinel 阻止自动修复

**错误信息**：`Configuration previously repaired, skipping surgery and health check.`
但容器日志仍有 Config invalid 错误

**触发条件**：容器重启时 sentinel 存在，entrypoint 跳过 surgical repair

**根因**：配置文件在容器外被修改（宿主机编辑），但 entrypoint 不知道

**修复**：
```bash
docker compose exec -T openclaw-gateway rm -f /home/node/.openclaw_initialized
docker compose restart openclaw-gateway
```

---

## 3. 宿主机路径硬编码残留

**错误信息**：`EACCES` 或日志中出现 `/Users/xxx/.openclaw` 路径

**触发条件**：宿主机配置文件中有 macOS/Linux 路径，容器内无权访问

**根因**：路径迁移 sed 只在 surgical repair 时执行一次，宿主机修改后未重新触发

**修复**：entrypoint 的 surgical repair 会自动处理；手动验证：
```bash
grep -r "/Users/" ~/.openclaw/ 2>/dev/null | head -5
```

---

## 4. phantom auth profile 阻塞

**错误信息**：`auth.profiles."anthropic:default": phantom profile requires ANTHROPIC_AUTH_TOKEN`

**触发条件**：`ANTHROPIC_AUTH_TOKEN` 未设置但配置中存在 `anthropic:default` profile

**根因**：手动配置过 auth profile，后来 env token 被撤销

**修复**：entrypoint surgical repair 会自动删除（如果 `ANTHROPIC_AUTH_TOKEN` 为空）；或手动：
```bash
docker compose exec -T openclaw-gateway runuser -u node -- \
  python3 -c "
import json
cfg = json.load(open('/home/node/.openclaw/openclaw.json'))
for k in ['anthropic:default', 'openai:default']:
    if k in cfg.get('auth', {}).get('profiles', {}):
        del cfg['auth']['profiles'][k]
        print(f'已删除: {k}')
open('/home/node/.openclaw/openclaw.json', 'w').write(json.dumps(cfg, indent=2))
"
```

---

## 5. 插件 schema 版本不兼容

**错误信息**：特定插件（如 `mem9`、`acpx`）的 config 字段报错

**触发条件**：OpenClaw 主版本升级，插件配置 schema 发生变化

**排查**：
```bash
# 检查 OpenClaw 主版本
docker compose exec -T openclaw-gateway runuser -u node -- openclaw --version

# 检查插件版本
docker compose exec -T openclaw-gateway runuser -u node -- \
  cat /home/node/.openclaw/extensions/<plugin>/package.json | jq .version
```

**修复**：搜索 GitHub Issue 确认是否为已知问题及版本要求

---

## 6. 容器重启循环

**错误信息**：容器不断重启，`docker compose logs` 显示同一错误反复出现

**排查步骤**：
1. `docker compose logs --tail=50` 确认每次启动是否同错误
2. `docker compose exec openclaw-gateway cat /home/node/.openclaw_initialized` 检查 sentinel
3. `python3 scripts/check_health.py --nagios` 机器可读诊断

**根因组合**：通常是上述 #1 或 #2 的组合

---

## 7. Gateway token 认证失效

**错误信息**：`unauthorized: gateway token missing` 或 `token mismatch`

**触发条件**：`.env` 中 `OPENCLAW_GATEWAY_TOKEN` 被修改或清空

**修复**：
```bash
# 从 .env 重新同步 token 到容器
docker compose exec -T openclaw-gateway \
  env | grep OPENCLAW_GATEWAY_TOKEN

# 如果 token 丢失，重新生成
docker compose exec -T openclaw-gateway runuser -u node -- \
  openclaw config set gateway.auth.token "$(openssl rand -hex 32)"
```
