# ==============================================================================
# OpenClaw Docker 开发环境 - 运维 Makefile
# ==============================================================================
# 用法: make <target>
# 帮助: make help
#
# 镜像版本:
#   - openclaw:dev     标准版 (默认)
#   - openclaw:pro     Office 办公版
#   - openclaw:dev-java Java 增强版
#
# 示例:
#   make install              # 安装标准版
#   make install java        # 安装 Java 版
#   make install office      # 安装 Office 版
#   make build              # 构建标准版镜像
#   make rebuild office     # 构建并重启 Office 版
# ==============================================================================

.PHONY: help install up down restart logs shell status \
        build build-java build-office rebuild rebuild-java rebuild-office \
        clean clean-volumes \
        exec cli pairing gateway-health test-proxy verify \
        backup-config restore-config \
        update check-deps \
        java office dev

# 默认目标
.DEFAULT_GOAL := help

# 环境配置
-include .env

# ============================================================
# 变量定义
# ============================================================

COMPOSE_FILE := docker-compose.dev.yml
SETUP_SCRIPT := docker-dev-setup.sh
GATEWAY_PORT := 18789
OPENCLAW_BIN := openclaw

# 镜像配置
IMAGE_NAME ?= $(OPENCLAW_IMAGE)
ifeq ($(IMAGE_NAME),)
IMAGE_NAME := openclaw:dev
endif

# Docker 构建公共参数
DOCKER_BUILD_ARGS := --build-arg HTTP_PROXY=$(HTTP_PROXY) --build-arg HTTPS_PROXY=$(HTTPS_PROXY)

# ============================================================
# 帮助信息 (简洁版)
# ============================================================

help: ## 显示帮助
	@echo ""
	@echo "  OpenClaw DevKit $(shell echo '$(IMAGE_NAME)' | sed 's/.*://')  |  运维工具"
	@echo "  ─────────────────────────────────────────────────────────────"
	@echo ""
	@echo "  快速开始:"
	@echo "    make install              # 安装 (标准版)"
	@echo "    make up                  # 启动服务"
	@echo "    make logs                # 查看日志"
	@echo ""
	@echo "  生命周期:"
	@echo "    install   / up   / down  / restart  / status"
	@echo ""
	@echo "  构建 (可选: dev|office|java):"
	@echo "    build     / rebuild        # 构建或重建镜像"
	@echo ""
	@echo "  调试:"
	@echo "    shell    / logs-all      # 进入容器 / 查看所有日志"
	@echo "    exec CMD='...'           # 执行命令"
	@echo "    test-proxy              # 测试代理"
	@echo ""
	@echo "  版本切换 (前置到命令):"
	@echo "    make install office      # 安装 Office 版"
	@echo "    make build java         # 构建 Java 版"
	@echo "    make rebuild office     # 重建 Office 版"
	@echo ""
	@echo "  完整命令: make help-full"
	@echo ""

help-full: ## 显示完整帮助
	@echo ""
	@echo "  OpenClaw DevKit 运维工具"
	@echo "  ========================================"
	@echo ""
	@echo "  [生命周期]"
	@echo "    install        首次安装/初始化环境"
	@echo "    up             启动服务"
	@echo "    down           停止服务"
	@echo "    restart        重启服务"
	@echo "    status         查看服务状态"
	@echo ""
	@echo "  [构建]"
	@echo "    build          构建镜像 (默认: 标准版)"
	@echo "    build-java     构建 Java 增强版"
	@echo "    build-office   构建 Office 办公版"
	@echo "    rebuild        重建镜像并重启服务"
	@echo "    rebuild-java   重建 Java 版并重启"
	@echo "    rebuild-office 重建 Office 版并重启"
	@echo ""
	@echo "  [调试]"
	@echo "    logs           查看 Gateway 日志"
	@echo "    logs-all       查看所有容器日志"
	@echo "    shell          进入 Gateway 容器"
	@echo "    exec           执行命令"
	@echo "    cli            执行 OpenClaw CLI"
	@echo "    pairing        频道配对"
	@echo "    gateway-health 检查 Gateway 健康"
	@echo "    test-proxy     测试代理连接"
	@echo "    verify         验证镜像工具版本"
	@echo ""
	@echo "  [备份]"
	@echo "    backup-config      备份配置"
	@echo "    restore-config     恢复配置"
	@echo ""
	@echo "  [维护]"
	@echo "    update        从 GitHub 更新源码"
	@echo "    check-deps   检查依赖状态"
	@echo "    clean         清理容器和悬空镜像"
	@echo "    clean-volumes 清理所有数据卷 (慎用)"
	@echo ""
	@echo "  [版本选择]"
	@echo "    make <cmd> <version>"
	@echo "    版本: dev | office | java"
	@echo ""
	@echo "  示例:"
	@echo "    make install java    # 安装 Java 版"
	@echo "    make build office  # 构建 Office 版"
	@echo "    make rebuild office"
	@echo ""

