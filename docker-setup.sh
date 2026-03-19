# Hard Check: Ensure we are running in Bash
if [ -z "$BASH_VERSION" ]; then
  echo "Error: This script requires a Bash-compatible shell."
  case "$OSTYPE" in
    msys*|cygwin*|win32*) 
      echo "Recommendation: Please use 'Git Bash' (included with Git for Windows) or another POSIX environment."
      ;;
  esac
  exit 1
fi

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${OPENCLAW_IMAGE:-ghcr.io/hrygo/openclaw-devkit:latest}"

# OS Detection
IS_WINDOWS=false
[[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]] && IS_WINDOWS=true

# Self-Healing: Fix CRLF line endings in docker-entrypoint.sh if on Windows
if [ -f "$ROOT_DIR/docker-entrypoint.sh" ]; then
    if grep -q $'\r' "$ROOT_DIR/docker-entrypoint.sh" 2>/dev/null; then
        echo "Detected CRLF line endings in docker-entrypoint.sh, converting to LF..."
        if command -v sed >/dev/null 2>&1; then
            sed -i 's/\r//g' "$ROOT_DIR/docker-entrypoint.sh"
        else
            tr -d '\r' < "$ROOT_DIR/docker-entrypoint.sh" > "$ROOT_DIR/docker-entrypoint.sh.tmp" && \
            mv "$ROOT_DIR/docker-entrypoint.sh.tmp" "$ROOT_DIR/docker-entrypoint.sh"
        fi
    fi
fi

# COMPOSE_FILE is managed by .env for flexibility
# EXTRA_COMPOSE_FILE still used for on-the-fly mounts
EXTRA_COMPOSE_FILE="$ROOT_DIR/docker-compose.dev.extra.yml"

# ============================================================
# Visual Styling (Whitepaper Grade)
# ============================================================

# ANSI Colors (Calculated for portability)
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
BLUE=$(printf '\033[0;34m')
CYAN=$(printf '\033[0;36m')
BOLD=$(printf '\033[1m')
NC=$(printf '\033[0m') # No Color

# Output Prefixes
INFO="${BLUE}${BOLD}==>${NC}"
SUCCESS="${GREEN}${BOLD}✓${NC}"
WARN="${YELLOW}${BOLD}⚠${NC}"
ERROR="${RED}${BOLD}✖${NC}"

fail() {
  echo "${ERROR}${RED}错误: $*${NC}" >&2
  exit 1
}

warn() {
  echo "${WARN}${YELLOW}警告: $*${NC}" >&2
}

success() {
  echo "${SUCCESS}${GREEN}$*${NC}"
}

info() {
  echo "${INFO} $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少依赖: $1" >&2
    exit 1
  fi
}

is_truthy_value() {
  local raw="${1:-}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    1 | true | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

contains_disallowed_chars() {
  local value="$1"
  [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *$'\t'* ]]
}

validate_mount_path_value() {
  local label="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    fail "$label cannot be empty."
  fi
  if contains_disallowed_chars "$value"; then
    fail "$label contains unsupported control characters."
  fi
  if [[ "$value" =~ [[:space:]] ]]; then
    fail "$label cannot contain whitespace."
  fi
}

validate_named_volume() {
  local value="$1"
  if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    fail "OPENCLAW_HOME_VOLUME must match [A-Za-z0-9][A-Za-z0-9_.-]* when using a named volume."
  fi
}

validate_mount_spec() {
  local mount="$1"
  if contains_disallowed_chars "$mount"; then
    fail "OPENCLAW_EXTRA_MOUNTS entries cannot contain control characters."
  fi
  if [[ ! "$mount" =~ ^[^[:space:],:]+:[^[:space:],:]+(:[^[:space:],:]+)?$ ]]; then
    fail "Invalid mount format '$mount'. Expected source:target[:options] without spaces."
  fi
}

