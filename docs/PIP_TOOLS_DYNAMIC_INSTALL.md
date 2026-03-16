# PIP_TOOLS 动态安装方案

> 本文档已归档 — notebooklm CLI 现已内置于镜像中。本方案保留供将来参考。

## 概述

PIP_TOOLS 是 OpenClaw DevKit 的动态 Python 工具安装方案，允许在容器启动时自动安装 Python 包作为系统级工具。

## 原理

通过 Docker Compose 环境变量触发容器入口脚本执行安装逻辑：

```
docker-compose.yml → PIP_TOOLS 环境变量 → docker-entrypoint.sh → uv pip install
```

## 配置方法

### 1. 在 .env 中配置

```bash
# 安装单个工具
PIP_TOOLS=notebooklm-py:notebooklm

# 安装多个工具
PIP_TOOLS="notebooklm-py:notebooklm pandas black:blackd"
```

### 2. 格式说明

```
包名:二进制名
```

- **包名**：PyPI 上的包名称
- **二进制名**（可选）：安装后的 CLI 命令名，默认为包名

### 3. 示例

| 期望效果 | 配置值 |
|---------|--------|
| 安装 notebooklm-py，命令为 notebooklm | `notebooklm-py:notebooklm` |
| 安装 pandas（无自定义命令名） | `pandas` |
| 安装 black，命令为 blackd | `black:blackd` |

## 实现代码

### docker-compose.yml

```yaml
environment:
  # Python Tools Auto-Install (space-separated, format: pkg[:bin])
  # Examples: "notebooklm", "pandas", "black:blackd"
  # Tools are installed to system Python via uv on first startup
  PIP_TOOLS: ${PIP_TOOLS:-}
```

### docker-entrypoint.sh

```bash
# ------------------------------------------------------------------------------
# 5. Auto-install pip tools (reinstalled on rebuild via entrypoint)
# Set PIP_TOOLS env var to install packages, e.g., PIP_TOOLS="notebooklm pandas"
# Format: "pkg_name:binary_name" to specify binary (e.g., "notebooklm-py:notebooklm")
# ------------------------------------------------------------------------------
if [[ -n "${PIP_TOOLS:-}" ]]; then
    echo "--> Checking pip tools: ${PIP_TOOLS}"

    for tool in ${PIP_TOOLS}; do
        # Extract package name (before :) and binary name (after :) if specified
        pkg_name="${tool%%:*}"
        bin_name="${tool#*:}"

        # Security: Validate both package name and binary name to prevent command injection
        if ! validate_pkg_name "${pkg_name}"; then
            echo "--> ERROR: Skipping invalid package name: ${pkg_name}"
            continue
        fi
        if ! validate_pkg_name "${bin_name}"; then
            echo "--> ERROR: Skipping invalid binary name: ${bin_name}"
            continue
        fi

        # Check if binary exists
        if ! command -v "${bin_name}" >/dev/null 2>&1; then
            echo "--> Installing ${pkg_name} (binary: ${bin_name})..."
            # Use uv for fast installation (available in DevKit images)
            if command -v uv >/dev/null 2>&1; then
                uv pip install --system --break-system-packages --no-cache "${pkg_name}"
            # Fallback to pip3 if uv is not available
            elif command -v pip3 >/dev/null 2>&1; then
                pip3 install --break-system-packages --no-cache-dir "${pkg_name}"
            fi
        fi
    done
fi
```

### 安全验证函数

```bash
validate_pkg_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "ERROR: Invalid package name: $name" >&2
        return 1
    fi
    return 0
}
```

## 使用场景

### 场景 1：安装新的 Python CLI 工具

```bash
# 在 .env 中添加
echo "PIP_TOOLS=httpx:httpx" >> .env

# 重启容器
make down && make up
```

### 场景 2：禁用已内置的工具

如果需要禁用已内置的工具，可以设置空值：

```bash
# 禁用所有动态安装
echo "PIP_TOOLS=" >> .env
```

### 场景 3：手动安装

```bash
# 进入容器
make shell

# 手动安装
uv pip install --system --break-system-packages <package>
```

## 注意事项

1. **包名验证**：只允许字母、数字、点号、下划线连字符，防止命令注入
2. **幂等设计**：已安装的包会跳过，避免重复安装
3. **使用 uv**：优先使用 uv（比 pip 快 10-100 倍），降级到 pip3
4. **系统级安装**：使用 `--system --break-system-packages` 安装到系统 Python

## 重新启用方案

如需重新启用 PIP_TOOLS 方案：

1. 在 `docker-compose.yml` 中恢复 PIP_TOOLS 环境变量
2. 在 `docker-entrypoint.sh` 中恢复动态安装逻辑
3. 移除 `Dockerfile.base` 中的 notebooklm-py 内置安装（如不需要）