# ============================================================
# 版本选择 (伪目标)
# ============================================================

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
	@chmod +x $(SETUP_SCRIPT)
	@$(call select_image,$(MAKECMDGOALS))
	@echo "==> 使用镜像: $(IMAGE_NAME)"
	@./$(SETUP_SCRIPT)

up: ## 启动服务
	@docker compose -f $(COMPOSE_FILE) up -d
	@echo "✓ 已启动 (Web: http://127.0.0.1:$(GATEWAY_PORT)/)"

down: ## 停止服务
	@docker compose -f $(COMPOSE_FILE) down
	@echo "✓ 已停止"

restart: ## 重启服务
	@$(MAKE) down && $(MAKE) up

status: ## 查看服务状态
	@echo "【容器】"
	@docker ps --filter "name=openclaw" --format "  {{.Names}}: {{.Status}}" 2>/dev/null || echo "  (无运行中的容器)"
	@echo ""
	@echo "【镜像】"
	@docker images $(IMAGE_NAME) --format "  {{.Repository}}:{{.Tag}} ({{.Size}})" 2>/dev/null || echo "  (未构建)"
	@echo ""
	@echo "【访问】 http://127.0.0.1:$(GATEWAY_PORT)/"

# ============================================================
# 构建与清理
# ============================================================

build: ## 构建镜像
	@$(call do_build,dev,$(MAKECMDGOALS))

build-java: ## 构建 Java 版镜像
	@$(call do_build,java,$(MAKECMDGOALS))

build-office: ## 构建 Office 版镜像
	@$(call do_build,office,$(MAKECMDGOALS))

rebuild: ## 重建镜像并重启
	@$(call do_rebuild,dev,$(MAKECMDGOALS))

rebuild-java: ## 重建 Java 版并重启
	@$(call do_rebuild,java,$(MAKECMDGOALS))

rebuild-office: ## 重建 Office 版并重启
	@$(call do_rebuild,office,$(MAKECMDGOALS))

clean: ## 清理容器和悬空镜像
	@docker compose -f $(COMPOSE_FILE) down --remove-orphans
	@docker image prune -f 2>/dev/null || true
	@echo "✓ 已清理"

clean-volumes: ## 清理所有数据卷
	@echo "⚠️  确认清理所有数据卷? 按 Enter 确认, Ctrl+C 取消"
	@read confirm
	@docker compose -f $(COMPOSE_FILE) down -v
	@docker volume rm openclaw-node-modules openclaw-go-mod \
		openclaw-playwright-cache openclaw-playwright-bin \
		openclaw-sessions-main openclaw-sessions-codex 2>/dev/null || true
	@echo "✓ 数据卷已清理"

# ============================================================
# 调试与诊断
# ============================================================

logs: ## 查看 Gateway 日志
	@docker compose -f $(COMPOSE_FILE) logs -f openclaw-gateway

logs-all: ## 查看所有容器日志
	@docker compose -f $(COMPOSE_FILE) logs -f

shell: ## 进入 Gateway 容器
	@docker compose -f $(COMPOSE_FILE) exec openclaw-gateway bash

verify: ## 验证镜像工具版本
	@docker run --rm $(IMAGE_NAME) node -v 2>/dev/null | grep -q "v22" && echo "✓ Node.js v22" || echo "✗ Node.js"
	@docker run --rm $(IMAGE_NAME) go version 2>/dev/null | grep -q "1.2" && echo "✓ Go 1.2x" || echo "⚠ Go (Office版无)"

exec: ## 执行命令
	@docker compose -f $(COMPOSE_FILE) exec openclaw-gateway $(CMD)

cli: ## 执行 OpenClaw CLI
	@docker compose -f $(COMPOSE_FILE) exec openclaw-gateway $(OPENCLAW_BIN) $(CMD)