read_config_gateway_token() {
  local config_path="${HOST_OPENCLAW_DIR:-"$HOME/.openclaw"}/openclaw.json"
  if [[ ! -f "$config_path" ]]; then
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$config_path" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
except Exception:
    raise SystemExit(0)

gateway = cfg.get("gateway")
if not isinstance(gateway, dict):
    raise SystemExit(0)
auth = gateway.get("auth")
if not isinstance(auth, dict):
    raise SystemExit(0)
token = auth.get("token")
if isinstance(token, str):
    token = token.strip()
    if token:
        print(token)
PY
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    node - "$config_path" <<'NODE'
const fs = require("node:fs");
const configPath = process.argv[2];
try {
  const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const token = cfg?.gateway?.auth?.token;
  if (typeof token === "string" && token.trim().length > 0) {
    process.stdout.write(token.trim());
  }
} catch {
  // Keep docker-setup resilient when config parsing fails.
}
NODE
  fi
}

# Upsert .env 文件 (借鉴自 docker-setup.sh)
# 保留已有配置，只更新指定变量
upsert_env() {
  local file="$1"
  shift
  # We use a temporary file to avoid partial writes
  local tmp
  if command -v mktemp >/dev/null 2>&1; then
    tmp="$(mktemp)"
  else
    tmp="${file}.tmp.$$"
  fi
  
  local seen=" "

  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      local key="${line%%=*}"
      local found=false
      for k in "$@"; do
        if [ "$key" = "$k" ]; then
          # Evaluate current value of the variable named 'k'
          eval "val=\${$k-}"
          if [ -n "$val" ]; then
            printf '%s=%s\n' "$k" "$val" >>"$tmp"
          else
            # Keep original line if new value is empty
            printf '%s\n' "$line" >>"$tmp"
          fi
          seen="$seen$k "
          found=true
          break
        fi
      done
      if [ "$found" = false ]; then
        printf '%s\n' "$line" >>"$tmp"
      fi
    done <"$file"
  fi

  for k in "$@"; do
    if [[ "$seen" != *" $k "* ]]; then
      eval "val=\${$k-}"
      if [ -n "$val" ]; then
        printf '%s=%s\n' "$k" "$val" >>"$tmp"
      fi
    fi
  done

  mv "$tmp" "$file"
}

# 动态生成额外的 compose 配置
write_extra_compose() {
  local home_volume="$1"
  shift
  local mount
  local gateway_home_mount
  local gateway_config_mount
  local gateway_workspace_mount

  cat >"$EXTRA_COMPOSE_FILE" <<'YAML'
services:
  openclaw-gateway:
    volumes:
YAML

  if [[ -n "$home_volume" ]]; then
    gateway_home_mount="${home_volume}:/home/node"
    gateway_config_mount="${HOST_OPENCLAW_DIR}:/home/node/.openclaw"
    gateway_workspace_mount="${HOST_OPENCLAW_DIR}/workspace:/home/node/.openclaw/workspace"
    validate_mount_spec "$gateway_home_mount"
    validate_mount_spec "$gateway_config_mount"
    validate_mount_spec "$gateway_workspace_mount"
    printf '      - %s\n' "$gateway_home_mount" >>"$EXTRA_COMPOSE_FILE"
    printf '      - %s\n' "$gateway_config_mount" >>"$EXTRA_COMPOSE_FILE"
    printf '      - %s\n' "$gateway_workspace_mount" >>"$EXTRA_COMPOSE_FILE"
  fi

  for mount in "$@"; do
    validate_mount_spec "$mount"
    printf '      - %s\n' "$mount" >>"$EXTRA_COMPOSE_FILE"
  done

  if [[ -n "$home_volume" && "$home_volume" != *"/"* ]]; then
    validate_named_volume "$home_volume"
    cat >>"$EXTRA_COMPOSE_FILE" <<YAML
volumes:
  ${home_volume}:
YAML
  fi
}


# ============================================================
# 参数解析
# ============================================================

INSTALL_BROWSER=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-browser)
      INSTALL_BROWSER=""
      shift
      ;;
    --help|-h)
      cat <<'HELP'
OpenClaw 开发环境 Docker 部署脚本

用法:
  ./docker-setup.sh [选项]

选项:
  --no-browser    跳过浏览器安装（减少约 300MB）
  --help          显示帮助信息

环境变量:
  HOST_OPENCLAW_DIR     宿主机 OpenClaw 配置目录 (默认: ~/.openclaw，直接 bind mount 共享)
  OPENCLAW_EXTRA_MOUNTS   额外挂载点，逗号分隔
                          格式: src:dst[:ro],src2:dst2
  OPENCLAW_HOME_VOLUME    命名卷名称 (可选，用于持久化整个 home)

