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
# - Incremental permission fix via `find \! -user node` (skip already-correct files)
# - Skip /.global (Dockerfile already sets ownership)
# - Bind mounts: warn only (don't modify host filesystem)
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
# 1. Volume Permission Fix (Optimized: O(n) → O(1) for most startups)
#
# Strategy (following postgres/mysql/redis official image patterns):
#   - Image content:       Skip (Dockerfile already sets correct ownership)
#   - Named volumes:       Incremental fix via `find \! -user node -exec chown`
#   - Bind mounts:         WARN only (don't modify host filesystem)
#   - Extension plugins:   Set to root:0 (required by plugin loader security)
#
# Performance: First run still does full chown; subsequent runs skip in <1s.
# ------------------------------------------------------------------------------
if [[ "$(id -u)" = "0" ]]; then
    echo "--> Checking volume permissions..."

    # Named volume directories: create if missing, then incremental fix
    # Note: /home/node/.global is NOT included - Dockerfile:106 already handles it
    for dir in "/home/node/.claude" "/home/node/.local" "/home/node/.agents" "/home/node/go" "/home/node/.cache" "/home/node/.config"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}"
            # New directory: set ownership directly (no need to traverse)
            chown node:node "${dir}" 2>/dev/null || true
        else
            # Existing directory: only fix files NOT owned by node (incremental)
            # Uses find batching (+) for efficiency - ~10x faster than chown -R
            find "${dir}" \! -user node -exec chown node:node {} + 2>/dev/null || true
        fi
    done

    # /app and compile cache: simple mkdir + chown (usually empty or small)
    for dir in "/app" "/var/tmp/openclaw-compile-cache"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}"
        fi
        chown node:node "${dir}" 2>/dev/null || true
    done

    # Bind mount directories: CHECK ONLY, warn if wrong ownership
    # Per Docker best practices: containers should NOT modify bind mount ownership
    # (that would be modifying the host filesystem, which is a security boundary)
    for dir in "/home/node/.openclaw" "/home/node/.notebooklm"; do
        if [[ -d "${dir}" ]]; then
            owner_uid="$(stat -c '%u' "${dir}" 2>/dev/null)"
            if [[ "${owner_uid}" != "1000" && "${owner_uid}" != "0" ]]; then
                echo "⚠️  WARNING: ${dir} is owned by UID ${owner_uid}, expected 1000 or 0."
                echo "   This may cause permission errors. Fix on host with:"
                echo "   chown -R 1000:1000 <host-path>"
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

    # Fix npm cache permissions for plugin-local installs (runs as root but npm expects node ownership)
    # This prevents EACCES errors when acpx or other plugins try to install dependencies
    if [[ -d "/root/.npm" ]]; then
        echo "--> Fixing npm cache permissions..."
        chown -R 1000:1000 /root/.npm 2>/dev/null || true
        echo "--> npm cache permissions OK."
    fi
fi

