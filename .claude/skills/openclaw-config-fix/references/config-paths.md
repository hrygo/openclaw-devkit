# OpenClaw 配置文件路径参考

## 执行前提

> 所有 docker / make 命令需在项目目录执行：
> ```bash
> cd ~/openclaw && docker compose logs ...
> cd ~/openclaw && make logs
> ```
>
> **目录查找逻辑**：脚本会自动检测项目目录，优先级：
> 1. 当前目录（有 `docker-compose.yml`）
> 2. `~/openclaw`
> 3. `~/openclaw-devkit`
> 4. 环境变量 `OPENCLAW_PROJECT_DIR`

## 架构概览

openclaw-devkit 使用 bind mount 架构：宿主机路径 → 容器内 `/home/node/.openclaw/`。
宿主机上操作的配置文件，挂载后容器内立即可见（反之亦然）。

## 容器内路径

| 路径 | 说明 | 编辑方式 |
|------|------|---------|
| `/home/node/.openclaw/openclaw.json` | 主配置文件 | 容器内 `runuser -u node` |
| `/home/node/.openclaw/agents/` | 各 Agent 配置 | 同上 |
| `/home/node/.openclaw/extensions/` | 插件安装目录 | 同上 |
| `/home/node/.openclaw_initialized` | sentinel 标记文件 | `rm` 删除 |
| `/home/node/.openclaw/config.yaml` | 旧版配置 (如存在) | 同上 |

## 宿主机路径

`HOST_OPENCLAW_DIR` 环境变量控制（docker-compose.yml），默认：

| OS | 路径 |
|----|------|
| macOS | `~/.openclaw/` |
| Linux | `~/.openclaw/` |
| Windows | `%USERPROFILE%\.openclaw\` |

可通过 `.env` 中 `HOST_OPENCLAW_DIR=~/.openclaw` 自定义。

## 操作矩阵

| 任务 | 宿主机 | 容器内 |
|------|--------|--------|
| 读取配置 | `cat ~/.openclaw/openclaw.json` | `docker compose exec ... cat /home/node/.openclaw/openclaw.json` |
| 编辑配置 | 直接 vim/emacs | `runuser -u node -- vim /home/node/.openclaw/openclaw.json` |
| JSON 格式化验证 | `python3 -m json.tool ~/.openclaw/openclaw.json > /dev/null` | `python3 -c "import json; json.load(open('/home/node/.openclaw/openclaw.json'))"` |
| 删除 sentinel | 需进入容器 | `docker compose exec -T openclaw-gateway rm /home/node/.openclaw_initialized` |
| 查看日志 | `cd ~/openclaw && docker compose logs` | — |

## docker-entrypoint.sh 行为

1. **首次启动**：执行 surgical repair（路径迁移、auth cleanup）→ `doctor --fix` → 创建 sentinel
2. **后续启动**：检测 sentinel 存在 → 跳过 surgical repair 和 doctor
3. **sentinel 删除后**：下次容器启动重新执行完整修复流程

## 典型修复命令速查

> 前提：`cd ~/openclaw &&`

```bash
# 编辑配置（容器内，node 用户）
cd ~/openclaw && docker compose exec -T openclaw-gateway runuser -u node -- \
  vim /home/node/.openclaw/openclaw.json

# 删除 sentinel，强制重新修复
cd ~/openclaw && docker compose exec -T openclaw-gateway rm -f /home/node/.openclaw_initialized

# 重启并观察
cd ~/openclaw && docker compose restart openclaw-gateway && \
  sleep 8 && docker compose logs --tail=20

# 运行 make（项目 Makefile）
cd ~/openclaw && make logs
cd ~/openclaw && make restart
```