示例:
  # 基本使用
  ./docker-setup.sh

  # 跳过浏览器安装
  ./docker-setup.sh --no-browser

  # 挂载额外目录
  OPENCLAW_EXTRA_MOUNTS="$HOME/projects:/home/node/projects:rw" ./docker-setup.sh

  # 使用 Java 增强版进行安装
  make install java
HELP
      exit 0
      ;;
    *)
      echo "未知选项: $1" >&2
      exit 1
      ;;
  esac
done

# ============================================================
# 验证依赖
# ============================================================

require_cmd docker
if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose 不可用 (尝试: docker compose version)" >&2
  exit 1
fi

# ============================================================
# 安全检测：宿主机 OpenClaw (提前检测，避免端口/配置冲突)
# ============================================================

_openclaw_host_installed=false
_openclaw_host_running=false

# 检测 CLI 是否存在于 PATH
if command -v openclaw >/dev/null 2>&1; then
    _openclaw_host_installed=true
fi

# 检测 launchd 服务 (macOS CLI 安装)
if [[ "$OSTYPE" == "darwin"* ]] && command -v launchctl >/dev/null 2>&1; then
    if launchctl print gui/$UID/bot.molt.gateway >/dev/null 2>&1; then
        _openclaw_host_running=true
    fi
fi

# 检测 systemd 服务 (Linux CLI 安装，user mode)
if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-active --quiet openclaw-gateway.service 2>/dev/null; then
        _openclaw_host_running=true
    fi
fi

# 检测直接运行进程（兜底：即使没有服务管理器也可能 Gateway 在运行）
if ! $_openclaw_host_running; then
    if pgrep -f "openclaw-gateway" >/dev/null 2>&1; then
        _openclaw_host_running=true
    fi
fi

