# ==============================================================================
# OpenClaw Docker 开发环境 - 运维 Makefile
# ==============================================================================
# 用法: make <target>
# 帮助: make help
#
# 镜像版本:
#   - docker-compose.yml       Docker Compose 配置
#   - Dockerfile               开发环境镜像
#   - docker-setup.sh          初始化脚本
#
# 示例:
#   make install              # 安装标准版
#   make install java        # 安装 Java 版
#   make install go          # 安装 Go 版
#   make install office      # 安装 Office 版
#   make build              # 构建标准版镜像
#   make upgrade go         # 升级并重启 Go 版
#   make upgrade office     # 升级并重启 Office 版
# ==============================================================================

# ============================================================
# Shell Configuration
# ============================================================
# Require bash for cross-platform consistency (macOS/Linux/Windows+GitBash)
SHELL := /bin/bash
# Disable POSIX sh mode - rely on bash features (seq, [[ ]], etc.)
SHELL_OPTS := +O globstar

# ============================================================
# Visual Styling (Whitepaper Grade)
# ============================================================

# Detect OS
ifeq ($(OS),Windows_NT)
    PLATFORM := Windows
else
    PLATFORM := Unix
endif

# Determine Home Directory
ifeq ($(PLATFORM),Windows)
    # Use USERPROFILE on Windows, but convert to POSIX path if in Git Bash
    ifneq ($(strip $(MSYSTEM)),)
        HOME_DIR := $(shell cygpath -u "$(USERPROFILE)")
    else
        HOME_DIR := $(USERPROFILE)
    endif
else
    HOME_DIR := $(HOME)
endif

# Export HOME for docker compose visibility on Windows
export HOME := $(HOME_DIR)

# Git Bash Path Conversion Fix (Windows only)
# Prevents Git Bash from converting /home/node to C:/Program Files/Git/home/node
ifeq ($(PLATFORM),Windows)
    ifneq ($(strip $(MSYSTEM)),)
        export MSYS_NO_PATHCONV := 1
    endif
endif

# Check shell environment on Windows
ifeq ($(OS),Windows_NT)
    ifeq ($(strip $(MSYSTEM)),)
        # Not in a POSIX environment - issue warning but continue
        WINDOWS_POSIX := false
    else
        WINDOWS_POSIX := true
    endif
endif

# Common Commands (POSIX-Standard)
MKDIR := mkdir -p
RM    := rm -rf

# ANSI Colors - with Windows CMD/PowerShell compatibility
# On Unix/Linux/macOS: use colors
# On Windows with POSIX (Git Bash/MSYS2): use colors
# On Windows CMD/PowerShell: no colors to avoid shell parsing issues
ifneq ($(OS),Windows_NT)
    # Unix-like systems: use ANSI colors
    RED    := $(shell printf '\033[0;31m')
    GREEN  := $(shell printf '\033[0;32m')
    YELLOW := $(shell printf '\033[1;33m')
    BLUE   := $(shell printf '\033[0;34m')
    CYAN   := $(shell printf '\033[0;36m')
    BOLD   := $(shell printf '\033[1m')
    DIM    := $(shell printf '\033[2m')
    NC     := $(shell printf '\033[0m')
else
    # Windows: check if in POSIX environment
    ifeq ($(WINDOWS_POSIX),true)
        # Git Bash/MSYS2/Cygwin: use ANSI colors
        RED    := $(shell printf '\033[0;31m')
        GREEN  := $(shell printf '\033[0;32m')
        YELLOW := $(shell printf '\033[1;33m')
        BLUE   := $(shell printf '\033[0;34m')
        CYAN   := $(shell printf '\033[0;36m')
        BOLD   := $(shell printf '\033[1m')
        NC     := $(shell printf '\033[0m')
    else
        # Windows CMD/PowerShell: no colors to avoid shell parsing issues
        RED    :=
        GREEN  :=
        YELLOW :=
        BLUE   :=
        CYAN   :=
        BOLD   :=
        NC     :=
    endif
endif

# Output Prefixes
INFO    := $(BLUE)$(BOLD)==>$(NC)
SUCCESS := $(GREEN)$(BOLD)✓$(NC)
WARN    := $(YELLOW)$(BOLD)⚠$(NC)
ERROR   := $(RED)$(BOLD)✖$(NC)

.DEFAULT_GOAL := help

# 环境配置
-include .env

# ============================================================
# 环境变量自动导出 (Ensure Docker Compose receives variables)
# ============================================================
export OPENCLAW_IMAGE
export HOST_OPENCLAW_DIR
export OPENCLAW_GATEWAY_PORT
export OPENCLAW_BRIDGE_PORT
export OPENCLAW_GATEWAY_TOKEN
export HTTP_PROXY
export HTTPS_PROXY
export ANTHROPIC_AUTH_TOKEN
export ANTHROPIC_BASE_URL

# ============================================================
# 变量定义
# ============================================================

