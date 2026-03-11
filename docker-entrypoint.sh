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
    chown -R node:node "$CONFIG_DIR" 2>/dev/null || echo "Warning: Could not fix permissions (continuing anyway)"
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
        run_as_node openclaw onboard --non-interactive --accept-risk
    fi
fi

# 3. Ensure Gateway safety & access for Docker
# Run these as node to ensure generated metadata/temp files are owned correctly
if [ -f "$CONFIG_FILE" ]; then
    run_as_node openclaw config set gateway.mode local --strict-json >/dev/null 2>&1 || true
    run_as_node openclaw config set gateway.bind lan --strict-json >/dev/null 2>&1 || true
    run_as_node openclaw config set gateway.controlUi.allowedOrigins "${OPENCLAW_ALLOWED_ORIGINS:-[\"http://127.0.0.1:18789\"]}" --strict-json >/dev/null 2>&1 || true
fi

# 4. Execute CMD
# If root, drop privileges to 'node' to avoid subsequent permission issues
# This ensures all files created by the app (logs, sessions) belong to 'node'
echo "==> Starting OpenClaw..."
if [ "$(id -u)" = "0" ]; then
    exec runuser -u node -m -- "$@"
else
    exec "$@"
fi