# ── 输出警告与停止建议 ──────────────────────────────────────────
if $_openclaw_host_installed || $_openclaw_host_running; then
    echo ""
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD}  ⚠️  安全警示：宿主机 OpenClaw 检测到${NC}"
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "容器模式与宿主机模式存在冲突："
    echo ""
    echo -e "  1. ${BOLD}端口冲突${NC}: 两者均监听 18789"
    echo -e "  2. ${BOLD}配置冲突${NC}: bind mount 会覆盖宿主机 ~/.openclaw/ 配置"
    echo -e "  3. ${BOLD}双进程风险${NC}: 同时运行会争夺设备配对和 WebSocket 连接"
    echo ""

    # ── 自动停止 ──────────────────────────────────────────────
    _stopped=false

    # 方式 1: 使用 openclaw CLI (跨平台，会自动选择 launchd/systemd/直接 kill)
    if command -v openclaw >/dev/null 2>&1; then
        echo -e "${INFO}尝试通过 openclaw CLI 停止 Gateway 服务..."
        if openclaw gateway stop >/dev/null 2>&1; then
            echo -e "${SUCCESS}Gateway 服务已通过 openclaw 停止${NC}"
            _stopped=true
        else
            # CLI stop 失败，尝试平台原生工具
            echo -e "${YELLOW}openclaw gateway stop 未成功，尝试平台原生工具...${NC}"

            # 方式 2: macOS launchd
            if [[ "$OSTYPE" == "darwin"* ]] && command -v launchctl >/dev/null 2>&1; then
                if launchctl print gui/$UID/bot.molt.gateway >/dev/null 2>&1; then
                    echo -e "${INFO}检测到 launchd 服务 (bot.molt.gateway)，正在停止..."
                    if launchctl bootout gui/$UID/bot.molt.gateway 2>/dev/null; then
                        echo -e "${SUCCESS}launchd 服务已停止${NC}"
                        _stopped=true
                    fi
                fi
                # macOS App launchd
                if launchctl print gui/$UID/ai.openclaw.mac >/dev/null 2>&1; then
                    echo -e "${INFO}检测到 macOS App launchd 服务 (ai.openclaw.mac)，正在停止..."
                    launchctl bootout gui/$UID/ai.openclaw.mac 2>/dev/null && \
                        echo -e "${SUCCESS}macOS App 服务已停止${NC}" || true
                fi
            fi

            # 方式 3: Linux systemd (user mode)
            if command -v systemctl >/dev/null 2>&1; then
                if systemctl --user is-active --quiet openclaw-gateway.service 2>/dev/null; then
                    echo -e "${INFO}检测到 systemd 服务 (openclaw-gateway.service)，正在停止..."
                    if systemctl --user stop openclaw-gateway.service 2>/dev/null; then
                        echo -e "${SUCCESS}systemd 服务已停止${NC}"
                        _stopped=true
                    fi
                fi
            fi
        fi
    fi

    # 方式 4: 兜底 - 直接 kill 进程
    if ! $_stopped; then
        _gateway_pids=$(pgrep -f "openclaw-gateway" 2>/dev/null || true)
        if [[ -n "$_gateway_pids" ]]; then
            echo -e "${YELLOW}正在强制终止残留进程...${NC}"
            for _pid in $_gateway_pids; do
                echo -e "${INFO}  kill TERM PID $_pid"
                kill -TERM "$_pid" 2>/dev/null || true
            done
            sleep 2
            # 检查是否还有残留
            _remaining=$(pgrep -f "openclaw-gateway" 2>/dev/null || true)
            if [[ -n "$_remaining" ]]; then
                echo -e "${YELLOW}  进程未响应 SIGTERM，发送 SIGKILL...${NC}"
                for _pid in $_remaining; do
                    kill -KILL "$_pid" 2>/dev/null || true
                done
            fi
            echo -e "${SUCCESS}残留进程已终止${NC}"
            _stopped=true
        fi
    fi

    if $_stopped; then
        echo -e "${SUCCESS}宿主机 OpenClaw 已全部停止${NC}"
    else
        echo -e "${YELLOW}未能自动停止宿主机 OpenClaw，请手动处理${NC}"
    fi
    echo ""

    # ── 卸载指南 ──────────────────────────────────────────────
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  🔧 宿主机 OpenClaw 卸载指南${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${BOLD}推荐：使用官方卸载命令（最彻底，自动清理所有资源）${NC}"
    echo -e "  ${BOLD}npx -y openclaw uninstall --all --yes --non-interactive${NC}"
    echo ""
    echo -e "${BOLD}分步卸载：${NC}"
    echo ""

    if $_openclaw_host_running; then
        echo -e "${BOLD}Step 1 - 停止服务${NC}"
        echo -e "  macOS (launchd):   ${BOLD}launchctl bootout gui/\$UID/bot.molt.gateway${NC}"
        echo -e "  macOS (App):       ${BOLD}launchctl bootout gui/\$UID/ai.openclaw.mac${NC}"
        echo -e "  Linux (systemd):   ${BOLD}systemctl --user stop openclaw-gateway.service${NC}"
        echo -e "  直接进程:          ${BOLD}pkill -f openclaw-gateway${NC}"
        echo ""
    fi

    echo -e "${BOLD}Step 2 - 卸载 CLI${NC}"
    echo -e "  npm:  ${BOLD}npm uninstall -g openclaw${NC}"
    echo -e "  pnpm: ${BOLD}pnpm remove -g openclaw${NC}"
    echo -e "  bun:  ${BOLD}bun remove -g openclaw${NC}"
    echo ""

    echo -e "${BOLD}Step 3 - 清理残留服务文件（如有）${NC}"
    echo -e "  macOS (CLI plist):     ${BOLD}rm -f ~/Library/LaunchAgents/bot.molt.gateway.plist${NC}"
    echo -e "  macOS (App plist):     ${BOLD}rm -f ~/Library/LaunchAgents/ai.openclaw.mac.plist${NC}"
    echo -e "  Linux (systemd unit):  ${BOLD}rm -f ~/.config/systemd/user/openclaw-gateway.service${NC}"
    echo -e "  Linux (reload):        ${BOLD}systemctl --user daemon-reload${NC}"
    echo ""

    echo -e "${BOLD}Step 4 - 清理配置与数据（按需）${NC}"
    echo -e "  配置目录:  ${BOLD}rm -rf ~/.openclaw${NC}"
    echo -e "  npm 全局包: ${BOLD}npm list -g openclaw --depth=0${NC} (确认是否有残留)"
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
fi

# ============================================================
# 配置变量
# ============================================================

HOME_VOLUME_NAME="${OPENCLAW_HOME_VOLUME:-}"
RAW_EXTRA_MOUNTS="${OPENCLAW_EXTRA_MOUNTS:-}"

# Initialize variables with defaults (handled before tilde expansion)
HOST_OPENCLAW_DIR="${HOST_OPENCLAW_DIR:-$HOME/.openclaw}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_BRIDGE_PORT="${OPENCLAW_BRIDGE_PORT:-18790}"

# Handle tilde expansion (POSIX compliant)
case "$HOST_OPENCLAW_DIR" in
    \~*) HOST_OPENCLAW_DIR="$HOME${HOST_OPENCLAW_DIR#\~}" ;;
