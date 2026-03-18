#!/usr/bin/env bash
set -e

# ==============================================================================
# OpenClaw Docker Entrypoint
# Handles permission fixes, config seeding, Git identity, PIP tools, and
# privilege drop. Optimized for DevKit development environments.
# ==============================================================================

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
SEED_DIR="/home/node/.openclaw-seed"

# ------------------------------------------------------------------------------
# Helper: Run commands as the node user if currently root
# Uses env to explicitly override HOME (avoids -m preserving root's HOME)
# ------------------------------------------------------------------------------
run_as_node() {
    if [[ "$(id -u)" = "0" ]]; then
        runuser -u node -m -- env HOME="/home/node" PATH="/home/node/.global/bin:/home/node/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin" "$@"
    else
        "$@"
    fi
}

# ------------------------------------------------------------------------------
# Helper: Validate package name (alphanumeric, hyphens, underscores, dots)
# Prevents command injection via PIP_TOOLS environment variable
# ------------------------------------------------------------------------------
validate_pkg_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "ERROR: Invalid package name: $name" >&2
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 0. Cleanup stale temporary files from previous runs
# ------------------------------------------------------------------------------
find "${CONFIG_DIR}" -name "*.tmp" -type f -delete 2>/dev/null || true
find "${CONFIG_DIR}" -name "*.bak" -type f -delete 2>/dev/null || true

# ------------------------------------------------------------------------------
# 1. Fix Permissions & Create Directories (if running as root)
#    Solves EACCES issues with host-mounted volumes
# ------------------------------------------------------------------------------
if [[ "$(id -u)" = "0" ]]; then
    echo "--> Optimizing file access policy for ${CONFIG_DIR}..."
    mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
    chown -R node:node "${CONFIG_DIR}" 2>/dev/null || true

    # Seed directory for initial configuration
    if [[ -d "${SEED_DIR}" ]]; then
        chown -R node:node "${SEED_DIR}" 2>/dev/null || true
    fi

    # Go module cache (Docker volume may be owned by root)
    if [[ -d "/home/node/go" ]]; then
        echo "--> Fixing Go module cache permissions..."
        chown -R node:node /home/node/go 2>/dev/null || true
    fi

    # Go build cache
    if [[ -d "/home/node/.cache/go-build" ]]; then
        echo "--> Fixing Go build cache permissions..."
        chown -R node:node /home/node/.cache/go-build 2>/dev/null || true
    fi

    # Python user packages directory (for uv pip install --user persistence)
    if [[ -d "/home/node/.local" ]]; then
        echo "--> Fixing pip packages permissions..."
        chown -R node:node /home/node/.local 2>/dev/null || true
    fi

    # notebooklm directory (shared with host)
    if [[ -d "/home/node/.notebooklm" ]]; then
        echo "--> Fixing notebooklm permissions..."
        chown -R node:node /home/node/.notebooklm 2>/dev/null || true
    fi

    # Claude directory (shared with host)
    if [[ -d "/home/node/.claude" ]]; then
        echo "--> Fixing Claude permissions..."
        chown -R node:node /home/node/.claude 2>/dev/null || true
    fi

    # Unified global tools directory (persistent via named volume)
    if [[ -d "/home/node/.global" ]]; then
        echo "--> Fixing global tools permissions..."
        chown -R node:node /home/node/.global 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 2. Configuration Health Check & Surgical Repair
#    Handles legacy schema issues (contextPruning, compaction, etc.)
# ------------------------------------------------------------------------------
echo "--> Pre-checking configuration health..."
run_as_node openclaw doctor --fix >/dev/null 2>&1 || true