pairing: ## 频道配对
	@docker compose -f $(COMPOSE_FILE) exec openclaw-gateway $(OPENCLAW_BIN) pairing $(CMD)

gateway-health: ## 检查健康状态
	@curl -s http://127.0.0.1:$(GATEWAY_PORT)/ >/dev/null 2>&1 && echo "✓ Web UI 正常" || echo "✗ Web UI 不可用"

test-proxy: ## 测试代理连接
	@echo "Google: "; docker compose -f $(COMPOSE_FILE) exec -T openclaw-gateway \
		curl -s --proxy http://host.docker.internal:7897 --connect-timeout 3 https://www.google.com >/dev/null 2>&1 && echo "✓" || echo "✗"
	@echo "Claude API: "; docker compose -f $(COMPOSE_FILE) exec -T openclaw-gateway \
		curl -s --proxy http://host.docker.internal:15721 --connect-timeout 3 https://api.anthropic.com >/dev/null 2>&1 && echo "✓" || echo "✗"

# ============================================================
# 备份与恢复
# ============================================================

BACKUP_DIR := ~/.openclaw-backups

backup-config: ## 备份配置
	@mkdir -p $(BACKUP_DIR)
	@TIM=$$(date +%Y%m%d-%H%M%S)
	@tar -czf $(BACKUP_DIR)/main-agent-$$TIM.tar.gz -C $(HOME)/.openclaw/agents/main/agent . 2>/dev/null && echo "✓ main" || echo "⚠ main (无)"
	@tar -czf $(BACKUP_DIR)/codex-agent-$$TIM.tar.gz -C $(HOME)/.openclaw/agents/codex/agent . 2>/dev/null && echo "✓ codex" || echo "⚠ codex (无)"
	@cp $(HOME)/.openclaw/openclaw.json $(BACKUP_DIR)/openclaw-$$TIM.json 2>/dev/null && echo "✓ config" || echo "⚠ config (无)"
	@echo "备份完成: $(BACKUP_DIR)"

restore-config: ## 恢复配置
ifndef FILE
	@echo "用法: make restore-config FILE=<filename>"
	@ls -lt $(BACKUP_DIR) 2>/dev/null | head -5 || echo "  (无备份)"
	@exit 1
endif
	@echo "⚠ 确认恢复 $(FILE)? 按 Enter 确认"
	@read confirm
	@if [[ "$(FILE)" == *agent*.tar.gz ]]; then \
		AGENT=$$(echo "$(FILE)" | sed 's/-agent-.*//'); \
		mkdir -p $(HOME)/.openclaw/agents/$$AGENT/agent; \
		tar -xzf $(BACKUP_DIR)/$(FILE) -C $(HOME)/.openclaw/agents/$$AGENT/agent; \
		echo "✓ 已恢复 $$AGENT"; \
	elif [[ "$(FILE)" == *.json ]]; then \
		cp $(BACKUP_DIR)/$(FILE) $(HOME)/.openclaw/openclaw.json; \
		echo "✓ 已恢复 config"; \
	fi

# ============================================================
# 维护
# ============================================================

update: ## 更新源码
	@chmod +x update-source.sh
	@./update-source.sh

check-deps: ## 检查依赖
	@echo "Docker: "; command -v docker >/dev/null 2>&1 && docker --version | cut -d' ' -f3 | xargs echo || echo "✗"
	@echo "Compose: "; command -v docker >/dev/null 2>&1 && docker compose version --short 2>/dev/null || echo "✗"

# ============================================================
# 内部函数
# ============================================================

define select_image
$(if $(filter office,$(1)),\
	$(eval IMAGE_NAME := openclaw:pro),\
$(if $(filter java,$(1)),\
	$(eval IMAGE_NAME := openclaw:dev-java),\
	$(eval IMAGE_NAME := openclaw:dev)))
endef

define do_build
$(call select_image,$(2))
@echo "==> 构建 $(IMAGE_NAME)"
docker build -t $(IMAGE_NAME) -f Dockerfile.$(1) $(DOCKER_BUILD_ARGS) .openclaw_src
endef

define do_rebuild
$(call do_build,$(1),$(2))
$(MAKE) down
$(call select_image,$(2))
OPENCLAW_IMAGE=$(IMAGE_NAME) $(MAKE) up
endef