esac

# 验证路径
validate_mount_path_value "HOST_OPENCLAW_DIR" "$HOST_OPENCLAW_DIR"
if [[ -n "$HOME_VOLUME_NAME" ]]; then
  if [[ "$HOME_VOLUME_NAME" == *"/"* ]]; then
    validate_mount_path_value "OPENCLAW_HOME_VOLUME" "$HOME_VOLUME_NAME"
  else
    validate_named_volume "$HOME_VOLUME_NAME"
  fi
fi
if contains_disallowed_chars "$RAW_EXTRA_MOUNTS"; then
  fail "OPENCLAW_EXTRA_MOUNTS cannot contain control characters."
fi

OPENCLAW_SKIP_BUILD="${OPENCLAW_SKIP_BUILD:-true}"  # 默认使用极速模式 (跳过构建)
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}" # 默认编排文件
export OPENCLAW_IMAGE="$IMAGE_NAME"
# COMPOSE_FILE logic handled via .env upsert

# ============================================================
# 创建目录 (借鉴 docker-setup.sh 的完整目录树)
# ============================================================

# 检查并修复权限：如果目录已存在且属于其他用户，尝试自动修复
repair_host_permissions() {
    local dir="$1"
    if [[ "$IS_WINDOWS" == "true" ]]; then
        return 0  # Skip on Windows host
    fi
    if [[ -d "$dir" ]]; then
        # 兼容 Linux (stat -c) 和 macOS (stat -f)
        local dir_owner
        dir_owner=$(stat -c '%u' "$dir" 2>/dev/null || stat -f '%u' "$dir" 2>/dev/null || echo "0")

        if [[ "$dir_owner" != "$(id -u)" ]]; then
            echo "  --> 正在优化宿主机目录 $dir 的访问策略 (当前所有者 UID: $dir_owner)..."

            # 方案1: 尝试用 docker run 修复（需要 docker 权限）
            if docker info >/dev/null 2>&1; then
                # 使用当前环境的镜像修复权限（如果已存在）
                local repair_image="alpine"
                if docker images alpine --format '{{.Repository}}' 2>/dev/null | grep -q alpine || \
                   docker pull "$repair_image" >/dev/null 2>&1; then
                    docker run --rm -v "$dir:/target" "$repair_image" \
                        chown -R "$(id -u):$(id -g)" /target 2>/dev/null && \
                        echo "  --> 权限已通过 Docker 修复" && return 0
                fi
            fi

            # 方案2: 尝试直接 chown（当前用户如果是文件所有者）
            if chown -R "$(id -u):$(id -g)" "$dir" 2>/dev/null; then
                echo "  --> 权限已修复" && return 0
            fi

            # 方案3: 均失败，提示用户
            fail "无法自动修复目录 $dir 的权限。\n请手动运行: sudo chown -R $(id -u):$(id -g) $dir"
        fi
    fi
}

# 先检查并修复权限 (使用新架构的 HOST_OPENCLAW_DIR)
repair_host_permissions "${HOST_OPENCLAW_DIR:-$HOME/.openclaw}"
repair_host_permissions "$HOME/.claude"
repair_host_permissions "$HOME/.notebooklm"
repair_host_permissions "$HOME/.agents/skills"

# 创建配置目录（仅首次使用——存量用户已有 ~/.openclaw，直接复用）
mkdir -p "${HOST_OPENCLAW_DIR:-$HOME/.openclaw}"
# Seed 子目录：确保 bind mount 目标存在（Dokcer Desktop/Windows 容器内无法创建宿主机子目录）
mkdir -p "${HOST_OPENCLAW_DIR:-$HOME/.openclaw}/identity"
mkdir -p "${HOST_OPENCLAW_DIR:-$HOME/.openclaw}/agents/main/agent"
mkdir -p "${HOST_OPENCLAW_DIR:-$HOME/.openclaw}/agents/main/sessions"
mkdir -p "${HOST_OPENCLAW_DIR:-$HOME/.openclaw}/agents/codex/agent"
mkdir -p "${HOST_OPENCLAW_DIR:-$HOME/.openclaw}/agents/codex/sessions"