# ------------------------------------------------------------------------------
# 1a. Sync Plugin Marketplace Config (Seed-based Architecture)
#
# Architecture:
#   - Host source:   ~/.claude/plugins/known_marketplaces.json (bind mount, RO)
#                    → /home/node/.claude/plugins/.host-marketplaces-seed.json
#   - Container use: /home/node/.claude/plugins/known_marketplaces.json (writable)
#                    Uses container paths: /home/node/.claude/plugins/marketplaces/...
#
# Why not direct bind mount?
#   - Host paths are absolute (/Users/xxx, /home/xxx, C:/Users/xxx)
#   - Container needs /home/node paths
#   - Direct sharing causes path conflicts
#
# Solution:
#   1. Mount host config as READ-ONLY seed file
#   2. Convert paths and write to container's own file
#   3. Auto-sync when host file is updated
# ------------------------------------------------------------------------------
_sync_marketplace_config() {
    local plugins_dir="/home/node/.claude/plugins"
    local seed_file="${plugins_dir}/.host-marketplaces-seed.json"
    local target_file="${plugins_dir}/known_marketplaces.json"
    local marker_file="${plugins_dir}/.seed-synced"

    # Skip if no seed file (host doesn't have plugins configured yet)
    [[ -f "${seed_file}" ]] || return 0

    # Check if sync is needed
    local seed_mtime=$(stat -c %Y "${seed_file}" 2>/dev/null || stat -f %m "${seed_file}" 2>/dev/null || echo 0)
    local last_sync=0
    if [[ -f "${marker_file}" ]]; then
        last_sync=$(cat "${marker_file}" 2>/dev/null || echo 0)
    fi

    # Sync if: first time, or seed file updated
    if [[ ! -f "${target_file}" ]] || [[ "${seed_mtime}" -gt "${last_sync}" ]]; then
        echo "--> Syncing plugin marketplace config from host seed..."

        # Use Python to convert paths
        if command -v python3 >/dev/null 2>&1; then
            python3 "${seed_file}" "${target_file}" <<'PYTHON_EOF'
import sys
import json
import re
import os

def convert_paths(data, host_marketplaces_dir):
    """
    Convert host absolute paths to container paths.

    Examples:
    - /Users/xxx/.claude/plugins/marketplaces/name -> /home/node/.claude/plugins/marketplaces/name
    - /home/xxx/.claude/plugins/marketplaces/name -> /home/node/.claude/plugins/marketplaces/name
    - C:/Users/xxx/.claude/plugins/marketplaces/name -> /home/node/.claude/plugins/marketplaces/name
    """
    if isinstance(data, dict):
        for key, value in list(data.items()):
            if key == "installLocation" and isinstance(value, str):
                # Extract marketplace name from any path format
                # Use raw string with proper escaping for backslash in character class
                match = re.search(r'marketplaces[/\\\\]([^/\\\\]+)(?:[/\\\\]|$)', value)
                if match:
                    marketplace_name = match.group(1)
                    data[key] = f"/home/node/.claude/plugins/marketplaces/{marketplace_name}"

                    # Verify marketplace exists in container (may need to copy from host)
                    container_path = f"/home/node/.claude/plugins/marketplaces/{marketplace_name}"
                    host_path = os.path.join(host_marketplaces_dir, marketplace_name)

                    if not os.path.exists(container_path) and os.path.exists(host_path):
                        # Marketplace directory not in container, copy from host mount
                        print(f"    Copying marketplace: {marketplace_name}")
                        os.makedirs(os.path.dirname(container_path), exist_ok=True)
                        import shutil
                        shutil.copytree(host_path, container_path)

            elif isinstance(value, dict):
                convert_paths(value, host_marketplaces_dir)
    elif isinstance(data, list):
        for item in data:
            convert_paths(item, host_marketplaces_dir)

try:
    seed_file = sys.argv[1]
    target_file = sys.argv[2]

    # Host marketplaces are mounted at /home/node/.claude/plugins/marketplaces-host
    host_marketplaces_dir = "/home/node/.claude/plugins/marketplaces-host"

    with open(seed_file, 'r') as f:
        data = json.load(f)

    convert_paths(data, host_marketplaces_dir)

    # Ensure target directory exists
    os.makedirs(os.path.dirname(target_file), exist_ok=True)

    with open(target_file, 'w') as f:
        json.dump(data, f, indent=2)

    print(f"    ✓ Synced {len(data)} marketplace(s)")
except Exception as e:
    print(f"    ✗ Error syncing marketplace config: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
            local result=$?
            if [[ ${result} -ne 0 ]]; then
                echo "    ✗ Failed to sync marketplace config"
                return 1
            fi

            # Record sync time
            echo "${seed_mtime}" > "${marker_file}"
        else
            echo "    ✗ Python3 not available, cannot sync"
            return 1
        fi
    fi

    # Ensure correct ownership
    if [[ "$(id -u)" = "0" ]]; then
        chown -R node:node "${plugins_dir}" 2>/dev/null || true
    fi
}

# Run sync
_sync_marketplace_config

# ------------------------------------------------------------------------------
# 1b. Sync Image-Managed Extensions into Bind-Mount Volume
#
# Architecture:
#   - Image global:  /home/node/.global/lib/node_modules/@larksuite/openclaw-lark
#                    (installed by Dockerfile RUN; version = OPENCLAW_VERSION)
#   - Volume mount:  /home/node/.openclaw/extensions/openclaw-lark
#                    (bind-mounted from host ~/.openclaw; persists across rebuilds)
#
# Since the bind mount completely shadows any content the image places at
# /home/node/.openclaw, we must actively sync image-builtins into the volume
# on every boot when versions drift.  The marker file encodes the synced
# version so we skip re-sync on subsequent starts.
#
# This handles the "stale bundled SDK" problem: older openclaw-lark versions
# bundled openclaw/plugin-sdk whose import-hashes didn't match the global SDK,
# causing "normalizeAccountId is not a function".  Newer versions (>=2026.3.18)
# dropped the bundle and depend on the external openclaw package instead.
#
# NOTE: @larksuite/openclaw-lark has its own independent version numbering
# (YYYY.M.D format) that does NOT track openclaw's semver with -N suffixes.
# The image always installs @latest; the entrypoint syncs that into the volume.
# ------------------------------------------------------------------------------
_sync_image_extensions() {
    local ext_base="/home/node/.openclaw/extensions"
    local img_nm="/home/node/.global/lib/node_modules"

    # ── openclaw-lark ────────────────────────────────────────────────────────
    local ext_name="openclaw-lark"
    local img_pkg="${img_nm}/@larksuite/${ext_name}"
    local vol_dir="${ext_base}/${ext_name}"
    local marker_dir="${vol_dir}/.synced_from_image"

    # Read versions (empty if not present)
    local img_ver="$(cat "${img_pkg}/package.json" 2>/dev/null | grep '"version"' | head -1 | sed 's/[^0-9.].*//g')"
    local vol_ver=""
    if [[ -f "${vol_dir}/package.json" ]]; then
        vol_ver="$(cat "${vol_dir}/package.json" 2>/dev/null | grep '"version"' | head -1 | sed 's/[^0-9.].*//g')"
    fi

    # Skip if image doesn't have this extension (not a build-time install)
    [[ -n "${img_ver}" && -d "${img_pkg}" ]] || return 0

    # If volume has no extension, or version differs from image, sync
    if [[ ! -d "${vol_dir}" || ( -n "${vol_ver}" && "${vol_ver}" != "${img_ver}" ) ]]; then
        echo "--> Syncing ${ext_name}: image=${img_ver}, volume=${vol_ver:-none}"

        # Backup existing (user-modified) extension
        if [[ -d "${vol_dir}" && "${vol_dir}" != "/" ]]; then
            local bak_dir="${vol_dir}.backup_$(date +%Y%m%d_%H%M%S)"
            echo "--> Backing up old ${ext_name} to ${bak_dir}"
            cp -r "${vol_dir}" "${bak_dir}"
        fi

        # Remove old content (keep parent dir)
        rm -rf "${vol_dir}"/* 2>/dev/null || true

        # Copy from image global (preserving the nested node_modules/@larksuite)
        cp -r "${img_pkg}"/* "${vol_dir}/" 2>/dev/null || true

        # The npm package puts the extension at @larksuite/openclaw-lark, but
        # OpenClaw's plugin loader looks for <name>/index.js.  Reorganise:
        #   @larksuite/openclaw-lark/*  →  openclaw-lark/*
        if [[ -d "${vol_dir}/@larksuite" ]]; then
            for item in "${vol_dir}/@larksuite/${ext_name}"/*; do
                [[ -e "${item}" ]] || continue
                local bn="$(basename "${item}")"
                rm -rf "${vol_dir}/${bn}"
                mv "${item}" "${vol_dir}/"
            done
            rm -rf "${vol_dir}/@larksuite"
        fi

        # Restore ownership (plugin loader requires root-owned for non-bundled plugins)
        chown -R 0:0 "${vol_dir}" 2>/dev/null || true

        # Mark synced version
        echo "${img_ver}" > "${marker_dir}"
        echo "--> ${ext_name} synced to ${img_ver}"
    fi
}
_sync_image_extensions

# ── OpenViking ────────────────────────────────────────────────────────────────
# ov-install runs during image build, but /home/node/.openclaw is bind-mounted
# from host at runtime, shadowing everything the image placed there.
# We stage the artifacts to /app/openviking-staging (not mounted) during build,
# then restore them into the mounted volume on first start.
# ------------------------------------------------------------------------------
_sync_openviking() {
    local staging="/app/openviking-staging"
    local ext_target="/home/node/.openclaw/extensions/openviking"
    local env_target="/home/node/.openclaw/openviking.env"

    # No staging dir means image was built without OpenViking
    [[ -d "${staging}" ]] || return 0

    # Extension already present in volume — skip
    [[ -d "${ext_target}" ]] && return 0

    echo "--> Syncing openviking from image staging..."
    mkdir -p "${ext_target}"
    cp -r "${staging}/extensions/openviking/"* "${ext_target}/" 2>/dev/null || true
    chown -R 0:0 "${ext_target}" 2>/dev/null || true

    # Restore openviking.env if missing
    if [[ ! -f "${env_target}" && -f "${staging}/openviking.env" ]]; then
        cp "${staging}/openviking.env" "${env_target}"
    fi

    echo "--> OpenViking extension synced."
}
_sync_openviking

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

# Create statusline.sh for Claude Code from seed file
# Seed file is bind-mounted from host (read-only), container maintains its own writable copy
STATUSLINE_SEED="/home/node/.claude/statusline.sh.seed"
STATUSLINE_TARGET="/home/node/.claude/statusline.sh"
if [[ -f "${STATUSLINE_SEED}" ]]; then
    if [[ ! -f "${STATUSLINE_TARGET}" ]] || [[ "${STATUSLINE_SEED}" -nt "${STATUSLINE_TARGET}" ]]; then
        echo "--> Syncing statusline.sh from host seed..."
        cp "${STATUSLINE_SEED}" "${STATUSLINE_TARGET}"
        chmod +x "${STATUSLINE_TARGET}"
        if [[ "$(id -u)" = "0" ]]; then
            chown node:node "${STATUSLINE_TARGET}" 2>/dev/null || true
        fi
    fi
elif [[ ! -f "${STATUSLINE_TARGET}" ]]; then
    # Fallback: create basic statusline.sh if seed file doesn't exist
    echo "--> Creating basic statusline.sh (no seed file found)..."
    cat > "${STATUSLINE_TARGET}" << 'EOF'
#!/bin/bash
# Status line script for Claude Code

# Get current directory name
current_dir=$(basename "$PWD")

# Check if in git repo
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    status="[$branch]"
else
    status=""
fi

# Output status line
echo "$current_dir $status"
EOF
    chmod +x "${STATUSLINE_TARGET}"
    if [[ "$(id -u)" = "0" ]]; then
        chown node:node "${STATUSLINE_TARGET}" 2>/dev/null || true
    fi
fi

# Fix plugin hook scripts execution permissions
# Some plugins (like ralph-loop) have hooks that require execute permission
PLUGINS_DIR="/home/node/.claude/plugins"
if [[ -d "${PLUGINS_DIR}" ]]; then
    echo "--> Fixing plugin hook permissions..."
    find "${PLUGINS_DIR}" -type f -name "*-hook.sh" -exec chmod +x {} + 2>/dev/null || true
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

// Clean up stale plugin entries (feishu is now handled by openclaw-lark)
if (cfg.plugins && cfg.plugins.allow) {
    cfg.plugins.allow = cfg.plugins.allow.filter(p => p !== 'feishu');
}
if (cfg.plugins && cfg.plugins.entries && cfg.plugins.entries.feishu) {
    delete cfg.plugins.entries.feishu;
}

// Configure OpenViking plugin based on OPENVIKING_ENABLED environment variable
const openvikingEnabled = '${OPENVIKING_ENABLED:-false}'.toLowerCase() === 'true';
cfg.plugins = cfg.plugins || {};
cfg.plugins.entries = cfg.plugins.entries || {};
cfg.plugins.entries.openviking = cfg.plugins.entries.openviking || {};

// enabled: 每次启动都设置
cfg.plugins.entries.openviking.enabled = openvikingEnabled;

// 首次初始化时设置 config 和 contextEngine
const surgeryFlag = '${SURGERY_FLAG}';
if (!fs.existsSync(surgeryFlag)) {
    cfg.plugins.entries.openviking.config = {
        mode: 'local',
        configPath: '/home/node/.openclaw/openviking/ov.conf',
        port: 1933
    };
    cfg.plugins.slots = cfg.plugins.slots || {};
    cfg.plugins.slots.contextEngine = 'openviking';
    console.log('--> OpenViking config and slots initialized.');
}
console.log('--> OpenViking plugin', openvikingEnabled ? 'enabled' : 'disabled');

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
# ------------------------------------------------------------------------------
# 6a. Generate OpenViking Configuration File from Template
#    Replaces template variables with actual environment variable values
# ------------------------------------------------------------------------------
_generate_openviking_config() {
    local template_file="/app/templates/ov.conf.template"
    local config_dir="/home/node/.openclaw/openviking"
    local config_file="${config_dir}/ov.conf"

    # Skip if template file doesn't exist (not all image variants have OpenViking)
    if [[ ! -f "${template_file}" ]]; then
        echo "--> OpenViking template not found, skipping config generation."
        return 0
    fi

    # Skip if OpenViking is disabled
    if [[ "${OPENVIKING_ENABLED}" != "true" ]]; then
        echo "--> OpenViking is disabled, skipping config generation."
        return 0
    fi

    echo "--> Generating OpenViking configuration file..."

    # Create config directory if it doesn't exist
    if [[ "$(id -u)" = "0" ]]; then
        run_as_node mkdir -p "${config_dir}" 2>/dev/null || true
    else
        mkdir -p "${config_dir}" 2>/dev/null || true
    fi

    # Use Node.js to replace template variables (handles JSON safely)
    # Optimized: only process known template variables, don't scan all environment variables
    run_as_node node <<NODE_EOF
const fs = require('fs');
const configPath = '${config_file}';
const templateFile = '${template_file}';

// Read template file
const template = fs.readFileSync(templateFile, 'utf8');

// Directly use known template variables (much faster than scanning process.env)
const vars = {
    'OPENVIKING_EMBEDDING_PROVIDER': process.env.OPENVIKING_EMBEDDING_PROVIDER || '',
    'OPENVIKING_EMBEDDING_API_KEY': process.env.OPENVIKING_EMBEDDING_API_KEY || '',
    'OPENVIKING_EMBEDDING_MODEL': process.env.OPENVIKING_EMBEDDING_MODEL || '',
    'OPENVIKING_EMBEDDING_API_BASE': process.env.OPENVIKING_EMBEDDING_API_BASE || '',
    'OPENVIKING_EMBEDDING_DIMENSION': process.env.OPENVIKING_EMBEDDING_DIMENSION || '1024',
    'OPENVIKING_EMBEDDING_INPUT': process.env.OPENVIKING_EMBEDDING_INPUT || 'multimodal',
    'OPENVIKING_VLM_PROVIDER': process.env.OPENVIKING_VLM_PROVIDER || '',
    'OPENVIKING_VLM_API_KEY': process.env.OPENVIKING_VLM_API_KEY || '',
    'OPENVIKING_VLM_MODEL': process.env.OPENVIKING_VLM_MODEL || '',
    'OPENVIKING_VLM_API_BASE': process.env.OPENVIKING_VLM_API_BASE || ''
};

// Replace template variables using simple string replacement (faster than regex)
let config = template;
for (const [key, value] of Object.entries(vars)) {
    config = config.split('\${' + key + '}').join(value);
}

// Ensure output directory exists
const dir = require('path').dirname(configPath);
if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true, mode: 0o755 });
}

// Write configuration file
fs.writeFileSync(configPath, config, { mode: 0o600 });
console.log('    ✓ OpenViking configuration written to:', configPath);
NODE_EOF
    if [[ $? -ne 0 ]]; then
        echo "    ✗ Failed to generate OpenViking configuration"
        return 1
    fi

    # Ensure correct ownership
    if [[ "$(id -u)" = "0" ]]; then
        chown -R node:node "${config_dir}" 2>/dev/null || true
    fi

    echo "--> OpenViking configuration generation completed."
}

# ------------------------------------------------------------------------------
# 6b. Write Environment Variables to Node User's Shell Profile
#    Ensures environment variables are available in interactive shell sessions
# ------------------------------------------------------------------------------
_write_env_to_profile() {
    local profile_file="/home/node/.bashrc"
    local env_marker="# === OpenClaw DevKit Environment Variables ==="

    echo "--> Writing environment variables to node user's shell profile..."

    # Remove old environment variable section if exists
    if [[ -f "${profile_file}" ]]; then
        sed -i "/${env_marker}/,/# === End OpenClaw DevKit Environment Variables ===/d" "${profile_file}" 2>/dev/null || true
    fi

    # Create new environment variable section
    {
        echo ""
        echo "${env_marker}"
        echo "# Auto-generated by OpenClaw DevKit entrypoint"
        echo "# These variables are synced from .env and docker-compose.yml"
        echo ""

        # Write important environment variables
        local env_vars=(
            "GITHUB_PERSONAL_ACCESS_TOKEN"
            "GITHUB_TOKEN"
            "ANTHROPIC_AUTH_TOKEN"
            "ANTHROPIC_BASE_URL"
            "HTTP_PROXY"
            "HTTPS_PROXY"
            "NO_PROXY"
            "TZ"
            # OpenViking configuration
            "OPENVIKING_ENABLED"
            "OPENVIKING_EMBEDDING_PROVIDER"
            "OPENVIKING_EMBEDDING_API_KEY"
            "OPENVIKING_EMBEDDING_MODEL"
            "OPENVIKING_EMBEDDING_API_BASE"
            "OPENVIKING_EMBEDDING_DIMENSION"
            "OPENVIKING_EMBEDDING_INPUT"
            "OPENVIKING_VLM_PROVIDER"
            "OPENVIKING_VLM_API_KEY"
            "OPENVIKING_VLM_MODEL"
            "OPENVIKING_VLM_API_BASE"
        )

        for var in "${env_vars[@]}"; do
            if [[ -n "${!var:-}" ]]; then
                # Escape special characters in the value
                local value="${!var}"
                # Use printf to safely escape the value
                printf 'export %s="%s"\n' "${var}" "${value}"
            fi
        done

        echo ""
        echo "# === End OpenClaw DevKit Environment Variables ==="
    } >> "${profile_file}"

    # Ensure correct ownership
    if [[ "$(id -u)" = "0" ]]; then
        chown node:node "${profile_file}" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# 6b. Disable Built-in Feishu Extensions
# ------------------------------------------------------------------------------
# To avoid conflicts with openclaw-lark plugin, we need to disable the built-in
# feishu extensions that ship with OpenClaw. These extensions are re-created
# from the image on every container restart, so we must remove them on each boot.
#
# Affected paths:
#   - /home/node/.global/lib/node_modules/openclaw/dist/extensions/feishu
#   - /home/node/.global/lib/node_modules/@larksuite/openclaw-lark/node_modules/openclaw/dist/extensions/feishu
#   - /home/node/.openclaw/extensions/openclaw-lark/node_modules/openclaw/dist/extensions/feishu
# ------------------------------------------------------------------------------
_disable_builtin_feishu() {
    echo "--> Disabling built-in feishu extensions to avoid conflicts..."

    local feishu_dirs=(
        "/home/node/.global/lib/node_modules/openclaw/dist/extensions/feishu"
        "/home/node/.global/lib/node_modules/@larksuite/openclaw-lark/node_modules/openclaw/dist/extensions/feishu"
        "/home/node/.openclaw/extensions/openclaw-lark/node_modules/openclaw/dist/extensions/feishu"
    )

    for dir in "${feishu_dirs[@]}"; do
        if [[ -d "${dir}" ]]; then
            echo "    Removing: ${dir}"
            rm -rf "${dir}"
        fi
    done

    echo "    ✓ Built-in feishu extensions disabled"
}

# ------------------------------------------------------------------------------
# 6. Configure npm to use node user's cache directory
# ------------------------------------------------------------------------------
# When running as root but executing npm as node user (via runuser), npm may try to use
# /root/.npm cache which causes EACCES errors. We configure npm to use a cache directory
# owned by the node user instead.
# ------------------------------------------------------------------------------
_configure_npm_cache() {
    local npmrc="/home/node/.npmrc"
    local cache_dir="/home/node/.npm-cache"

    echo "--> Configuring npm cache for node user..."

    # Create cache directory if it doesn't exist
    mkdir -p "${cache_dir}" 2>/dev/null || true
    chown -R node:node "${cache_dir}" 2>/dev/null || true

    # Configure npm to use the custom cache directory
    if [[ ! -f "${npmrc}" ]] || ! grep -q "cache\s*=" "${npmrc}" 2>/dev/null; then
        echo "cache=${cache_dir}" > "${npmrc}"
        chown node:node "${npmrc}" 2>/dev/null || true
        echo "--> npm cache configured: ${cache_dir}"
    else
        echo "--> npm cache already configured"
    fi
}

# Disable built-in feishu extensions
_disable_builtin_feishu

# Configure npm cache
_configure_npm_cache

# Generate OpenViking configuration file
_generate_openviking_config

# Write environment variables to profile
_write_env_to_profile

# ------------------------------------------------------------------------------
# 7. Start OpenClaw Gateway
# ------------------------------------------------------------------------------
echo "==> Starting OpenClaw..."

if ! run_as_node bash -c 'command -v openclaw' &>/dev/null; then
    echo "ERROR: 'openclaw' command not found in PATH." >&2
    echo "Check if the global tools volume is properly populated." >&2
    exit 1
fi

if ! run_as_node bash -c 'command -v opencode' &>/dev/null; then
    echo "⚠️  WARNING: 'opencode' command not found in PATH." >&2
    echo "   AI coding tools may not have been installed in this image variant." >&2
    echo "   Continuing startup without opencode..." >&2
fi

if [[ "$(id -u)" = "0" ]]; then
    # Use runuser -m to preserve all container environment variables
    # (NODE_COMPILE_CACHE, GITHUB_TOKEN, ANTHROPIC_AUTH_TOKEN, etc.)
    # The -m flag makes runuser preserve the environment, similar to sudo -E
    # PATH is set correctly by Docker already (from Dockerfile ENV + compose env_file)
    # IMPORTANT: Set HOME=/home/node to ensure npm uses correct cache directory
    exec env HOME=/home/node runuser -u node -m -- "$@"
else
    exec "$@"
fi
