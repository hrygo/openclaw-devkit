#!/usr/bin/env bash
set -e

# ==============================================================================
# OpenClaw Docker Entrypoint
# Handles permission fixes, config seeding, Git identity, and privilege drop.
# Optimized for DevKit development environments.
#
# Architecture (v4):
# - Named volume: openclaw-devkit-home:/home/node (tools, caches)
# - Named volume: openclaw-claude-home:/home/node/.claude (session, memory)
# - RO bind: settings.json, skills/ (host-managed)
# - RW bind: .openclaw, .notebooklm (bind mount, NOTEBOOKLM_STORAGE env var controls path)
#
# Performance optimizations:
# - Always chown named volumes (cheap, prevents stale root ownership)
# - One-time surgery + one-time doctor (gateway manages config afterwards)
# ==============================================================================

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
# Flags in named volume (writable) - avoids read-only mount conflicts
SURGERY_FLAG="/home/node/.openclaw_initialized"

# Global tools path for node user
NODE_GLOBAL_PATH="/home/node/.opencode/bin:/home/node/.global/bin:/home/node/.local/bin"

# ------------------------------------------------------------------------------
# Helper: Run commands as the node user if currently root
# Uses env to explicitly override HOME (avoids -m preserving root's HOME)
# ------------------------------------------------------------------------------
run_as_node() {
    if [[ "$(id -u)" = "0" ]]; then
        runuser -u node -m -- env HOME="/home/node" PATH="${NODE_GLOBAL_PATH}:${PATH}" "$@"
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
# 1. Volume Permission Fix
#    - Named volume dirs: always chown to node (cheap, prevents stale root ownership)
#    - Bind mounts: fix only if empty or wrong owner (preserves host data)
# ------------------------------------------------------------------------------
if [[ "$(id -u)" = "0" ]]; then
    # Always fix named volume permissions (chown is cheap, ~5ms, avoids stale root ownership).
    # Bind mounts: fix only if empty or not already owned by node user (preserves host data).
    echo "--> Checking volume permissions..."

    # Named volume directories: create if missing (empty volumes have no contents from image),
    # then chown to node (idempotent, cheap ~5ms, prevents stale root ownership).
    for dir in "/home/node/.claude" "/home/node/.global" "/home/node/.local" "/home/node/.agents" "/home/node/go" "/home/node/.cache" "/app" "/var/tmp/openclaw-compile-cache"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}"
        fi
        chown -R node:node "${dir}" 2>/dev/null || true
    done

    # Bind mount directories: only fix if empty or wrong owner (preserve host data)
    for dir in "/home/node/.openclaw" "/home/node/.notebooklm"; do
        if [[ -d "${dir}" ]]; then
            if [[ -z "$(ls -A "${dir}" 2>/dev/null)" ]] || \
               [[ "$(stat -c '%u' "${dir}" 2>/dev/null)" != "1000" ]]; then
                chown -R node:node "${dir}" 2>/dev/null || true
            fi
        fi
    done

    # Ensure extension plugins have correct ownership (root-owned to pass ownership checks)
    # OpenClaw plugin loader checks ownership of non-bundled plugins:
    #   - Must match process uid (root=0) OR be root-owned (uid=0)
    #   - Root ownership signals "system-managed" and bypasses user-writeable-path checks
    # We chown to root (0:0) since entrypoint runs as root; node-owned plugins are blocked.
    # Note: acpx is bundled via npm package (in node_modules), mem9/lark are user-installed.
    if [[ -d "/home/node/.openclaw/extensions/mem9" ]]; then
        chown -R 0:0 /home/node/.openclaw/extensions/mem9 2>/dev/null || true
    fi
    if [[ -d "/home/node/.openclaw/extensions/openclaw-lark" ]]; then
        chown -R 0:0 /home/node/.openclaw/extensions/openclaw-lark 2>/dev/null || true
    fi
    if [[ -d "/home/node/.global/lib/node_modules/openclaw/extensions/acpx" ]]; then
        chown -R 0:0 /home/node/.global/lib/node_modules/openclaw/extensions/acpx 2>/dev/null || true
    fi

    echo "--> Volume permissions OK."
fi

# ------------------------------------------------------------------------------
# 2. Configuration Health Check & Surgical Repair
#    - Surgery: runs once (path migration + Node.js cleanup)
#    - Doctor: runs once after surgery, then skipped (gateway manages config afterwards)
#
#    Note: Gateway modifies openclaw.json on startup (adding/updating fields).
#    This causes hash changes on every startup, making hash-based detection unreliable.
#    Instead, we rely on one-time surgery + one-time doctor, then trust the gateway.
# ------------------------------------------------------------------------------
echo "--> Pre-checking configuration health..."