# 优雅迁移 Git 身份：如果发现宿主机有热备用的 Gitconfig，自动推入配置目录
if [[ -f "$HOME/.gitconfig-hotplex" ]]; then
  cp "$HOME/.gitconfig-hotplex" "${HOST_OPENCLAW_DIR:-$HOME/.openclaw}/.gitconfig"
fi

# ============================================================
# 生成 Gateway Token (复用已有配置)
# ============================================================

if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  EXISTING_CONFIG_TOKEN="$(read_config_gateway_token || true)"
  if [[ -n "$EXISTING_CONFIG_TOKEN" ]]; then
    OPENCLAW_GATEWAY_TOKEN="$EXISTING_CONFIG_TOKEN"
    info "复用配置文件中的 Gateway Token: ${CYAN}${HOST_OPENCLAW_DIR}/openclaw.json${NC}"
  elif command -v openssl >/dev/null 2>&1; then
    OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32)"
  else
    OPENCLAW_GATEWAY_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
  fi
fi
export OPENCLAW_GATEWAY_TOKEN

# ============================================================
# 构建镜像
# ============================================================

info "检查开发环境镜像: ${CYAN}$IMAGE_NAME${NC}"
if is_truthy_value "${OPENCLAW_SKIP_BUILD:-}"; then
  # 极速模式：尝试拉取镜像
  if ! docker inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    info "正在拉取镜像: ${BOLD}$IMAGE_NAME${NC}..."
    docker pull "$IMAGE_NAME" || warn "无法拉取镜像，请检查网络或执行 'make build' 手动构建。"
  fi
else
  # 本地构建模式：验证镜像是否存在
  if ! docker inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    error "未找到镜像 ${BOLD}$IMAGE_NAME${NC}。\n提示: 本地开发模式下，请使用 ${BOLD}make build${NC} 构建镜像。\n原脚本中的内置构建逻辑已移除，以符合 DRY 原则（统一由 Makefile 管理）。"
  fi
fi

# ============================================================
# 生成额外的 compose 配置 (如果有 HOME_VOLUME 或 EXTRA_MOUNTS)
# ============================================================

