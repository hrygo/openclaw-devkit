#!/usr/bin/env bash
# OpenClaw 开发环境 Docker 部署脚本
#
# 用法:
#   ./docker-dev-setup.sh [选项]
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
IMAGE_NAME="${OPENCLAW_IMAGE:-openclaw:dev}"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
DEV_COMPOSE_FILE="$ROOT_DIR/docker-compose.dev.yml"
EXTRA_COMPOSE_FILE="$ROOT_DIR/docker-compose.dev.extra.yml"

# ============================================================
# 工具函数 (借鉴自 docker-setup.sh)
# ============================================================

fail() {
  echo "ERROR: $*" >&2
  exit 1
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
  ./docker-dev-setup.sh [选项]

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
  ./docker-dev-setup.sh

  # 跳过浏览器安装
  ./docker-dev-setup.sh --no-browser

  # 挂载额外目录
  OPENCLAW_EXTRA_MOUNTS="$HOME/projects:/home/node/projects:rw" ./docker-dev-setup.sh

  # 使用命名卷持久化 home
  OPENCLAW_HOME_VOLUME=openclaw-home ./docker-dev-setup.sh
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
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_BRIDGE_PORT="${OPENCLAW_BRIDGE_PORT:-18790}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"

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

# 导出变量供 docker compose 使用
export OPENCLAW_CONFIG_DIR
export OPENCLAW_WORKSPACE_DIR
export OPENCLAW_GATEWAY_PORT
export OPENCLAW_BRIDGE_PORT
export OPENCLAW_GATEWAY_BIND
export OPENCLAW_IMAGE="$IMAGE_NAME"

# ============================================================
# 创建目录 (借鉴 docker-setup.sh 的完整目录树)
# ============================================================

mkdir -p "$OPENCLAW_CONFIG_DIR"
mkdir -p "$OPENCLAW_WORKSPACE_DIR"
# Seed directory tree eagerly so bind mounts work even on Docker Desktop/Windows
# where the container (even as root) cannot create new host subdirectories.
mkdir -p "$OPENCLAW_CONFIG_DIR/identity"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/main/agent"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/main/sessions"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/codex/agent"
mkdir -p "$OPENCLAW_CONFIG_DIR/agents/codex/sessions"

# ============================================================
# 生成 Gateway Token (复用已有配置)
# ============================================================

if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  EXISTING_CONFIG_TOKEN="$(read_config_gateway_token || true)"
  if [[ -n "$EXISTING_CONFIG_TOKEN" ]]; then
    OPENCLAW_GATEWAY_TOKEN="$EXISTING_CONFIG_TOKEN"
    echo "复用配置文件中的 Gateway Token: $OPENCLAW_CONFIG_DIR/openclaw.json"
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

echo "==> 构建开发环境镜像: $IMAGE_NAME"
if [[ ! -f "$ROOT_DIR/.openclaw_src/package.json" ]]; then
  echo ""
  echo "❌ 错误: 在 .openclaw_src 目录中未找到项目源码 (package.json)。"
  echo "提示: 如果您是首次克隆本项目，请先运行以下命令拉取源码："
  echo ""
  echo "    make update"
  echo ""
  exit 1
fi

docker build \
  -t "$IMAGE_NAME" \
  -f "$ROOT_DIR/Dockerfile.dev" \
  --build-arg "INSTALL_BROWSER=${INSTALL_BROWSER}" \
  --build-arg "HTTP_PROXY=${HTTP_PROXY:-}" \
  --build-arg "HTTPS_PROXY=${HTTPS_PROXY:-}" \
  "$ROOT_DIR/.openclaw_src"

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
echo ""
echo "==> 更新环境变量文件"
upsert_env "$ENV_FILE" \
  OPENCLAW_CONFIG_DIR \
  OPENCLAW_WORKSPACE_DIR \
  OPENCLAW_GATEWAY_PORT \
  OPENCLAW_BRIDGE_PORT \
  OPENCLAW_GATEWAY_BIND \
  OPENCLAW_GATEWAY_TOKEN \
  OPENCLAW_IMAGE \
  OPENCLAW_EXTRA_MOUNTS \
  OPENCLAW_HOME_VOLUME
echo "已更新: $ENV_FILE"

# ============================================================
# 修复权限 (借鉴 docker-setup.sh 的 -xdev 方式)
# ============================================================

echo ""
# 修复数据目录权限
# Use -xdev to restrict chown to the config-dir mount only
# 使用 root 用户修复权限，但限制在 .openclaw 目录内
docker compose -f "$DEV_COMPOSE_FILE" run --rm --user root --entrypoint sh openclaw-cli -c \
  'find /home/node/.openclaw -xdev -exec chown node:node {} + 2>/dev/null || true; \
   [ -d /home/node/.openclaw/workspace/.openclaw ] && chown -R node:node /home/node/.openclaw/workspace/.openclaw || true'

# ============================================================
# 辅助函数：运行 CLI 命令
# ============================================================

run_cli() {
  docker compose -f "$DEV_COMPOSE_FILE" run --rm --entrypoint "" openclaw-cli node dist/index.js "$@"
}

# ============================================================
# 配置 Gateway
# ============================================================

echo ""
echo "==> 配置 Gateway"
echo "Docker 开发环境配置:"
echo "  Gateway 模式: local"
echo "  绑定模式: $OPENCLAW_GATEWAY_BIND"
echo "  Token: $OPENCLAW_GATEWAY_TOKEN"
echo ""
run_cli config set gateway.mode local >/dev/null && echo "✓ gateway.mode = local"
run_cli config set gateway.bind "$OPENCLAW_GATEWAY_BIND" >/dev/null && echo "✓ gateway.bind = $OPENCLAW_GATEWAY_BIND"

# ============================================================
# 启动 Gateway
# ============================================================

echo ""
echo "==> 启动 Gateway"
docker compose -f "$DEV_COMPOSE_FILE" up -d openclaw-gateway

# ============================================================
# 完成提示
# ============================================================

COMPOSE_HINT="docker compose -f ${DEV_COMPOSE_FILE}"
if [[ -f "$EXTRA_COMPOSE_FILE" ]]; then
  COMPOSE_HINT+=" -f ${EXTRA_COMPOSE_FILE}"
fi

cat <<END

============================================================
  OpenClaw 开发环境已启动
============================================================

访问地址:
  http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}/

Gateway Token:
  ${OPENCLAW_GATEWAY_TOKEN}

配置目录:
  ${OPENCLAW_CONFIG_DIR}

工作区目录:
  ${OPENCLAW_WORKSPACE_DIR}

常用命令:
  # 查看日志
  ${COMPOSE_HINT} logs -f openclaw-gateway

  # 进入容器 shell
  ${COMPOSE_HINT} exec openclaw-gateway bash

  # 运行 CLI 命令
  ${COMPOSE_HINT} run --rm openclaw-cli --help

  # 健康检查
  ${COMPOSE_HINT} exec openclaw-gateway \\
    node dist/index.js health --token "\${OPENCLAW_GATEWAY_TOKEN}"

  # 停止服务
  ${COMPOSE_HINT} down

包含的开发工具:
  ✓ Node.js 22 + pnpm + Bun
  ✓ Python 3 + pip (含 python-docx, openpyxl, python-pptx)
  ✓ Go (golang-go)
  ✓ Chromium/Playwright (浏览器自动化)
  ✓ Pandoc + LaTeX (文档处理)
  ✓ ripgrep, jq, fd-find, bat, httpie 等现代 CLI 工具
END
