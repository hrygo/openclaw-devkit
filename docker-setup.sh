#!/usr/bin/env bash
# OpenClaw 开发环境 Docker 部署脚本
#
# 用法:
#   ./docker-setup.sh [选项]
#
# 选项:
#   --no-browser    跳过浏览器安装（减少约 300MB）
#   --help          显示帮助信息
#
# 环境变量:
#   OPENCLAW_CONFIG_DIR     配置目录 (默认: ~/.openclaw)
#   OPENCLAW_WORKSPACE_DIR  工作区目录 (默认: ~/.openclaw/workspace)
#   OPENCLAW_EXTRA_MOUNTS   额外挂载点 (格式: src:dst[:ro],src2:dst2)
#   OPENCLAW_HOME_VOLUME    命名卷名称 (可选，用于持久化整个 home)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${OPENCLAW_IMAGE:-openclaw-devkit}"
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
  echo -e "${SUCCESS}${GREEN}$*${NC}"
}

info() {
  echo -e "${INFO} $*"
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
  local config_path="$OPENCLAW_CONFIG_DIR/openclaw.json"
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
  local -a keys=("$@")
  local tmp
  tmp="$(mktemp)"
  local seen=" "

  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      local key="${line%%=*}"
      local replaced=false
      for k in "${keys[@]}"; do
        if [[ "$key" == "$k" ]]; then
          printf '%s=%s\n' "$k" "${!k-}" >>"$tmp"
          seen="$seen$k "
          replaced=true
          break
        fi
      done
      if [[ "$replaced" == false ]]; then
        printf '%s\n' "$line" >>"$tmp"
      fi
    done <"$file"
  fi

  for k in "${keys[@]}"; do
    if [[ "$seen" != *" $k "* ]]; then
      printf '%s=%s\n' "$k" "${!k-}" >>"$tmp"
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
    gateway_config_mount="${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw"
    gateway_workspace_mount="${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace"
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

  cat >>"$EXTRA_COMPOSE_FILE" <<'YAML'
  openclaw-cli:
    volumes:
YAML

  if [[ -n "$home_volume" ]]; then
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

INSTALL_BROWSER=1
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
  OPENCLAW_CONFIG_DIR     配置目录 (默认: ~/.openclaw)
  OPENCLAW_WORKSPACE_DIR  工作区目录 (默认: ~/.openclaw/workspace)
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
# 配置变量
# ============================================================

HOME_VOLUME_NAME="${OPENCLAW_HOME_VOLUME:-}"
RAW_EXTRA_MOUNTS="${OPENCLAW_EXTRA_MOUNTS:-}"

OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$HOME/.openclaw}"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$HOME/.openclaw/workspace}"

# 展开波浪号 Tilde (如果环境是从 .env 以字符串读入 '~' 的话)
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR/#\~/$HOME}"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR/#\~/$HOME}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_BRIDGE_PORT="${OPENCLAW_BRIDGE_PORT:-18790}"

# 验证路径
validate_mount_path_value "OPENCLAW_CONFIG_DIR" "$OPENCLAW_CONFIG_DIR"
validate_mount_path_value "OPENCLAW_WORKSPACE_DIR" "$OPENCLAW_WORKSPACE_DIR"
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
    if [[ -d "$dir" ]]; then
        # 兼容 Linux (stat -c) 和 macOS (stat -f)
        local dir_owner
        dir_owner=$(stat -c '%u' "$dir" 2>/dev/null || stat -f '%u' "$dir" 2>/dev/null || echo "0")

        if [[ "$dir_owner" != "$(id -u)" ]]; then
            echo "  --> 发现目录 $dir 属于其他用户 (UID: $dir_owner)，尝试修复..."

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

# 先检查并修复权限
repair_host_permissions "$OPENCLAW_CONFIG_DIR"

mkdir -p "$OPENCLAW_CONFIG_DIR"
mkdir -p "$OPENCLAW_WORKSPACE_DIR"
# Seed directory tree eagerly so bind mounts work even on Docker Desktop/Windows
# where the container (even as root) cannot create new host subdirectories.
mkdir -p "$OPENCLAW_CONFIG_DIR/identity"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/main/agent"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/main/sessions"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/codex/agent"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/codex/sessions"

# 优雅迁移 Git 身份：如果发现宿主机有热备用的 Gitconfig，自动推入 Seed，规避 docker-compose 的危险空挂载
if [[ -f "$HOME/.gitconfig-hotplex" ]]; then
  cp "$HOME/.gitconfig-hotplex" "$OPENCLAW_CONFIG_DIR/.gitconfig"
fi

# ============================================================
# 生成 Gateway Token (复用已有配置)
# ============================================================

if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  EXISTING_CONFIG_TOKEN="$(read_config_gateway_token || true)"
  if [[ -n "$EXISTING_CONFIG_TOKEN" ]]; then
    OPENCLAW_GATEWAY_TOKEN="$EXISTING_CONFIG_TOKEN"
    info "复用配置文件中的 Gateway Token: ${CYAN}$OPENCLAW_CONFIG_DIR/openclaw.json${NC}"
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
upsert_env "$ENV_FILE" \
  OPENCLAW_CONFIG_DIR \
  OPENCLAW_WORKSPACE_DIR \
  OPENCLAW_GATEWAY_PORT \
  OPENCLAW_BRIDGE_PORT \
  OPENCLAW_GATEWAY_TOKEN \
  OPENCLAW_IMAGE \
  OPENCLAW_EXTRA_MOUNTS \
  OPENCLAW_HOME_VOLUME \
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
# Use -xdev to restrict chown to the config-dir mount only
# 使用 root 用户修复权限，限制由于 openclaw-cli 仅挂载了 .openclaw 且为统一存储池
docker compose run --rm --user root --entrypoint sh openclaw-cli -c \
  'find /home/node/.openclaw -xdev -exec chown node:node {} + 2>/dev/null || true'

# ============================================================
# 辅助函数：运行 CLI 命令
# ============================================================

run_cli() {
  docker compose run --rm --entrypoint "" openclaw-cli node dist/index.js "$@"
}

# ============================================================
# 配置 Gateway
# ============================================================

echo ""
info "部署网络服务..."
docker compose up -d openclaw-gateway

# ============================================================
# 完成提示
# ============================================================

COMPOSE_HINT="docker compose"
if [[ -f "$EXTRA_COMPOSE_FILE" ]]; then
  COMPOSE_HINT+=" -f ${EXTRA_COMPOSE_FILE}"
fi

cat <<END

${BLUE}${BOLD}============================================================${NC}
  ${GREEN}${BOLD}OpenClaw 开发环境已就绪${NC}
${BLUE}${BOLD}============================================================${NC}

访问地址:
  ${CYAN}http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}/${NC}

Gateway Token:
  ${YELLOW}${OPENCLAW_GATEWAY_TOKEN}${NC}

配置目录:
  ${BOLD}${OPENCLAW_CONFIG_DIR}${NC}

常用命令:
  ${INFO}查看实时日志:  ${BOLD}${COMPOSE_HINT} logs -f openclaw-gateway${NC}
  ${INFO}进入内部 Shell: ${BOLD}${COMPOSE_HINT} exec openclaw-gateway bash${NC}
  ${INFO}交互式配置引导:  ${BOLD}make onboard${NC}

包含的开发工具:
  ${SUCCESS}Node.js 22 + pnpm + Bun
  ${SUCCESS}Python 3 + Office 自动化套件
  ${SUCCESS}Go & JDK 21 (根据版本选择)
  ${SUCCESS}Chromium/Playwright & Pandoc & LaTeX


END