if [[ -f "${CONFIG_FILE}" ]]; then
    # 2a. One-time surgical repair (path migration + Node.js cleanup)
    # Always run this section once - it's idempotent and necessary for dev environment
    if [[ ! -f "${SURGERY_FLAG}" ]]; then
        echo "--> Running one-time configuration surgical repair..."

        # Path migration: fix host paths that cause EACCES in container
        echo "--> Performing environment path surgery..."
        find "${CONFIG_DIR}" -type f \( -name "*.json" -o -name "*.jsonl" \) -print0 2>/dev/null | xargs -0 -r sed -i "s|/Users/[^/]*/\.openclaw|/home/node/.openclaw|g" 2>/dev/null || true
        find "${CONFIG_DIR}" -type f \( -name "*.json" -o -name "*.jsonl" \) -print0 2>/dev/null | xargs -0 -r sed -i "s|/home/[^/]*/\.openclaw|/home/node/.openclaw|g" 2>/dev/null || true

        # Deep cleanup using Node.js for surgical removal of obsolete nodes
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
                if (config.auth && config.auth.profiles) {
                    for (const [id, profile] of Object.entries(config.auth.profiles)) {
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

                const baseOrigins = [
                    "http://127.0.0.1:18789",
                    "http://localhost:18789",
                    "http://0.0.0.0:18789",
                    "http://host.docker.internal:18789"
                ];

                let customOrigins = [];
                try {
                    const envOrigins = process.env.OPENCLAW_ALLOWED_ORIGINS;
                    if (envOrigins) customOrigins = JSON.parse(envOrigins);
                } catch (e) {}

                config.gateway.controlUi.allowedOrigins = [...new Set([...baseOrigins, ...customOrigins])];

                // Security hardening: enforce Slack channel allowlist policy
                if (config.channels?.slack && config.channels.slack.groupPolicy !== "allowlist") {
                    config.channels.slack.groupPolicy = "allowlist";
                    console.log("--> Slack channel policy hardened to allowlist.");
                }

                fs.writeFileSync(path, JSON.stringify(config, null, 2));
                console.log("--> OpenClaw configuration surgically optimized for DevKit.");
            } catch (e) {
                console.error("Warning: Configuration surgery failed: " + e.message);
            }
        ' || true

        # Security hardening: lock down config file (contains tokens/secrets)
        chmod 600 "${CONFIG_FILE}" 2>/dev/null || true

        # 2b. Run doctor once after surgery to ensure config is valid
        echo "--> Running post-surgery health check..."
        run_as_node openclaw doctor --fix >/dev/null 2>&1 || true

        touch "${SURGERY_FLAG}"
        echo "--> Configuration surgical repair completed."
    else
        # Surgery already done - gateway manages config from now on
        echo "--> Configuration previously repaired, skipping surgery and health check."
    fi
else
    # No config file - bind mount (HOST_OPENCLAW_DIR) is empty or new
    echo "==> Initializing fresh OpenClaw environment..."

    # Ensure openclaw.json exists (run official setup if still missing)
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "--> 运行 OpenClaw 初始化向导..."
        run_as_node openclaw onboard --non-interactive --accept-risk || true
    fi
fi

# ------------------------------------------------------------------------------
# 4. Claude Code Runtime Files
#    .claude/ is backed by openclaw-claude-home named volume.
#    settings.json and skills/ are read-only bind mounts from host.
#    No seed copying needed - session/memory persist across rebuilds.
# ------------------------------------------------------------------------------
# Ensure .claude.json exists (Claude Code CLI requires this file)
# Create empty JSON object if missing to prevent "configuration file not found" warnings.
# This file stores userID, project configs, MCP servers, and other CLI runtime state.
# Ref: https://code.claude.com/docs/en/settings
CLAUDE_JSON="/home/node/.claude.json"
if [[ ! -f "${CLAUDE_JSON}" ]]; then
    echo "--> Creating empty .claude.json configuration file..."
    run_as_node sh -c "echo '{}' > '${CLAUDE_JSON}'"
    if [[ "$(id -u)" = "0" ]]; then
        chown node:node "${CLAUDE_JSON}" 2>/dev/null || true
    fi
fi

echo "--> Optimizing Claude Code runtime configuration..."
run_as_node node -e '
    const fs = require("fs");
    const path = "'"${CLAUDE_JSON}"'";
    let config = {};
    try {
        config = JSON.parse(fs.readFileSync(path, "utf8"));
        if (typeof config !== "object" || config === null) config = {};
    } catch (e) { config = {}; }

    // Clean up isolated userID field (prevents login prompts)
    delete config.userID;

    // Prevent onboarding tips
    config.hasCompletedOnboarding = true;

    fs.writeFileSync(path, JSON.stringify(config, null, 2));
'

# ------------------------------------------------------------------------------
# 5. Git Identity Injection
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

# Batch-update all config values in a single Node.js invocation.
# Previously each value was set via a separate `openclaw config set` CLI call,
# which cost ~5s each (Node.js startup + plugin init), totalling ~30s.
# One Node.js script doing all updates takes ~1.5s — a ~20x speedup.
echo "--> Batch-updating gateway and skills configuration..."
run_as_node node -e "
const fs = require('fs');
const path = '${CONFIG_FILE}';
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(path, 'utf8')); } catch(e) {}