VALID_MOUNTS=()
if [[ -n "$RAW_EXTRA_MOUNTS" ]]; then
  IFS=',' read -r -a mounts <<<"$RAW_EXTRA_MOUNTS"
  for mount in "${mounts[@]}"; do
    mount="${mount#"${mount%%[![:space:]]*}"}"
    mount="${mount%"${mount##*[![:space:]]}"}"
    if [[ -n "$mount" ]]; then
      VALID_MOUNTS+=("$mount")
    fi
  done
fi

# 清理旧的 extra compose 文件
rm -f "$EXTRA_COMPOSE_FILE"

if [[ -n "$HOME_VOLUME_NAME" || ${#VALID_MOUNTS[@]} -gt 0 ]]; then
  echo ""
  echo "==> 生成额外挂载配置"
  if [[ ${#VALID_MOUNTS[@]} -gt 0 ]]; then
    write_extra_compose "$HOME_VOLUME_NAME" "${VALID_MOUNTS[@]}"
  else
    write_extra_compose "$HOME_VOLUME_NAME"
  fi
  echo "已生成: $EXTRA_COMPOSE_FILE"
fi

# ============================================================
# 更新 .env 文件 (使用 upsert 保留已有配置)
# ============================================================

ENV_FILE="$ROOT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  info "初始化环境配置文件: ${CYAN}.env${NC} (从模板复制)"
  cp "$ROOT_DIR/.env.example" "$ENV_FILE"
fi

info "同步环境变量文件: ${CYAN}$ENV_FILE${NC}"
# Use host paths for .env (required for docker-compose volume mounting)
# The application inside will still use the internal paths via compose environment overrides.

# 根据平台自动设置 HOST_CLAWHUB_DIR (覆盖 .env.example 的 macOS 默认值)
if [[ "$IS_WINDOWS" == "true" ]]; then
  export HOST_CLAWHUB_DIR="$(cygpath -u "$APPDATA")/clawhub"
elif [[ "$IS_MACOS" == "true" ]]; then
  export HOST_CLAWHUB_DIR="${HOME}/Library/Application Support/clawhub"
else
  # Linux 及 WSL 默认路径
  export HOST_CLAWHUB_DIR="${HOME}/.config/clawhub"
fi

upsert_env "$ENV_FILE" \
  HOST_OPENCLAW_DIR \
  HOST_CLAWHUB_DIR \
  OPENCLAW_GATEWAY_PORT \
  OPENCLAW_BRIDGE_PORT \
  OPENCLAW_GATEWAY_TOKEN \
  OPENCLAW_IMAGE \
  OPENCLAW_EXTRA_MOUNTS \
  OPENCLAW_HOME_VOLUME \
  HTTP_PROXY \
  HTTPS_PROXY \
  NO_PROXY \
  OPENCLAW_SKIP_BUILD \
  COMPOSE_FILE \
  GIT_USER_NAME \
  GIT_USER_EMAIL
success "环境变量同步完成"

# ============================================================
# 修复权限 (借鉴 docker-setup.sh 的 -xdev 方式)
# ============================================================

echo ""
# 修复数据目录权限
if [[ "$IS_WINDOWS" == "false" ]]; then
  # Use -xdev to restrict chown to the config-dir mount only
  # 使用 root 用户修复权限
  docker compose run --rm --user root --entrypoint sh openclaw-gateway -c \
    'find /home/node/.openclaw -xdev -exec chown node:node {} + 2>/dev/null || true'
fi

# ============================================================
# 配置 Gateway
# ============================================================

echo ""
info "正在调度 Docker 引擎准备服务环境..."
# 仅拉取/准备，不启动，遵循 "Install-only" 策略
# docker compose up -d openclaw-gateway
docker compose pull openclaw-gateway >/dev/null 2>&1 || true

# 清理一次性的 init 容器
docker rm openclaw-init >/dev/null 2>&1 || true

# ============================================================
# 完成提示
# ============================================================

COMPOSE_HINT="docker compose"
if [[ -f "$EXTRA_COMPOSE_FILE" ]]; then
  COMPOSE_HINT+=" -f ${EXTRA_COMPOSE_FILE}"
fi

# ============================================================
# 安全提示：宿主机 OpenClaw 配置共享
# ============================================================

HOST_OPENCLAW_RUNNING=false
if command -v openclaw &>/dev/null && pgrep -x openclaw &>/dev/null; then
    HOST_OPENCLAW_RUNNING=true
fi

if [[ "$HOST_OPENCLAW_RUNNING" == "true" ]]; then
cat <<HOST_WARN

${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}
${YELLOW}  ⚠️  宿主机 OpenClaw 检测到${NC}
${YELLOW}═══════════════════════════════════════════════════════════════════════════════${NC}

配置目录 ${HOST_OPENCLAW_DIR}  同时被宿主机和容器使用。
Gateway 绑定 LAN（gateway.bind=lan）使容器内 Gateway 监听所有网卡。

${RED}风险:${NC}
  → 同一局域网的设备可能访问到你的 Gateway（受 token 保护）
  → 如果在宿主机上直接运行 openclaw 命令，它会读写容器的同一份配置，导致冲突

${GREEN}建议:${NC}
  → ${BOLD}pkill openclaw${NC}   # 先停止宿主机进程，只用容器版
  → 容器 Gateway 通过 ${BOLD}make dashboard${NC} 访问，不要在宿主机直接运行 openclaw

HOST_WARN
fi

cat <<END

${BLUE}${BOLD}============================================================${NC}
  ${GREEN}${BOLD}OpenClaw 环境初始化准备就绪${NC}
${BLUE}${BOLD}============================================================${NC}

配置目录:
  ${BOLD}${HOST_OPENCLAW_DIR}${NC}

${BOLD}下一步 (Next Steps):${NC}
  1. 运行配置引导:  ${BOLD}make onboard${NC}
  2. 启动核心服务:  ${BOLD}make up${NC}

包含的开发工具:
  ${SUCCESS}Node.js 22 + pnpm + Bun
  ${SUCCESS}Python 3 + Office 自动化套件
  ${SUCCESS}Go & JDK 21 (根据版本选择)
  ${SUCCESS}Chromium/Playwright & Pandoc & LaTeX

END