# COMPOSE_FILE is managed by .env for flexibility
SETUP_SCRIPT := docker-setup.sh
GATEWAY_PORT ?= $(if $(OPENCLAW_GATEWAY_PORT),$(OPENCLAW_GATEWAY_PORT),18789)
OPENCLAW_BIN := openclaw

# 镜像配置
INITIAL_IMAGE_NAME := ghcr.io/hrygo/openclaw-devkit
IMAGE_NAME := $(if $(OPENCLAW_IMAGE),$(OPENCLAW_IMAGE),$(INITIAL_IMAGE_NAME):latest)

# Docker 构建公共参数
DOCKER_BUILD_ARGS := --build-arg HTTP_PROXY=$(HTTP_PROXY) \
                     --build-arg HTTPS_PROXY=$(HTTPS_PROXY) \
                     --build-arg DOCKER_MIRROR=$(if $(DOCKER_MIRROR),$(DOCKER_MIRROR),docker.io) \
                     --build-arg APT_MIRROR=$(if $(APT_MIRROR),$(APT_MIRROR),mirrors.tuna.tsinghua.edu.cn) \
                     --build-arg NPM_MIRROR=$(NPM_MIRROR) \
                     --build-arg PYTHON_MIRROR=$(PYTHON_MIRROR) \
                     --build-arg OPENCLAW_VERSION=$(if $(OPENCLAW_VERSION),$(OPENCLAW_VERSION),latest) \
                     --build-arg INSTALL_BROWSER=$(if $(INSTALL_BROWSER),$(INSTALL_BROWSER),0)

# ============================================================
# 帮助信息 (现代分组版)
# ============================================================

help: ## 显示帮助信息
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)==>   OpenClaw DevKit   |  终端运维蓝图 $(NC)\n"
	@printf "  $(BOLD)══════════════════════════════════════════════════════════$(NC)\n"
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)⚡  快速开始 (Zero-Friction) $(NC)\n"
	@printf "    $(BOLD)make install$(NC)            一键适配、生成及安装\n"
	@printf "    $(BOLD)make onboard$(NC)            交互式灵魂配置 (LLM/API)\n"
	@printf "    $(BOLD)make up$(NC)                 启动服务\n"
	@printf "    $(BOLD)make down$(NC)               停止服务\n"
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)🔄  生命周期管理 $(NC)\n"
	@printf "    $(BOLD)make restart$(NC)           服务重启\n"
	@printf "    $(BOLD)make status$(NC)            查看分层编排状态\n"
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)🔧  构建引擎 (Version: dev|go|java|office) $(NC)\n"
	@printf "    $(BOLD)make build$(NC)             感知式构建 (根据 SKIP_BUILD)\n"
	@printf "    $(BOLD)make upgrade$(NC)           ⬆️  升级镜像并重启\n"
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)🐛  调试与诊断 $(NC)\n"
	@printf "    $(BOLD)make logs$(NC)              查看 Gateway 实时日志\n"
	@printf "    $(BOLD)make tui$(NC)               🖥️  启动 TUI 终端界面\n"
	@printf "    $(BOLD)make dashboard$(NC)         🚀 一键直达仪表盘 (免配对)\n"
	@printf "    $(BOLD)make approve$(NC)           🔐 一键批准配对请求\n"
	@printf "    $(BOLD)make devices$(NC)           查看已配对设备及请求\n"
	@printf "    $(BOLD)make shell$(NC)             进入隔离沙盒 Shell\n"
	@printf "    $(BOLD)make test-proxy$(NC)        黑盒代理通配性测试\n"
	@printf "    $(BOLD)make doctor$(NC)            🛠️  一键诊断并修复容器配置\n"
	@printf "    $(BOLD)make verify$(NC)            工具链合规检查\n"
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)💾  持久化维护 $(NC)\n"
	@printf "    $(BOLD)make backup-config$(NC)     配置全量备份\n"
	@printf "    $(BOLD)make update$(NC)            从 GH 同步源码 openclaw-devkit\n"
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)🗑️  宿主机冲突解决 $(NC)\n"
	@printf "    $(BOLD)make uninstall-host$(NC)    停止并卸载宿主机 OpenClaw\n"
	@printf "\n"
	@printf "  $(BOLD)══════════════════════════════════════════════════════════$(NC)\n"
	@printf "  分级调用:  make <cmd> <version>\n"
	@printf "  ==>   dev  (标准) | go  (Go) | java  (Java) | office  (办公)\n"
	@printf "\n"
	@printf "  示例:  make install go \n"
	@printf "  $(BOLD)══════════════════════════════════════════════════════════$(NC)\n"
	@printf "\n"

# ============================================================
# 版本选择 (伪目标)
# ============================================================

go: ## 内部: 选择 Go 版
	@:

java: ## 内部: 选择 Java 版
	@:

office: ## 内部: 选择 Office 版
	@:

dev: ## 内部: 选择标准版
	@:

