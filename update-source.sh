#!/usr/bin/env bash
# OpenClaw 源码更新脚本
# 从 GitHub Releases 下载最新版本源码
# 支持镜像版本管理 (最多保留 5 个版本)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/.openclaw_src"
REPO="openclaw/openclaw"
IMAGE_NAME="openclaw"
MAX_IMAGES=5

# 临时文件跟踪 (用于 trap 清理)
TMP_FILE=""
TMP_DIR=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "${GREEN}==>${NC} $*" >&2; }
warn() { echo -e "${YELLOW}WARNING:${NC} $*" >&2; }
error() { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }

# 清理临时文件
cleanup() {
  [[ -n "$TMP_FILE" && -f "$TMP_FILE" ]] && rm -f "$TMP_FILE"
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# 获取最新 release 版本
get_latest_version() {
  local version
  version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name')
  if [[ -z "$version" ]]; then
    error "无法获取最新版本信息"
  fi
  echo "$version"
}

# 下载源码
download_source() {
  local version="$1"
  local url="https://github.com/${REPO}/archive/refs/tags/${version}.tar.gz"

  TMP_FILE=$(mktemp -t "openclaw-${version}.tar.gz.XXXXXX") || error "无法创建临时文件"

  info "下载 OpenClaw ${version} 源码..."
  if ! curl -fsSL "$url" -o "$TMP_FILE"; then
    error "下载失败: $url"
  fi

  echo "$TMP_FILE"
}

# 停止运行中的容器
stop_containers() {
  if docker ps --filter "name=openclaw" --format "{{.Names}}" 2>/dev/null | grep -q .; then
    info "停止运行中的容器..."
    if ! docker compose -f "${SCRIPT_DIR}/docker-compose.dev.yml" down; then
      error "停止容器失败，请手动运行: docker compose -f ${SCRIPT_DIR}/docker-compose.dev.yml down"
    fi
  fi
}

# 清理旧源码
clean_old_source() {
  if [[ -d "${SRC_DIR}" ]]; then
    # 验证容器已停止
    if docker ps --filter "name=openclaw" --format "{{.Names}}" 2>/dev/null | grep -q .; then
      error "容器仍在运行，无法清理源码"
    fi
    info "清理旧版本源码..."
    rm -rf "${SRC_DIR}" || error "清理源码目录失败"
  fi
}

# 解压源码
extract_source() {
  local tar_file="$1"
  local version="$2"

  TMP_DIR=$(mktemp -d -t "openclaw-extract.XXXXXX") || error "无法创建临时目录"

  info "解压源码..."
  if ! tar -xzf "$tar_file" -C "$TMP_DIR"; then
    error "解压失败，可能是下载文件损坏"
  fi

  # 找到解压后的目录名 (通常是 openclaw-版本号)
  local extracted_dir
  extracted_dir=$(ls -1 "$TMP_DIR" | head -1)

  if [[ -z "$extracted_dir" ]]; then
    error "解压后未找到源码目录"
  fi

  info "安装新版本源码..."
  mv "${TMP_DIR}/${extracted_dir}" "${SRC_DIR}"

  # 清理临时文件 (trap 也会处理，但主动清理更好)
  rm -f "$tar_file"
  rm -rf "$TMP_DIR"
  TMP_FILE=""
  TMP_DIR=""
}

# 构建镜像 (带版本标签)
build_image() {
  local version="$1"
  local proxy_args=()

  if [[ -n "${HTTP_PROXY:-}" ]]; then
    proxy_args=("--build-arg" "HTTP_PROXY=${HTTP_PROXY}" "--build-arg" "HTTPS_PROXY=${HTTPS_PROXY:-}")
  fi

  info "构建镜像 ${IMAGE_NAME}:${version}..."
  if ! docker build \
    --no-cache \
    -t "${IMAGE_NAME}:${version}" \
    -t "${IMAGE_NAME}:latest" \
    -f "${SCRIPT_DIR}/Dockerfile.dev" \
    "${proxy_args[@]}" \
    "${SRC_DIR}"; then
    error "构建镜像失败"
  fi
  info "✓ 镜像构建完成: ${IMAGE_NAME}:${version}, ${IMAGE_NAME}:latest"
}

# 清理旧版本镜像 (保留最近 ${MAX_IMAGES} 个)
prune_old_images() {
  info "清理旧版本镜像 (保留最近 ${MAX_IMAGES} 个)..."

  # 获取所有版本标签镜像 (排除 latest)
  local images
  images=$(docker images "${IMAGE_NAME}" --format "{{.Tag}}" --filter "dangling=false" 2>/dev/null | grep -v "latest" | sort -r)

  if [[ -z "$images" ]]; then
    info "没有需要清理的旧版本镜像"
    return
  fi

  # 计算需要删除的数量
  local count
  count=$(echo "$images" | wc -l | tr -d ' ')

  if [[ $count -le $MAX_IMAGES ]]; then
    info "当前有 ${count} 个版本镜像，无需清理"
    return
  fi

  local to_remove=$((count - MAX_IMAGES))
  info "发现 ${to_remove} 个旧版本镜像需要清理..."

  # 获取要删除的镜像 (最旧的)
  local old_images
  old_images=$(echo "$images" | tail -n ${to_remove})

  for img in $old_images; do
    info "  删除 ${IMAGE_NAME}:${img}"
    docker rmi "${IMAGE_NAME}:${img}" 2>/dev/null || warn "删除镜像失败: ${IMAGE_NAME}:${img}"
  done

  info "✓ 已清理 ${to_remove} 个旧版本镜像"
}

# 主流程
main() {
  local current_version=""
  local latest_version=""

  # 检查当前版本
  if [[ -f "${SRC_DIR}/package.json" ]]; then
    local raw_version
    raw_version=$(jq -r '.version' "${SRC_DIR}/package.json" 2>/dev/null || echo "")
    if [[ -n "$raw_version" && "$raw_version" != "null" ]]; then
      current_version="v${raw_version}"
      info "当前版本: ${current_version}"
    else
      warn "无法读取当前版本"
    fi
  else
    warn "源码目录不存在"
  fi

  # 获取最新版本
  info "检查最新版本..."
  latest_version=$(get_latest_version)
  info "最新版本: ${latest_version}"

  # 检查是否需要更新
  if [[ -n "$current_version" && "$current_version" == "$latest_version" ]]; then
    info "已是最新版本，无需更新"
    exit 0
  fi

  # 下载新版本
  local tar_file
  tar_file=$(download_source "$latest_version")

  # 停止容器
  stop_containers

  # 清理旧版本
  clean_old_source

  # 解压新版本
  extract_source "$tar_file" "$latest_version"

  info "✓ 源码已更新到 ${latest_version}"

  # 构建镜像
  build_image "$latest_version"

  # 清理旧版本镜像
  prune_old_images

  info "✓ 更新完成！ 运行 'make up' 启动服务"
}

main "$@"