if [[ -f "${CONFIG_FILE}" ]]; then
    echo "--> Running configuration surgical repair..."
    
    # 0. Global Path Surgery (Incremental / Migratory)
    # Identify and fix host path leaks that cause EACCES in the container.
    # We use a flag file to ensure this O(N) scan only runs once (or when reset).
    SURGERY_FLAG="${CONFIG_DIR}/.path_surgery_complete"
    if [[ ! -f "${SURGERY_FLAG}" ]]; then
        echo "--> Performing one-time environment path surgery..."
        find "${CONFIG_DIR}" -type f \( -name "*.json" -o -name "*.jsonl" \) -print0 | xargs -0 sed -i "s|/Users/[^/]*/\.openclaw|/home/node/.openclaw|g" || true
        find "${CONFIG_DIR}" -type f \( -name "*.json" -o -name "*.jsonl" \) -print0 | xargs -0 sed -i "s|/home/[^/]*/\.openclaw|/home/node/.openclaw|g" || true
        touch "${SURGERY_FLAG}"
        echo "--> Path surgery migration completed."
    fi

    # Deep cleanup using Node.js for surgical removal of obsolete nodes
    # Node.js guarantees JSON validity, unlike sed which can corrupt structure
    export OPENCLAW_CONFIG_FILE="${CONFIG_FILE}"
    run_as_node node -e '
        const fs = require("fs");
        const path = process.env.OPENCLAW_CONFIG_FILE;
        try {
            const data = fs.readFileSync(path, "utf8");
            const config = JSON.parse(data);

            // 1. Clean legacy schema nodes
            if (config.agents && config.agents.defaults) {
                delete config.agents.defaults.contextPruning;
                delete config.agents.defaults.compaction;
            }

            // 2. Cleanup "phantom" auth profiles that block startup
            // If a profile exists but its mandatory environment variable is missing, remove it.
            if (config.auth && config.auth.profiles) {
                for (const [id, profile] of Object.entries(config.auth.profiles)) {
                    // Specific check for Anthropic/OpenAI defaults that often cause blocks
                    if (id === "anthropic:default" && !process.env.ANTHROPIC_AUTH_TOKEN) {
                        delete config.auth.profiles[id];
                        console.log("--> Pruned phantom auth profile: " + id);
                    } else if (id === "openai:default" && !process.env.OPENAI_AUTH_TOKEN) {
                        delete config.auth.profiles[id];
                        console.log("--> Pruned phantom auth profile: " + id);
                    }
                }
            }

            // 3. Agent-specific auth-profiles.json cleanup
            // Prune profiles that reference missing environment variables in any agent
            const agentsDir = require("path").join(require("path").dirname(path), "agents");
            if (fs.existsSync(agentsDir)) {
                fs.readdirSync(agentsDir).forEach(agentId => {
                    const authPath = require("path").join(agentsDir, agentId, "agent", "auth-profiles.json");
                    if (fs.existsSync(authPath)) {
                        try {
                            const authData = JSON.parse(fs.readFileSync(authPath, "utf8"));
                            let changed = false;
                            if (authData.profiles) {
                                Object.keys(authData.profiles).forEach(id => {
                                    const profile = authData.profiles[id];
                                    if (profile.keyRef && profile.keyRef.source === "env" && !process.env[profile.keyRef.id]) {
                                        delete authData.profiles[id];
                                        changed = true;
                                        console.log("--> [Agent: " + agentId + "] Pruned phantom secret ref: " + profile.keyRef.id);
                                    }
                                });
                            }
                            if (changed) fs.writeFileSync(authPath, JSON.stringify(authData, null, 2));
                        } catch (e) {}
                    }
                });
            }

            // 4. Force DevKit Gateway Best-Practices
            config.gateway = config.gateway || {};
            config.gateway.bind = "lan";
            config.gateway.mode = "local";
            config.gateway.controlUi = config.gateway.controlUi || {};

            // Comprehensive whitelist for Windows/WSL/Docker dev environments
            const baseOrigins = [
                "http://127.0.0.1:18789",
                "http://localhost:18789",
                "http://0.0.0.0:18789",
                "http://host.docker.internal:18789"
            ];

            // Add custom origins if provided via ENV
            let customOrigins = [];
            try {
                const envOrigins = process.env.OPENCLAW_ALLOWED_ORIGINS;
                if (envOrigins) customOrigins = JSON.parse(envOrigins);
            } catch (e) {}

            config.gateway.controlUi.allowedOrigins = [...new Set([...baseOrigins, ...customOrigins])];

            fs.writeFileSync(path, JSON.stringify(config, null, 2));
            console.log("--> OpenClaw configuration surgically optimized for DevKit.");
        } catch (e) {
            console.error("Warning: Configuration surgery failed: " + e.message);
        }
    ' || true

    # Re-run doctor to fill in any missing required fields
    run_as_node openclaw doctor --fix >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 3. Initialize Missing Configuration