# ============================================================
# 生命周期管理
# ============================================================

install: ## 首次安装/初始化环境
	@$(if $(filter Unix,$(PLATFORM)),chmod +x "$(SETUP_SCRIPT)",)
	@$(call select_image,$(MAKECMDGOALS))
	@echo "$(INFO) 目标环境: $(BOLD)$(YELLOW)$(IMAGE_NAME)$(NC)"
	@OPENCLAW_IMAGE="$(IMAGE_NAME)" bash "$(SETUP_SCRIPT)"
	@echo "$(SUCCESS) $(GREEN)环境安装完毕!$(NC)"
	@echo "  $(INFO) 🚀 下一步:"
	@echo "    执行 $(BOLD)make onboard$(NC) 配置核心模型并启动服务"
	@echo ""
	@# 检测存量用户卷标签，提示迁移选项
	@if docker volume inspect openclaw-devkit-home >/dev/null 2>&1; then \
		PROJECT=$$(docker volume inspect openclaw-devkit-home --format '{{index .Labels "com.docker.compose.project"}}' 2>/dev/null || echo ""); \
		if [ "$$PROJECT" = "openclaw" ]; then \
			echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
			echo "$(YELLOW)⚠️  检测到存量卷标签 (project=openclaw)$(NC)"; \
			echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
			echo ""; \
			echo "$(INFO) 升级后将看到 Docker Compose 警告 (不影响使用):"; \
			echo "  WARN volume already exists but was created for project \"openclaw\""; \
			echo ""; \
			echo "$(INFO) 消除警告方法 (可选，执行一次即可):"; \
			echo "  $(BOLD)./scripts/migrate-volumes.sh$(NC)"; \
			echo ""; \
		fi; \
	fi

# ============================================================
# 服务启动辅助函数
# ============================================================

# 等待服务就绪 (带超时、可视化进度条和实时日志)
# 用法: $(call wait-for-healthy,timeout_seconds)
#
# 就绪策略（三层保障）：
#   1. Docker health check "healthy" → 立即成功
#   2. Docker health check 不可用 → HTTP /healthz 探测兜底
#   3. 以上均未就绪 → 等待至超时
#
# 失败判定：
#   - 前 MIN_GRACE_PERIOD 秒内：忽略 unhealthy 状态（服务初始化预热）
#   - 超过预热期后：连续 UNHEALTHY_THRESHOLD 次 unhealthy 才判定失败
#   - 超时：所有检查均未就绪
define wait-for-healthy
	@echo "$(INFO) 等待服务就绪..."; \
	PROGRESS_BAR_WIDTH=40; \
	MIN_GRACE_PERIOD=45; \
	UNHEALTHY_THRESHOLD=8; \
	CONSECUTIVE_UNHEALTHY=0; \
	for i in $$(seq 1 $(1)); do \
		STATUS=$$(docker inspect --format='{{.State.Health.Status}}' openclaw-gateway 2>/dev/null || echo "none"); \
		if [ "$$STATUS" = "healthy" ]; then \
			echo ""; \
			FILLED=$$((PROGRESS_BAR_WIDTH)); \
			BAR=$$(printf '█%.0s' $$(seq 1 $$FILLED))$$(printf '░%.0s' $$(seq 1 $$((PROGRESS_BAR_WIDTH - FILLED)))); \
			PCT=100; \
			printf "\r$${BAR} $(BOLD)%3d%%$(NC) $(GREEN)✓ Ready!$(NC) ($${i}s)\n" "$$PCT"; \
			exit 0; \
		fi; \
		if [ "$$STATUS" = "unhealthy" ]; then \
			CONSECUTIVE_UNHEALTHY=$$((CONSECUTIVE_UNHEALTHY + 1)); \
			if [ $$i -le $$MIN_GRACE_PERIOD ]; then \
				:; \
			elif [ $$CONSECUTIVE_UNHEALTHY -ge $$UNHEALTHY_THRESHOLD ]; then \
				echo ""; \
				printf "\r$(RED)[✗ Service Failed]$(NC) unhealthy 状态持续约 $$((CONSECUTIVE_UNHEALTHY * 10))s (连续 $$CONSECUTIVE_UNHEALTHY 次轮询失败，超过 $${MIN_GRACE_PERIOD}s 预热期)\n"; \
				echo "  执行 $(BOLD)make logs$(NC) 查看详细日志"; \
				exit 1; \
			fi; \
		else \
			CONSECUTIVE_UNHEALTHY=0; \
		fi; \
		PCT=$$((i * 100 / $(1))); \
		FILLED=$$((i * PROGRESS_BAR_WIDTH / $(1))); \
		BAR=$$(printf '█%.0s' $$(seq 1 $$FILLED 2>/dev/null))$$(printf '░%.0s' $$(seq 1 $$((PROGRESS_BAR_WIDTH - FILLED)) 2>/dev/null)); \
		STATUS_ICON="⚠"; \
		STATUS_COLOR="$(YELLOW)"; \
		[ "$$STATUS" = "starting" ] && STATUS_ICON="🔄" && STATUS_COLOR="$(CYAN)"; \
		[ "$$STATUS" = "healthy"   ] && STATUS_ICON="✅" && STATUS_COLOR="$(GREEN)"; \
		[ "$$STATUS" = "unhealthy" ] && STATUS_ICON="✗" && STATUS_COLOR="$(RED)"; \
		[ "$$STATUS" = "none"      ] && STATUS_ICON="?" && STATUS_COLOR="$(DIM)" && STATUS="no-health-check"; \
		printf "\r$($$STATUS_COLOR)[$$BAR]$(NC) $(BOLD)%3d%%$(NC) $$STATUS_ICON %ds/$(1)s [$$STATUS]   " "$$PCT" "$$i"; \
		if [ $$((i % 8)) -eq 0 ]; then \
			LOG_LINE="$$(docker compose logs --tail 1 openclaw-gateway 2>/dev/null | sed 's/^openclaw-gateway  | //' | head -c 60)"; \
			[ -n "$$LOG_LINE" ] && printf "\n  $(DIM)%s...$(NC)\n" "$$LOG_LINE"; \
		fi; \
		sleep 1; \
	done; \
	echo ""; \
	printf "\r$(YELLOW)[░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] Timeout$(NC)\n"; \
	echo "$(WARN) 服务启动超时 (等待 $(1)s)，容器可能仍在启动中"; \
	echo "$(INFO) 可用 $(BOLD)make status$(NC) 查看状态，或 $(BOLD)make logs$(NC) 查看日志"
