#!/usr/bin/env bash
set -e

# ==============================================================================
# OpenClaw Docker Entrypoint
# Handles permission fixes, config seeding, Git identity, PIP tools, and
# privilege drop. Optimized for DevKit development environments.
#
# Performance optimizations:
# - Smart detection: only fix permissions on bind mounts when empty/first-time
# - One-time surgery + one-time doctor (gateway manages config afterwards)
# - Batch operations: single chown for all directories
# ==============================================================================

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"
SEED_DIR="/home/node/.openclaw-seed"
INIT_FLAG="${CONFIG_DIR}/.entrypoint_initialized"
SURGERY_FLAG="${CONFIG_DIR}/.path_surgery_complete"

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
# Workspace Path Overlap Detection
#    Validates that OPENCLAW_WORKSPACE_DIR does NOT overlap with the home volume
#    mount point. If workspace is a subdirectory of ~/.openclaw-in-docker, the
#    bind mount would shadow the named volume at that path, causing data loss.
# ------------------------------------------------------------------------------
_validate_workspace_path() {
    local workspace_host_dir="${OPENCLAW_WORKSPACE_DIR:-}"
    local home_host_dir="${HOME:-${USERPROFILE:-}}/.openclaw-in-docker"

    if [[ -z "${workspace_host_dir}" ]]; then
        return 0
    fi

    # Normalize paths for comparison
    local norm_workspace norm_home
    norm_workspace=$(realpath "${workspace_host_dir}" 2>/dev/null || echo "${workspace_host_dir}")
    norm_home=$(realpath "${home_host_dir}" 2>/dev/null || echo "${home_host_dir}")

    # Check if workspace is inside or equals the home directory
    if [[ "${norm_workspace}" == "${norm_home}" ]]; then
        echo "ERROR: OPENCLAW_WORKSPACE_DIR cannot be the same as the home volume root (${home_host_dir})." >&2
        echo "       Please set OPENCLAW_WORKSPACE_DIR to a path OUTSIDE ~/.openclaw-in-docker." >&2
        return 1
    fi

    case "${norm_workspace}" in
        "${norm_home}"/*)
            echo "ERROR: OPENCLAW_WORKSPACE_DIR must NOT be inside ~/.openclaw-in-docker." >&2
            echo "       Current: ${workspace_host_dir}" >&2
            echo "       The workspace bind mount would shadow the named volume at that path." >&2
            echo "       Please set OPENCLAW_WORKSPACE_DIR to a path OUTSIDE ~/.openclaw-in-docker." >&2
            return 1
            ;;
    esac

    return 0
}

# ------------------------------------------------------------------------------
# 0. Cleanup stale temporary files from previous runs
# ------------------------------------------------------------------------------
find "${CONFIG_DIR}" -name "*.tmp" -type f -delete 2>/dev/null || true
find "${CONFIG_DIR}" -name "*.bak" -type f -delete 2>/dev/null || true

# Validate workspace path before any mount operations
if ! _validate_workspace_path; then
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. Smart Permission Fix (only when needed)
#    - Named volumes: always fix (may be owned by root from previous runs)
#    - Bind mounts: only fix if empty or first-time (has flag file)
#    - Batch operation: single chown for all targets
# ------------------------------------------------------------------------------
if [[ "$(id -u)" = "0" ]]; then
    # Check if we've already initialized (skip redundant fixes)
    if [[ -f "${INIT_FLAG}" ]]; then
        echo "--> Permissions already initialized, skipping chown..."
    else
        echo "--> Running one-time permission initialization..."

        # Define all directories that need fixing
        # Named volumes (always need fixing): .global, .local, go, .cache
        # Bind mounts (only if empty): .openclaw, .notebooklm, .claude, .agents
        TARGET_DIRS=(
            "/home/node/.global"
            "/home/node/.local"
            "/home/node/go"
            "/home/node/.cache/go-build"
            "/home/node/.openclaw"
            "/home/node/.notebooklm"
            "/home/node/.claude"
            "/home/node/.agents"
        )

        # Batch chown - single recursive operation for all existing directories
        for dir in "${TARGET_DIRS[@]}"; do
            if [[ -d "${dir}" ]]; then
                # For bind mounts (.openclaw, .notebooklm, .claude), only chown if empty
                case "${dir}" in
                    /home/node/.openclaw|/home/node/.notebooklm|/home/node/.claude|/home/node/.agents)
                        # Only chown if directory is empty or has no proper owner
                        if [[ -z "$(ls -A "${dir}" 2>/dev/null)" ]] || \
                           [[ "$(stat -c '%u' "${dir}" 2>/dev/null)" != "1000" ]]; then
                            chown -R node:node "${dir}" 2>/dev/null || true
                        fi
                        ;;
                    *)
                        # Named volumes: always fix ownership
                        chown -R node:node "${dir}" 2>/dev/null || true
                        ;;
                esac
            fi
        done

        # Seed directory for initial configuration
        if [[ -d "${SEED_DIR}" ]]; then
            chown -R node:node "${SEED_DIR}" 2>/dev/null || true
        fi

        # Mark as initialized to skip on subsequent runs
        touch "${INIT_FLAG}"
        echo "--> Permission initialization complete."
    fi
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

                fs.writeFileSync(path, JSON.stringify(config, null, 2));
                console.log("--> OpenClaw configuration surgically optimized for DevKit.");
            } catch (e) {
                console.error("Warning: Configuration surgery failed: " + e.message);
            }
        ' || true

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
    # No config file - fresh init
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
# 4. Claude Code Embedded Skills
#    Re-injects skills from staging layer into the live mount point
# ------------------------------------------------------------------------------
CLAUDE_DIR="/home/node/.claude"
CLAUDE_SEED="/opt/claude_seed"
if [[ -d "${CLAUDE_SEED}" ]]; then
    echo "--> Verifying Claude embedded skills integrity..."
    run_as_node mkdir -p "${CLAUDE_DIR}"
    # Copy missing/updated skills (-n to not overwrite user edits)
    run_as_node cp -Rn "${CLAUDE_SEED}"/* "${CLAUDE_DIR}/" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 5. NotebookLM CLI
# Ensure symlink for config directory (CLI looks in /root/.notebooklm)
# ------------------------------------------------------------------------------
if [[ -d "/home/node/.notebooklm" ]] && [[ ! -d "/root/.notebooklm" ]]; then
    ln -sf /home/node/.notebooklm /root/.notebooklm
    echo "--> Linked /root/.notebooklm -> /home/node/.notebooklm"
fi

# ------------------------------------------------------------------------------
# 6. Git Identity Injection
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
# 7. Ensure Gateway Configuration
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
# 8. Unified Global Tools Directory
#    Pre-configured in Dockerfile, ensure symlink exists at runtime
# ------------------------------------------------------------------------------
mkdir -p /home/node/.global
mkdir -p /home/node/.local
mkdir -p /home/node/.agents
if [[ -d "/home/node/.global/bin" ]] && [[ ! -L "/usr/local/bin/global" ]]; then
    ln -sf /home/node/.global/bin /usr/local/bin/global
fi

# ------------------------------------------------------------------------------
# 10. Execute CMD (drop privileges if root)
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
    # Use runuser to correctly preserve arguments and handle PATH
    exec runuser -u node -m -- env PATH="${NODE_GLOBAL_PATH}:$PATH" "$@"
else
    exec "$@"
fi
