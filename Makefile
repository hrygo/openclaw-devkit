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
#   make rebuild go         # 构建并重启 Go 版
#   make rebuild office     # 构建并重启 Office 版
# ==============================================================================

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
    HOME_DIR := $(USERPROFILE)
else
    HOME_DIR := $(HOME)
endif

# Export HOME for docker compose visibility on Windows
export HOME := $(HOME_DIR)

# Check shell environment on Windows
ifeq ($(OS),Windows_NT)
    # Detect if we are in a POSIX-compatible shell (Git Bash, MSYS2, Cygwin, etc.)
    ifeq ($(strip $(MSYSTEM)),)
        ifeq ($(strip $(BASH_VERSION)),)
            $(error $(shell echo 1>&2 " \
                \n  [ ERROR ]  Unsupported Shell Environment (CMD/PowerShell detected)\n \
                \n  OpenClaw DevKit requires a POSIX environment to run correctly.\n \
                \n  FIX: Please use 'Git Bash' (included with Git for Windows).\n \
                \n  1. Download: https://git-scm.com/download/win\n \
                \n  2. Launch 'Git Bash' in this directory and run 'make' again.\n\n"))
        endif
    endif
endif

# Common Commands (POSIX-Standard)
MKDIR := mkdir -p
RM    := rm -rf

# ANSI Colors (Now reliable via Git Bash/Unix)
RED    := $(shell printf '\033[0;31m')
GREEN  := $(shell printf '\033[0;32m')
YELLOW := $(shell printf '\033[1;33m')
BLUE   := $(shell printf '\033[0;34m')
CYAN   := $(shell printf '\033[0;36m')
BOLD   := $(shell printf '\033[1m')
NC     := $(shell printf '\033[0m') # No Color

# Output Prefixes
INFO    := $(BLUE)$(BOLD)==>$(NC)
SUCCESS := $(GREEN)$(BOLD)✓$(NC)
WARN    := $(YELLOW)$(BOLD)⚠$(NC)
ERROR   := $(RED)$(BOLD)✖$(NC)

.DEFAULT_GOAL := help

# 环境配置
-include .env

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

# Docker 构建公共参数 (提供安全默认值以支持回退到原始源)
DOCKER_BUILD_ARGS := --build-arg HTTP_PROXY=$(HTTP_PROXY) \
                     --build-arg HTTPS_PROXY=$(HTTPS_PROXY) \
                     --build-arg DOCKER_MIRROR=$(if $(DOCKER_MIRROR),$(DOCKER_MIRROR),docker.io) \
                     --build-arg APT_MIRROR=$(if $(APT_MIRROR),$(APT_MIRROR),mirrors.tuna.tsinghua.edu.cn) \
                     --build-arg NPM_MIRROR=$(NPM_MIRROR) \
                     --build-arg PYTHON_MIRROR=$(PYTHON_MIRROR) \
                     --build-arg OPENCLAW_VERSION=$(if $(OPENCLAW_VERSION),$(OPENCLAW_VERSION),latest)

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
	@printf "    $(BOLD)make rebuild$(NC)           强制更新镜像并重启\n"
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)🐛  调试与诊断 $(NC)\n"
	@printf "    $(BOLD)make logs$(NC)              查看 Gateway 实时日志\n"
	@printf "    $(BOLD)make shell$(NC)             进入隔离沙盒 Shell\n"
	@printf "    $(BOLD)make test-proxy$(NC)        黑盒代理通配性测试\n"
	@printf "    $(BOLD)make verify$(NC)            工具链合规检查\n"
	@printf "\n"
	@printf "  $(BOLD)$(CYAN)💾  持久化维护 $(NC)\n"
	@printf "    $(BOLD)make backup-config$(NC)     配置全量备份\n"
	@printf "    $(BOLD)make update$(NC)            从 GH 同步最新逻辑基因\n"
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
	@echo "  $(INFO) 提示: 首次安装后，请执行 $(BOLD)make onboard$(NC) 以交互式引导配置 LLM 与 聊天应用。"

up: ## 启动服务
	@docker compose up -d
	@echo "✓ 已启动 (Web: http://127.0.0.1:$(GATEWAY_PORT)/)"
	@echo "提示: 初次使用建议运行 'make onboard' 进行交互式配置。"

onboard: ## 启动交互式引导程序
	@echo "$(INFO) 启动交互式引导程序..."
	@docker compose run --rm -it -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 openclaw-cli openclaw onboard

down: ## 停止服务
	@docker compose down
	@echo "$(SUCCESS) $(GREEN)服务已停止$(NC)"

restart: ## 重启服务
	@$(MAKE) down && $(MAKE) up

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

rebuild: ## 重建镜像并重启
	@$(call do_rebuild,dev,$(MAKECMDGOALS))

rebuild-go: ## 重建 Go 版并重启
	@$(call do_rebuild,go,$(MAKECMDGOALS))

rebuild-java: ## 重建 Java 版并重启
	@$(call do_rebuild,java,$(MAKECMDGOALS))

rebuild-office: ## 重建 Office 版并重启
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
	@echo "✓ 数据卷已清理"

# ============================================================
# 调试与诊断
# ============================================================

logs: ## 查看 Gateway 日志
	@LANG=C.UTF-8 LC_ALL=C.UTF-8 docker compose logs --tail 100 -f openclaw-gateway

logs-all: ## 查看所有容器日志
	@LANG=C.UTF-8 LC_ALL=C.UTF-8 docker compose logs --tail 100 -f

shell: ## 进入 Gateway 容器
	@docker compose exec openclaw-gateway bash

verify: ## 验证镜像工具版本 (最佳实践检查)
	@echo "$(INFO) 验证目标镜像: $(BOLD)$(YELLOW)$(IMAGE_NAME)$(NC)"
	@docker run --rm $(IMAGE_NAME) node -v | grep -q "v22" && echo "$(SUCCESS) Node.js v22 (LTS) OK" || echo "$(ERROR) Node.js version mismatch"
	@docker run --rm $(IMAGE_NAME) go version 2>/dev/null | grep -q "1.2" && echo "$(SUCCESS) Go 1.2x" || echo "$(WARN) Go (Office版无)"

exec: ## 执行命令
	@docker compose exec openclaw-gateway $(CMD)

cli: ## 执行 OpenClaw CLI
	@docker compose exec openclaw-gateway $(OPENCLAW_BIN) $(CMD)

pairing: ## 频道配对
	@docker compose exec openclaw-gateway $(OPENCLAW_BIN) pairing $(CMD)

gateway-health: ## 检查健康状态
	@curl -s http://127.0.0.1:$(GATEWAY_PORT)/ >/dev/null 2>&1 && echo "✓ Web UI 正常" || echo "✗ Web UI 不可用"

test-proxy: ## 测试代理连接
	@echo "$(INFO) Google: "; docker compose exec -T openclaw-gateway \
		curl -s --proxy http://host.docker.internal:7897 --connect-timeout 3 https://www.google.com >/dev/null 2>&1 && echo "$(SUCCESS)" || echo "$(ERROR)"
	@echo "$(INFO) Claude API: "; docker compose exec -T openclaw-gateway \
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

restore-config: ## 恢复配置
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
	docker build \
		-t $(IMAGE_NAME) \
		-f Dockerfile \
		$(DOCKER_BUILD_ARGS) \
		--build-arg BASE_IMAGE=$$BASE_IMG \
		.; \
fi
endef

define do_rebuild
$(call do_build,$(1),$(2))
$(MAKE) down
$(call select_image,$(2))
OPENCLAW_IMAGE=$(IMAGE_NAME) $(MAKE) up
endef