endef

# ============================================================
# 生命周期管理
# ============================================================

up: ## 启动服务
	@mkdir -p "$(HOME)/.agents/skills"
	@echo "$(INFO) 启动 OpenClaw 服务..."
	@# 捕获 Docker Compose 输出并检测卷警告
	@docker compose up -d 2>&1 | tee /tmp/openclaw-up.log || true
	@echo ""
	@# 检测是否出现卷标签警告
	@if grep -q "volume.*already exists but was created for project.*openclaw" /tmp/openclaw-up.log 2>/dev/null; then \
		echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
		echo "$(YELLOW)⚠️  检测到 Docker Compose 卷标签警告$(NC)"; \
		echo "$(YELLOW)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"; \
		echo ""; \
		echo "$(INFO) 这是因为您之前使用过 openclaw 项目，卷标签仍为旧项目名。"; \
		echo "$(INFO) 不影响使用，但可通过迁移脚本消除警告（执行一次即可）:"; \
		echo ""; \
		echo "  $(BOLD)$(GREEN)./migrate-volumes.sh$(NC)"; \
		echo ""; \
		echo "$(INFO) 迁移脚本会自动备份并重建卷，1-3 分钟完成。"; \
		echo ""; \
	fi
	@rm -f /tmp/openclaw-up.log
	$(call wait-for-healthy,90)
	@echo ""
	@echo "$(SUCCESS) 访问地址: $(BOLD)http://127.0.0.1:$(GATEWAY_PORT)/$(NC)"
	@echo "  $(INFO) 仪表盘: 执行 $(BOLD)make dashboard$(NC) 获取一键直通链接"
	@echo "  $(INFO) 实时日志: 执行 $(BOLD)make logs$(NC)"

start: up ## 启动服务 (别名)

onboard: ## 启动交互式引导程序
	@echo "$(INFO) 启动交互式引导程序..."
	@docker compose run --rm -it -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 openclaw-gateway openclaw onboard
	@echo ""
	@echo "$(SUCCESS) 配置完毕! 接下来请执行:"
	@echo "  ⚡ $(BOLD)make up$(NC)                正式启动服务"
	@echo "  🚀 $(BOLD)make dashboard$(NC)         一键免密直达 Web UI"

down: ## 停止服务
	@echo "$(INFO) 停止服务..."
	@docker compose down
	@echo "$(SUCCESS) 服务已停止"

stop: down ## 停止服务 (别名)

