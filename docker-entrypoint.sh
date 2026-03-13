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

# 1. Optimize File Access (if running as root)
# Windows users: Permission warnings can be safely ignored on host mounts.
if [ "$(id -u)" = "0" ]; then
    echo "--> Optimizing file access policy for $CONFIG_DIR..."
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
run_as_node openclaw config set gateway.mode local --strict-json >/dev/null 2>&1 || true
run_as_node openclaw config set gateway.bind lan --strict-json >/dev/null 2>&1 || true
run_as_node openclaw config set gateway.controlUi.allowedOrigins '["http://127.0.0.1:18789"]' --strict-json >/dev/null 2>&1 || true

# 4. Execute CMD
# If root, drop privileges to 'node' to avoid subsequent permission issues
# This ensures all files created by the app (logs, sessions) belong to 'node'
echo "==> Starting OpenClaw..."
if [ "$(id -u)" = "0" ]; then
    # Ensure HOME is correctly set for node before execution
    export HOME=/home/node
    exec runuser -u node -m -- "$@"
else
    exec "$@"
fi
