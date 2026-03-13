#!/usr/bin/env bash
set -e

# OpenClaw Docker Entrypoint
# Handles auto-initialization and permission fixes

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
SEED_DIR="/home/node/.openclaw-seed"

# Helper to run commands as the node user if currently root
run_as_node() {
    if [ "$(id -u)" = "0" ]; then
        runuser -u node -m -- "$@"
    else
        "$@"
    fi
}

# 1. Fix Permissions (if running as root)
# This solves the EACCES issue with host-mounted volumes
if [ "$(id -u)" = "0" ]; then
    echo "--> Fixing permissions for $CONFIG_DIR..."
    chown -R node:node "$CONFIG_DIR" 2>/dev/null || true
fi

# 1.5 Surgical Config Repair (Resilience)
# 针对配置文件版本过旧导致的局部 Schema 崩溃（如：windowSize, contextPruning 等）
# 采取“自愈复原”策略：如果 doctor 无法修复，我们将尝试强制升级/重置配置
if [ -f "$CONFIG_FILE" ]; then
    echo "--> Running configuration health check & surgical repair..."
    
    # 获取当前版本并尝试内置修复
    run_as_node openclaw doctor --fix >/dev/null 2>&1 || true
    
    # 深度净化逻辑：使用 Node.js 手术级移除可能导致 Zod 校验失败的过时节点
    # 相比 sed，Node.js 能百分之百保证 JSON 结构的合法性，不会产生语法错误
    run_as_node node -e "
        const fs = require('fs');
        const path = '$CONFIG_FILE';
        try {
            const data = fs.readFileSync(path, 'utf8');
            const config = JSON.parse(data);
            if (config.agents && config.agents.defaults) {
                console.log('--> Cleaning agents.defaults.contextPruning...');
                delete config.agents.defaults.contextPruning;
                console.log('--> Cleaning agents.defaults.compaction...');
                delete config.agents.defaults.compaction;
            }
            fs.writeFileSync(path, JSON.stringify(config, null, 2));
        } catch (e) {
            console.error('Warning: Configuration surgery failed: ' + e.message);
        }
    " || true
    
    # 再次尝试内置修复以补全缺失的必要字段
    run_as_node openclaw doctor --fix >/dev/null 2>&1 || true
fi

# 2. Check for missing configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "==> Initializing fresh OpenClaw environment..."
    
    # Try to copy from seed if available
    if [ -d "$SEED_DIR" ] && [ "$(ls -A "$SEED_DIR" 2>/dev/null)" ]; then
        echo "--> Copying initial configuration from seed..."
        run_as_node cp -rn "$SEED_DIR"/* "$CONFIG_DIR/" 2>/dev/null || true
    fi
    
    # If still missing, run official setup
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "--> Running official OpenClaw onboarding (non-interactive)..."
        # Allow failure here; often the config is created but a secondary gateway check fails.
        run_as_node openclaw onboard --non-interactive --accept-risk || true
    fi

    # After onboarding, configure custom skills directories
    if [ -f "$CONFIG_FILE" ]; then
        echo "--> Creating custom skills directories..."
        run_as_node mkdir -p /home/node/skills/custom-skills
        run_as_node mkdir -p /home/node/skills/team-skills

        echo "--> Configuring custom skills directories..."
        run_as_node python3 -c '
import json
import os

# 定义配置文件路径
config_path = "/home/node/.openclaw/openclaw.json"

# 确保目录存在（避免文件写入失败）
os.makedirs(os.path.dirname(config_path), exist_ok=True)

# 读取并更新配置
try:
    # 读取现有配置（文件不存在则创建空字典）
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            config = json.load(f)
    else:
        config = {}

    # 逐层初始化节点，避免KeyError
    config["skills"] = config.get("skills", {})
    config["skills"]["load"] = config["skills"].get("load", {})
    # 设置自定义技能目录
    config["skills"]["load"]["extraDirs"] = [
        "/home/node/skills/custom-skills",
        "/home/node/skills/team-skills"
    ]
    # 开启目录监听
    config["skills"]["load"]["watch"] = True

    # 写入配置（带缩进，保证可读性）
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)

    print(f"配置更新成功！路径：{config_path}")
except Exception as e:
    print(f"配置更新失败：{str(e)}")
' || echo "Warning: Failed to configure skills directories"
    fi
fi

# 2.5 Ensure Claude Code Embedded Skills survive the host bind-mount
# The host `~/.claude` might be an empty directory or missing the Playwright skills
# mapped via docker-compose.yml. We re-inject them on every startup from the safe-zone over mount points.
CLAUDE_DIR="/home/node/.claude"
CLAUDE_SEED="/opt/claude-seed"
if [ -d "$CLAUDE_SEED" ]; then
    echo "--> Verifying Claude embedded skills integrity..."
    run_as_node mkdir -p "$CLAUDE_DIR"
    # Copy missing/updated skills from our staging layer into the live mount (-r for recursive, -n to not overwrite user edits if any)
    run_as_node cp -Rn "$CLAUDE_SEED"/* "$CLAUDE_DIR/" 2>/dev/null || true
fi

# 2.8 Identity Injection: Configure Git if environment variables are provided
if [ -n "${GIT_USER_NAME:-}" ]; then
    echo "--> Setting Git identity: $GIT_USER_NAME"
    run_as_node git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
    run_as_node git config --global user.email "$GIT_USER_EMAIL"
fi

# 3. Ensure Gateway safety & access for Docker
# Run these as node to ensure generated metadata/temp files are owned correctly
# Always set these values to ensure consistency across restarts and upgrades
# Set UTF-8 locale for proper character encoding
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LANGUAGE=en_US:en

run_as_node openclaw config set gateway.mode local --strict-json >/dev/null 2>&1 || true
run_as_node openclaw config set gateway.bind lan --strict-json >/dev/null 2>&1 || true
run_as_node openclaw config set gateway.controlUi.allowedOrigins '["http://127.0.0.1:18789"]' --strict-json >/dev/null 2>&1 || true

# 4. Execute CMD
# If root, drop privileges to 'node' to avoid subsequent permission issues
# This ensures all files created by the app (logs, sessions) belong to 'node'
# Use 'exec env' to explicitly pass locale environment variables
echo "==> Starting OpenClaw..."
if [ "$(id -u)" = "0" ]; then
    exec runuser -u node -m -- env LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE=en_US:en "$@"
else
    exec "$@"
fi