uninstall-host: ## 停止并卸载宿主机 OpenClaw
	@echo ""
	@echo "$(INFO) 检测宿主机 OpenClaw 安装..."
	@echo ""
	@if command -v openclaw >/dev/null 2>&1; then \
		echo ""; \
		echo "  $(WARN) OpenClaw CLI 已安装"; \
		echo ""; \
		echo "  推荐：使用官方卸载命令（最彻底）"; \
		echo "    npx -y openclaw uninstall --all --yes --non-interactive"; \
		echo ""; \
		echo "  分步卸载："; \
		echo ""; \
		echo "  Step 1 - 停止服务"; \
		echo "    macOS (launchd CLI):   launchctl bootout gui/$$UID/bot.molt.gateway"; \
		echo "    macOS (App):           launchctl bootout gui/$$UID/ai.openclaw.mac"; \
		echo "    Linux (systemd user):   systemctl --user stop openclaw-gateway.service"; \
		echo "    直接进程:              pkill -f openclaw-gateway"; \
		echo ""; \
		echo "  Step 2 - 卸载 CLI"; \
		echo "    npm:  npm uninstall -g openclaw"; \
		echo "    pnpm: pnpm remove -g openclaw"; \
		echo "    bun:  bun remove -g openclaw"; \
		echo ""; \
		echo "  Step 3 - 清理残留服务文件"; \
		echo "    macOS (CLI plist):     rm -f ~/Library/LaunchAgents/bot.molt.gateway.plist"; \
		echo "    macOS (App plist):     rm -f ~/Library/LaunchAgents/ai.openclaw.mac.plist"; \
		echo "    Linux (systemd unit):   rm -f ~/.config/systemd/user/openclaw-gateway.service"; \
		echo ""; \
		echo "  Step 4 - 清理配置（按需）"; \
		echo "    rm -rf ~/.openclaw"; \
		echo ""; \
		echo "  跳过停止，直接卸载:"; \
		echo "    npx -y openclaw uninstall --all --yes --non-interactive"; \
	else \
		echo "  $(SUCCESS) 未检测到宿主机 OpenClaw CLI，无冲突。"; \
	fi
	@echo ""

restart: ## 重启服务
	@echo "$(INFO) 重启服务..."
	@docker compose down 2>/dev/null || true
	@docker compose up -d
	@echo ""
	$(call wait-for-healthy,90)
	@echo ""
	@echo "$(SUCCESS) 访问地址: $(BOLD)http://127.0.0.1:$(GATEWAY_PORT)/$(NC)"

status: ## 查看服务状态
	@echo "【容器】"
	@docker ps --filter "name=openclaw" --format "  {{.Names}}: {{.Status}}" 2>/dev/null || echo "  (无运行中的容器)"
	@echo ""
	@echo "【镜像】"
	@docker images "$(IMAGE_NAME)" --format "  {{.Repository}}:{{.Tag}} ({{.Size}})" 2>/dev/null || echo "  (未构建)"
	@echo ""
	@echo "【访问】 http://127.0.0.1:$(GATEWAY_PORT)/"

# ============================================================
# 构建与清理
# ============================================================

# ============================================================
# 构建与清理 (Hierarchical Layering)
# ============================================================

build-base: ## 构建统一基础镜像 (debian:bookworm-slim)
	@echo "$(INFO) 正在构建基础设施镜像: $(BOLD)openclaw-runtime:base$(NC)"
	@docker build -t openclaw-runtime:base -f Dockerfile.base $(DOCKER_BUILD_ARGS) .

build-stacks: build-base ## 构建全套技术栈基座 (Go, Java, Office)
	@echo "$(INFO) 正在构建技术栈基座..."
	@docker build -t openclaw-runtime:go --target stack-go -f Dockerfile.stacks $(DOCKER_BUILD_ARGS) --build-arg BASE_IMAGE=openclaw-runtime:base .
	@docker build -t openclaw-runtime:java --target stack-java -f Dockerfile.stacks $(DOCKER_BUILD_ARGS) --build-arg BASE_IMAGE=openclaw-runtime:base .
	@docker build -t openclaw-runtime:office --target stack-office -f Dockerfile.stacks $(DOCKER_BUILD_ARGS) --build-arg BASE_IMAGE=openclaw-runtime:base .

build: ## 构建标准版镜像 (基于 openclaw-runtime:base)
	@$(call do_build,dev,$(MAKECMDGOALS))

build-go: ## 构建 Go 版镜像 (基于 openclaw-runtime:go)
	@$(call do_build,go,$(MAKECMDGOALS))

build-java: ## 构建 Java 版镜像 (基于 openclaw-runtime:java)
	@$(call do_build,java,$(MAKECMDGOALS))

build-office: ## 构建 Office 版镜像 (基于 openclaw-runtime:office)
	@$(call do_build,office,$(MAKECMDGOALS))

# --------------------------------------------------------------

upgrade: ## ⬆️  升级镜像并重启 (拉取最新镜像或本地构建)
	@$(call do_rebuild,dev,$(MAKECMDGOALS))

upgrade-go: ## 升级 Go 版镜像并重启
	@$(call do_rebuild,go,$(MAKECMDGOALS))

upgrade-java: ## 升级 Java 版镜像并重启
	@$(call do_rebuild,java,$(MAKECMDGOALS))

upgrade-office: ## 升级 Office 版镜像并重启
	@$(call do_rebuild,office,$(MAKECMDGOALS))

# 向后兼容别名
rebuild: ## [已弃用] 请使用 upgrade
	@echo "$(WARN)  'rebuild' 已更名为 'upgrade'，建议使用新命令"
	@$(call do_rebuild,dev,$(MAKECMDGOALS))