cfg.gateway = cfg.gateway || {};
cfg.gateway.mode = 'local';
cfg.gateway.bind = 'lan';
cfg.gateway.controlUi = cfg.gateway.controlUi || {};
const baseOrigins = ['http://127.0.0.1:18789','http://localhost:18789','http://0.0.0.0:18789','http://host.docker.internal:18789'];
let customOrigins = [];
try { const eo = '${OPENCLAW_ALLOWED_ORIGINS:-}'; if (eo) customOrigins = JSON.parse(eo); } catch(e) {}
cfg.gateway.controlUi.allowedOrigins = [...new Set([...baseOrigins, ...customOrigins])];

const token = '${OPENCLAW_GATEWAY_TOKEN:-}';
if (token) cfg.gateway.auth = cfg.gateway.auth || {}, cfg.gateway.auth.token = token;

cfg.skills = cfg.skills || {};
cfg.skills.load = cfg.skills.load || {};
cfg.skills.load.extraDirs = ['/home/node/.agents/skills'];

fs.writeFileSync(path, JSON.stringify(cfg, null, 2));
console.log('--> Config batch update done.');
"
echo "--> Configuration batch update done."

# Cleanup legacy symlinks in ~/.openclaw/skills/ that point outside the skills root.
# These were created by clawhub install run from wrong working directory (~/.openclaw/).
# OpenClaw now rejects such symlinks for security reasons (realpath validation).
if [[ -d "/home/node/.openclaw/skills" ]]; then
    for entry in /home/node/.openclaw/skills/*; do
        [[ -L "${entry}" ]] || continue
        target=$(readlink "${entry}" 2>/dev/null) || continue
        case "${target}" in
            ../*)
                # Relative symlinks pointing outside - check if they resolve outside skills root
                resolved=$(readlink -f "${entry}" 2>/dev/null) || continue
                if [[ "${resolved}" != /home/node/.openclaw/skills/* ]]; then
                    echo "--> Removing legacy symlink: ${entry} -> ${target}"
                    rm -f "${entry}"
                fi
                ;;
        esac
    done
fi

# ------------------------------------------------------------------------------
# 7. Unified Global Tools Directory
#    .global/.local/.agents mounted via named volume
# ------------------------------------------------------------------------------
mkdir -p /home/node/.global
mkdir -p /home/node/.local

# ------------------------------------------------------------------------------
# 8. Execute CMD (drop privileges if root)
#    Ensures all files created by the app belong to 'node' user
# ------------------------------------------------------------------------------
echo "==> Starting OpenClaw..."

if ! run_as_node bash -c 'command -v openclaw' &>/dev/null; then
    echo "ERROR: 'openclaw' command not found in PATH." >&2
    echo "Check if the global tools volume is properly populated." >&2
    exit 1
fi

if ! run_as_node bash -c 'command -v opencode' &>/dev/null; then
    echo "ERROR: 'opencode' command not found in PATH." >&2
    echo "Check if the opencode installation in Dockerfile succeeded." >&2
    exit 1
fi

if [[ "$(id -u)" = "0" ]]; then
    export HOME="/home/node"
    # Use runuser -m to preserve container environment (NODE_COMPILE_CACHE, etc.)
    # Only override PATH and HOME to ensure correct values for the node user.
    exec runuser -u node -m -- env PATH="${NODE_GLOBAL_PATH}:$PATH" "$@"
else
    exec "$@"
fi