# ------------------------------------------------------------------------------
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "==> Initializing fresh OpenClaw environment..."

    # Try to copy from seed if available
    if [[ -d "${SEED_DIR}" ]] && [[ "$(ls -A "${SEED_DIR}" 2>/dev/null)" ]]; then
        echo "--> Copying initial configuration from seed..."
        run_as_node cp -rn "${SEED_DIR}"/* "${CONFIG_DIR}/" 2>/dev/null || true
    fi

    # If still missing, run official setup
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "--> Running official OpenClaw onboarding (non-interactive)..."
        run_as_node openclaw onboard --non-interactive --accept-risk || true
    fi
fi

# ------------------------------------------------------------------------------
# 4. Claude Code Embedded Skills - Survive host bind-mount
#    Re-injects skills from staging layer into the live mount point
# ------------------------------------------------------------------------------
CLAUDE_DIR="/home/node/.claude"
CLAUDE_SEED="/opt/claude-seed"
if [[ -d "${CLAUDE_SEED}" ]]; then
    echo "--> Verifying Claude embedded skills integrity..."
    run_as_node mkdir -p "${CLAUDE_DIR}"
    # Copy missing/updated skills (-n to not overwrite user edits)
    run_as_node cp -Rn "${CLAUDE_SEED}"/* "${CLAUDE_DIR}/" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 5. NotebookLM CLI is now built-in (pre-installed in Docker image)
# Ensure symlink for config directory (CLI looks in /root/.notebooklm)
# ------------------------------------------------------------------------------
if [[ -d "/home/node/.notebooklm" ]] && [[ ! -d "/root/.notebooklm" ]]; then
    ln -sf /home/node/.notebooklm /root/.notebooklm
    echo "--> Linked /root/.notebooklm -> /home/node/.notebooklm"
fi

# ------------------------------------------------------------------------------
# 6. Git Identity Injection (from environment variables)
#    Allows configuring Git identity via .env without host .gitconfig dependency
# ------------------------------------------------------------------------------
if [[ -n "${GIT_USER_NAME:-}" ]]; then
    echo "--> Setting Git identity: ${GIT_USER_NAME}"
    run_as_node git config --global user.name "${GIT_USER_NAME}" || echo "    Warning: Failed to set git user.name"
fi
if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
    run_as_node git config --global user.email "${GIT_USER_EMAIL}" || echo "    Warning: Failed to set git user.email"
fi

# Auto-configure safe.directory for mounted project volumes
PROJECTS_DIR="/home/node/projects"
if [[ -d "${PROJECTS_DIR}" ]]; then
    run_as_node git config --global --add safe.directory "${PROJECTS_DIR}" || true
    # Also add all first-level subdirectories (cloned repos)
    for d in "${PROJECTS_DIR}"/*/; do
        [[ -d "${d}.git" ]] && run_as_node git config --global --add safe.directory "${d}" || true
    done
fi

# ------------------------------------------------------------------------------
# 7. Ensure Gateway Configuration for Docker
#    Always set these values to ensure consistency across restarts and upgrades
# ------------------------------------------------------------------------------
run_as_node openclaw config set gateway.mode local --strict-json >/dev/null 2>&1 || true
run_as_node openclaw config set gateway.bind lan --strict-json >/dev/null 2>&1 || true
run_as_node openclaw config set gateway.controlUi.allowedOrigins "${OPENCLAW_ALLOWED_ORIGINS:-[\"http://127.0.0.1:18789\", \"http://localhost:18789\", \"http://0.0.0.0:18789\"]}" --strict-json >/dev/null 2>&1 || true

# Sync gateway token from environment variable to config (ensures dashboard URL works)
if [[ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
    run_as_node openclaw config set gateway.auth.token "\"${OPENCLAW_GATEWAY_TOKEN}\"" --strict-json >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 9. Unified Global Tools Directory
#    Pre-configured in Dockerfile, ensure symlink exists at runtime
# ------------------------------------------------------------------------------
mkdir -p /home/node/.global
mkdir -p /home/node/.local
if [[ -d "/home/node/.global/bin" ]] && [[ ! -L "/usr/local/bin/global" ]]; then
    ln -sf /home/node/.global/bin /usr/local/bin/global
fi

# ------------------------------------------------------------------------------
# 10. Execute CMD (drop privileges if root)
#    Ensures all files created by the app belong to 'node' user
# ------------------------------------------------------------------------------
echo "==> Starting OpenClaw..."
if [[ "$(id -u)" = "0" ]]; then
    export HOME="/home/node"
    # PATH already set in environment, ensure global tools are accessible
    exec runuser -u node -m -- env PATH="/home/node/.global/bin:/home/node/.local/bin:${PATH}" "$@"
else
    exec "$@"
fi