rebuild-go: ## [已弃用] 请使用 upgrade-go
	@echo "$(WARN)  'rebuild-go' 已更名为 'upgrade-go'，建议使用新命令"
	@$(call do_rebuild,go,$(MAKECMDGOALS))

rebuild-java: ## [已弃用] 请使用 upgrade-java
	@echo "$(WARN)  'rebuild-java' 已更名为 'upgrade-java'，建议使用新命令"
	@$(call do_rebuild,java,$(MAKECMDGOALS))

rebuild-office: ## [已弃用] 请使用 upgrade-office
	@echo "$(WARN)  'rebuild-office' 已更名为 'upgrade-office'，建议使用新命令"
	@$(call do_rebuild,office,$(MAKECMDGOALS))

clean: ## 清理容器和悬空镜像
	@docker compose down --remove-orphans
	@docker image prune -f 2>/dev/null || true
	@echo "$(SUCCESS) 已清理"

clean-volumes: ## 清理所有数据卷
	@echo "$(WARN)  确认清理所有数据卷? 按 Enter 确认, Ctrl+C 取消"
	@sh -c 'read confirm && docker compose down -v && \
		docker volume rm openclaw-node-modules openclaw-go-mod \
		openclaw-playwright-cache openclaw-playwright-bin \
		openclaw-state 2>/dev/null || true'

migrate-volumes: ## 迁移卷标签 (存量用户消除警告)
	@# 检测平台并执行对应的迁移脚本
	@if [ "$(PLATFORM)" = "Windows" ]; then \
		if [ -f "./scripts/migrate-volumes.ps1" ]; then \
			echo "$(INFO) Windows 环境: 使用 PowerShell 脚本"; \
			powershell -ExecutionPolicy Bypass -File ./scripts/migrate-volumes.ps1; \
		else \
			echo "$(INFO) Windows 环境: 使用 Git Bash"; \
			bash ./scripts/migrate-volumes.sh; \
		fi; \
	else \
		echo "$(INFO) Unix/macOS 环境: 使用 Bash 脚本"; \
		bash ./scripts/migrate-volumes.sh; \
	fi

# ============================================================
# 调试与诊断
# ============================================================

logs: ## 查看 Gateway 日志
	@LANG=C.UTF-8 LC_ALL=C.UTF-8 docker compose logs --tail 100 -f openclaw-gateway

logs-all: ## 查看所有容器日志
	@LANG=C.UTF-8 LC_ALL=C.UTF-8 docker compose logs --tail 100 -f

shell: ## 进入 Gateway 容器 (以 node 用户登录，切换到 node 主目录)
	@docker compose exec -u node -w /home/node -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 openclaw-gateway bash -l

tui: ## 启动 OpenClaw TUI 终端界面
	@docker compose exec -it -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 openclaw-gateway openclaw tui

dashboard: ## 🚀 一键直达仪表盘 (自动带 token)
	@echo "$(INFO) 正在生成直通链接..."
	@URL=$$(docker compose exec -T openclaw-gateway sh -c "openclaw dashboard --no-open | grep 'Dashboard URL:' | cut -d' ' -f3"); \
	if [ -n "$$URL" ]; then \
		echo "$(SUCCESS) 仪表盘已就绪:"; \
		echo "  $(BOLD)$(CYAN)$$URL$(NC)"; \
		echo ""; \
		if command -v open >/dev/null 2>&1; then \
			open "$$URL" 2>/dev/null || true; \
		fi; \
		echo "提示: 链接已自动打开。如显示 'pairing required' 请执行 $(BOLD)make approve$(NC)"; \
	else \
		echo "$(ERROR) 无法获取 URL，请确保容器正在运行。"; \
	fi

devices: ## 列举所有配对设备及请求
	@docker compose exec -T openclaw-gateway openclaw devices list

approve: ## 🔐 一键批准最新的配对请求
	@echo "$(INFO) 正在全自动识别待处理请求..."
	@REQ_ID=$$(docker compose exec -T openclaw-gateway sh -c "openclaw devices list --json | jq -r '.pending[0].requestId // empty'"); \
	if [ -n "$$REQ_ID" ]; then \
		echo "$(INFO) 检测到请求 ID: $$REQ_ID"; \
		docker compose exec -T openclaw-gateway openclaw devices approve "$$REQ_ID"; \
		echo "$(SUCCESS) 已自动批准！现在请返回浏览器刷新页面。"; \
	else \
		echo "$(WARN) 未发现待处理请求。"; \
		echo "提示: 请先在浏览器访问 http://127.0.0.1:$(GATEWAY_PORT)/ 触发配对提示。"; \
	fi

verify: ## 验证镜像工具版本 (最佳实践检查)
	@$(call select_image,$(MAKECMDGOALS))
	@echo "$(INFO) 验证目标镜像: $(BOLD)$(YELLOW)$(IMAGE_NAME)$(NC)"
	@docker run --rm --entrypoint bash $(IMAGE_NAME) -c ' \
		echo "  [Debug] PATH: $$PATH"; \
		node -v >/dev/null 2>&1 && echo "  $(SUCCESS) Node.js OK" || echo "  $(ERROR) Node.js missing"; \
		command -v opencode >/dev/null 2>&1 && echo "  $(SUCCESS) OpenCode CLI OK" || (echo "  $(ERROR) OpenCode CLI missing" && ls -l /home/node/.opencode/bin/opencode 2>/dev/null || echo "    (File /home/node/.opencode/bin/opencode not found)"); \
		command -v openclaw >/dev/null 2>&1 && echo "  $(SUCCESS) OpenClaw Gateway OK" || echo "  $(ERROR) OpenClaw Gateway missing"; \
		command -v claude >/dev/null 2>&1 && echo "  $(SUCCESS) Claude Code CLI OK" || echo "  $(ERROR) Claude Code CLI missing"; \
		command -v go >/dev/null 2>&1 && echo "  $(SUCCESS) Go OK" || (echo "  $(WARN) Go missing/unsupported" && command -v go || echo "    (Check variant: $$(echo $(IMAGE_NAME) | cut -d: -f2))"); \
		command -v uv >/dev/null 2>&1 && echo "  $(SUCCESS) Python UV OK" || echo "  $(ERROR) Python UV missing" \
	'

exec: ## 执行命令 (需要 CMD="..." 参数)
	@docker compose exec -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 openclaw-gateway $(CMD)

cli: ## 执行 OpenClaw CLI 命令 (需要 CMD="..." 参数)
	@docker compose exec openclaw-gateway $(OPENCLAW_BIN) $(CMD)

run: ## 交互式进入容器
	@docker compose exec openclaw-gateway bash

pairing: ## 频道配对
	@docker compose exec openclaw-gateway $(OPENCLAW_BIN) pairing $(CMD)

pair: pairing ## 频道配对 (别名)

gateway-health: ## 检查健康状态
	@curl -s http://127.0.0.1:$(GATEWAY_PORT)/ >/dev/null 2>&1 && echo "✓ Web UI 正常" || echo "✗ Web UI 不可用"

health: gateway-health ## 检查健康状态 (别名)
 
doctor: ## 🛠️  一键诊断并修复容器配置
	@echo "$(INFO) 正在诊断容器配置..."
	@docker compose exec -it openclaw-gateway openclaw doctor --fix
	@echo "$(SUCCESS) 诊断与修复完成！"

test-proxy: ## 测试代理连接 (默认端口: HTTP=7897, Claude API=15721)
	@echo "$(INFO) Google (proxy: http://host.docker.internal:7897): "; docker compose exec -T openclaw-gateway \
		curl -s --proxy http://host.docker.internal:7897 --connect-timeout 3 https://www.google.com >/dev/null 2>&1 && echo "$(SUCCESS)" || echo "$(ERROR)"
	@echo "$(INFO) Claude API (proxy: http://host.docker.internal:15721): "; docker compose exec -T openclaw-gateway \
		curl -s --proxy http://host.docker.internal:15721 --connect-timeout 3 https://api.anthropic.com >/dev/null 2>&1 && echo "$(SUCCESS)" || echo "$(ERROR)"

# ============================================================
# 备份与恢复
# ============================================================

BACKUP_DIR := $(HOME_DIR)/.openclaw-backups

backup-config: ## 备份配置
	@$(MKDIR) $(BACKUP_DIR)
	@sh -c 'TIM=$$(date +%Y%m%d-%H%M%S) && \
		tar -czf $(BACKUP_DIR)/main-agent-$$TIM.tar.gz -C $(HOME_DIR)/.openclaw/agents/main/agent . 2>/dev/null && echo "✓ main" || echo "⚠ main (无)"; \
		tar -czf $(BACKUP_DIR)/codex-agent-$$TIM.tar.gz -C $(HOME_DIR)/.openclaw/agents/codex/agent . 2>/dev/null && echo "✓ codex" || echo "⚠ codex (无)"; \
		cp $(HOME_DIR)/.openclaw/openclaw.json $(BACKUP_DIR)/openclaw-$$TIM.json 2>/dev/null && echo "✓ config" || echo "⚠ config (无)"'
	@echo "备份完成: $(BACKUP_DIR)"

backup: backup-config ## 备份配置 (别名)

restore-config: ## 恢复配置
	@echo "用法: make restore FILE=<filename>"

restore: restore-config ## 恢复配置 (别名)

ifndef FILE
	@echo "用法: make restore-config FILE=<filename>"
	@sh -c 'ls -lt $(BACKUP_DIR) 2>/dev/null | head -5 || echo "  (无备份)"'
	@exit 1
endif
	@echo "⚠ 确认恢复 $(FILE)? 按 Enter 确认"
	@sh -c 'read confirm && \
		if [[ "$(FILE)" == *agent*.tar.gz ]]; then \
			AGENT=$$(echo "$(FILE)" | sed "s/-agent-.*//"); \
			mkdir -p $(HOME_DIR)/.openclaw/agents/$$AGENT/agent; \
			tar -xzf $(BACKUP_DIR)/$(FILE) -C $(HOME_DIR)/.openclaw/agents/$$AGENT/agent; \
			echo "✓ 已恢复 $$AGENT"; \
		elif [[ "$(FILE)" == *.json ]]; then \
			cp $(BACKUP_DIR)/$(FILE) $(HOME_DIR)/.openclaw/openclaw.json; \
			echo "✓ 已恢复 config"; \
		fi'

update: ## 从 GitHub 同步源码 openclaw-devkit
	@echo "$(INFO) 正在从 GitHub 同步最新代码..."
	@if ! git diff --quiet 2>/dev/null; then \
		echo "$(WARNING) 存在未暂存的更改，请先提交或暂存"; \
		git status -s; \
		exit 1; \
	fi
	@git fetch origin
	@git status -sb | head -1
	@echo ""
	@BEHIND=$$(git rev-list --count HEAD..origin/$(shell git rev-parse --abbrev-ref HEAD) 2>/dev/null); \
	AHEAD=$$(git rev-list --count origin/$(shell git rev-parse --abbrev-ref HEAD)..HEAD 2>/dev/null); \
	if [ "$$BEHIND" -eq 0 ] && [ "$$AHEAD" -eq 0 ]; then \
		echo "$(SUCCESS) 已是最新版本"; \
	elif [ "$$BEHIND" -gt 0 ] && [ "$$AHEAD" -eq 0 ]; then \
		echo "$(INFO) 落后远程 $$BEHIND 个提交，正在拉取..."; \
		git pull --rebase; \
		echo ""; \
		echo "$(SUCCESS) 更新完成! 如需应用镜像更新，请执行:$(BOLD) make upgrade$(NC)"; \
	elif [ "$$AHEAD" -gt 0 ] && [ "$$BEHIND" -eq 0 ]; then \
		echo "$(INFO) 本地领先远程 $$AHEAD 个提交，无需更新"; \
		echo "$(INFO) 如需推送，请执行:$(BOLD) git push$(NC)"; \
	else \
		echo "$(WARNING) 本地与远程已分叉 (领先 $$AHEAD，落后 $$BEHIND)"; \
		echo "$(INFO) 请手动解决:$(BOLD) git rebase origin/$(shell git rev-parse --abbrev-ref HEAD)$(NC)"; \
	fi

# ============================================================
# 维护
# ============================================================

check-deps: ## 检查依赖
	@echo "Docker: "; sh -c 'command -v docker >/dev/null 2>&1 && docker --version | cut -d" " -f3 | xargs echo || echo "✗"'
	@echo "Compose: "; sh -c 'command -v docker >/dev/null 2>&1 && docker compose version --short 2>/dev/null || echo "✗"'

# ============================================================
# 内部函数
# ============================================================

define select_image
$(eval _VARIANT := $(if $(filter office %office,$(1)),office,$(if $(filter java %java,$(1)),java,$(if $(filter go %go,$(1)),go,$(if $(filter dev %dev,$(1)),latest,)))))
$(if $(_VARIANT),$(eval IMAGE_NAME := $(INITIAL_IMAGE_NAME):$(_VARIANT)),)
endef

define do_build
$(call select_image,$(2))
@if [ "$(OPENCLAW_SKIP_BUILD)" = "true" ]; then \
	echo "==> 跳过构建，正在拉取镜像: $(IMAGE_NAME)"; \
	docker pull $(IMAGE_NAME); \
else \
	echo "==> 正在构建镜像: $(IMAGE_NAME) (基于新分层架构)"; \
	BASE_IMG=$(if $(filter go,$(1)),openclaw-runtime:go,$(if $(filter java,$(1)),openclaw-runtime:java,$(if $(filter office,$(1)),openclaw-runtime:office,openclaw-runtime:base))); \
	CLI_VER_ARG=""; \
	if [ -n "$(CLI_VERSION)" ]; then CLI_VER_ARG="--build-arg CLI_VERSION=$(CLI_VERSION)"; fi; \
	AI_TOOLS_ARG="--build-arg INSTALL_AI_TOOLS=1"; \
	if [ "$(1)" = "office" ]; then AI_TOOLS_ARG="--build-arg INSTALL_AI_TOOLS=0"; fi; \
	docker build \
		-t $(IMAGE_NAME) \
		-f Dockerfile \
		$(DOCKER_BUILD_ARGS) \
		--build-arg BASE_IMAGE=$$BASE_IMG \
		$$CLI_VER_ARG \
		$$AI_TOOLS_ARG \
		.; \
fi
endef

define do_rebuild
$(call do_build,$(1),$(2))
$(MAKE) down
$(call select_image,$(2))
OPENCLAW_IMAGE=$(IMAGE_NAME) $(MAKE) up
endef
