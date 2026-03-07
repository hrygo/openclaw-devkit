# ==============================================================================
# OpenClaw Docker 开发环境 - 运维 Makefile
# ==============================================================================
# 用法: make <target>
# 帮助: make help
#
# 相关文件:
#   - docker-compose.dev.yml  Docker Compose 配置
#   - Dockerfile.dev          开发环境镜像
#   - docker-dev-setup.sh     初始化脚本
# ==============================================================================

.PHONY: help install up down restart logs shell status \
        build rebuild clean clean-volumes \
        exec cli gateway-health test-proxy \
        backup-config restore-config \
        update check-deps

# 默认目标
.DEFAULT_GOAL := help

# 变量
COMPOSE_FILE := docker-compose.dev.yml
SETUP_SCRIPT := docker-dev-setup.sh
IMAGE_NAME := openclaw:dev
GATEWAY_PORT := 18789

# ============================================================
# 帮助
# ============================================================

help: ## 显示帮助信息
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║       OpenClaw Docker 开发环境 - 运维工具套件              ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "用法: make <target>"
	@echo ""
	@echo "┌─ 生命周期管理 ─────────────────────────────────────────────┐"
	@grep -E '^(install|up|down|restart|status):.*## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "│  \033[36m%-18s\033[0m %s │\n", $$1, $$2}'
	@echo "├─ 构建与清理 ───────────────────────────────────────────────┤"
	@grep -E '^(build|rebuild|clean|clean-volumes):.*## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "│  \033[36m%-18s\033[0m %s │\n", $$1, $$2}'
	@echo "├─ 调试与诊断 ───────────────────────────────────────────────┤"
	@grep -E '^(logs|shell|exec|gateway-health|test-proxy):.*## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "│  \033[36m%-18s\033[0m %s │\n", $$1, $$2}'
	@echo "├─ 备份与恢复 ───────────────────────────────────────────────┤"
	@grep -E '^(backup-config|restore-config):.*## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "│  \033[36m%-18s\033[0m %s │\n", $$1, $$2}'
	@echo "├─ 维护 ─────────────────────────────────────────────────────┤"
	@grep -E '^(update|check-deps):.*## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "│  \033[36m%-18s\033[0m %s │\n", $$1, $$2}'
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "示例:"
	@echo "  make install     # 首次安装"
	@echo "  make up          # 启动服务"
	@echo "  make logs        # 查看日志"
	@echo "  make shell       # 进入容器"

# ============================================================
# 生命周期管理
# ============================================================

install: ## 首次安装/初始化环境
	@echo "==> 初始化 OpenClaw 开发环境..."
	@chmod +x $(SETUP_SCRIPT)
	./$(SETUP_SCRIPT)

up: ## 启动服务
	@echo "==> 启动 OpenClaw 服务..."
	docker compose -f $(COMPOSE_FILE) up -d
	@echo ""
	@echo "✓ 服务已启动"
	@echo "  Web UI:    http://127.0.0.1:$(GATEWAY_PORT)/"
	@echo "  查看日志:  make logs"

down: ## 停止服务
	@echo "==> 停止 OpenClaw 服务..."
	docker compose -f $(COMPOSE_FILE) down
	@echo "✓ 服务已停止"

restart: ## 重启服务 (等待容器完全重启)
	@echo "==> 重启 OpenClaw 服务..."
	@echo "    停止容器..."
	@docker compose -f $(COMPOSE_FILE) down --timeout 30
	@echo "    启动容器..."
	@docker compose -f $(COMPOSE_FILE) up -d
	@echo "    等待服务就绪..."
	@timeout 120 sh -c 'while ! docker inspect --format "{{.State.Health.Status}}" openclaw-gateway 2>/dev/null | grep -q "healthy"; do sleep 2; done' || \
		(echo "    ✗ Gateway 启动超时"; exit 1)
	@echo "✓ 服务已重启并就绪"

status: ## 查看服务状态
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║                    OpenClaw 服务状态                        ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "┌─ Docker 容器 ──────────────────────────────────────────────┐"
	@docker ps --filter "name=openclaw" --format "│  {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "│  无运行中的容器"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "┌─ 镜像信息 ─────────────────────────────────────────────────┐"
	@docker images $(IMAGE_NAME) --format "│  {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null || echo "│  镜像不存在"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "┌─ 访问地址 ─────────────────────────────────────────────────┐"
	@echo "│  Web UI:    http://127.0.0.1:$(GATEWAY_PORT)/"
	@echo "│  Gateway:   ws://127.0.0.1:$(GATEWAY_PORT)/"
	@echo "└─────────────────────────────────────────────────────────────┘"

# ============================================================
# 构建与清理
# ============================================================

build: ## 构建镜像 (不使用缓存)
	@echo "==> 构建 $(IMAGE_NAME) 镜像..."
	docker build \
		--no-cache \
		-t $(IMAGE_NAME) \
		-f Dockerfile.dev \
		--build-arg HTTP_PROXY=$(HTTP_PROXY) \
		--build-arg HTTPS_PROXY=$(HTTPS_PROXY) \
		.openclaw_src

rebuild: ## 重建镜像并重启服务
	@echo "==> 重建镜像并重启服务..."
	$(MAKE) build
	$(MAKE) down
	$(MAKE) up

clean: ## 清理容器和悬空镜像
	@echo "==> 清理 Docker 资源..."
	docker compose -f $(COMPOSE_FILE) down --remove-orphans
	docker image prune -f
	@echo "✓ 清理完成"

clean-volumes: ## 清理所有数据卷 (谨慎使用!)
	@echo "⚠️  警告: 将删除所有 OpenClaw 数据卷!"
	@echo "按 Ctrl+C 取消，或按 Enter 继续..."
	@read confirm
	docker compose -f $(COMPOSE_FILE) down -v
	docker volume rm openclaw-node-modules openclaw-go-mod \
		openclaw-playwright-cache openclaw-playwright-bin \
		openclaw-sessions-main openclaw-sessions-codex 2>/dev/null || true
	@echo "✓ 数据卷已清理"

# ============================================================
# 调试与诊断
# ============================================================

logs: ## 查看日志 (Ctrl+C 退出)
	docker compose -f $(COMPOSE_FILE) logs -f openclaw-gateway

logs-all: ## 查看所有容器日志
	docker compose -f $(COMPOSE_FILE) logs -f

shell: ## 进入 Gateway 容器
	docker compose -f $(COMPOSE_FILE) exec openclaw-gateway bash

exec: ## 执行命令 (用法: make exec CMD="node dist/index.js --help")
	docker compose -f $(COMPOSE_FILE) exec openclaw-gateway $(CMD)

cli: ## 执行 OpenClaw CLI 命令 (用法: make cli CMD="config list")
	docker compose -f $(COMPOSE_FILE) exec openclaw-gateway node dist/index.js $(CMD)

gateway-health: ## 检查 Gateway 健康状态
	@echo "==> 检查 Gateway 健康状态..."
	@curl -s http://127.0.0.1:$(GATEWAY_PORT)/ | head -5 && echo "... ✓ Web UI 正常" || echo "✗ Web UI 不可用"
	@docker compose -f $(COMPOSE_FILE) exec -T openclaw-gateway node -e \
		"fetch('http://127.0.0.1:$(GATEWAY_PORT)/healthz').then(r => { console.log(r.ok ? '✓ Health check passed' : '✗ Health check failed'); process.exit(r.ok ? 0 : 1); }).catch(e => { console.log('✗', e.message); process.exit(1); })"

test-proxy: ## 测试代理连接
	@echo "==> 测试代理连接..."
	@echo "┌─ HTTP 代理 (7897) ─────────────────────────────────────────┐"
	@docker compose -f $(COMPOSE_FILE) exec -T openclaw-gateway curl -s --proxy http://host.docker.internal:7897 --connect-timeout 5 https://www.google.com > /dev/null 2>&1 && echo "│  ✓ Google 可达" || echo "│  ✗ Google 不可达"
	@echo "├─ Claude API 代理 (15721) ──────────────────────────────────┤"
	@docker compose -f $(COMPOSE_FILE) exec -T openclaw-gateway curl -s --proxy http://host.docker.internal:15721 --connect-timeout 5 https://api.anthropic.com/v1/messages -X POST -H "x-api-key: test" -H "content-type: application/json" -d '{"model":"claude-3-opus-20240229","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}' 2>&1 | head -1 | grep -q "invalid_api_key" && echo "│  ✓ Claude API 代理工作正常" || echo "│  ⚠ Claude API 代理未响应或配置错误"
	@echo "└─────────────────────────────────────────────────────────────┘"

# ============================================================
# 备份与恢复
# ============================================================

BACKUP_DIR := ~/.openclaw-backups

backup-config: ## 备份配置文件
	@echo "==> 备份 OpenClaw 配置..."
	@mkdir -p $(BACKUP_DIR)
	@TIM=$$(date +%Y%m%d-%H%M%S); \
		echo "┌─ 备份 Agent 配置 ─────────────────────────────────────────────┐"; \
		echo "│  备份 main agent..."; \
		tar -czf $(BACKUP_DIR)/main-agent-$$TIM.tar.gz \
			-C $(HOME)/.openclaw/agents/main/agent . 2>/dev/null && \
			echo "│  ✓ main: main-agent-$$TIM.tar.gz" || \
			echo "│  ✗ main: 无配置"; \
		echo "│  备份 codex agent..."; \
		tar -czf $(BACKUP_DIR)/codex-agent-$$TIM.tar.gz \
			-C $(HOME)/.openclaw/agents/codex/agent . 2>/dev/null && \
			echo "│  ✓ codex: codex-agent-$$TIM.tar.gz" || \
			echo "│  ✗ codex: 无配置"; \
		echo "├─ 备份主配置 ─────────────────────────────────────────────────┤"; \
		cp $(HOME)/.openclaw/openclaw.json $(BACKUP_DIR)/openclaw-$$TIM.json 2>/dev/null && \
			echo "│  ✓ openclaw.json -> openclaw-$$TIM.json" || \
			echo "│  ✗ openclaw.json 不存在"; \
		echo "└─────────────────────────────────────────────────────────────┘"; \
		echo ""; \
		echo "✓ 备份完成: $(BACKUP_DIR)"; \
		echo ""; \
		echo "可用备份:"; \
		ls -lht $(BACKUP_DIR) | head -10

restore-config: ## 恢复配置文件 (用法: make restore-config FILE=xxx.tar.gz)
ifndef FILE
	@echo "用法: make restore-config FILE=<备份文件名>"
	@echo ""
	@echo "示例:"
	@echo "  make restore-config FILE=main-agent-20260307-120000.tar.gz"
	@echo "  make restore-config FILE=codex-agent-20260307-120000.tar.gz"
	@echo "  make restore-config FILE=openclaw-20260307-120000.json"
	@echo ""
	@echo "可用备份:"
	@ls -lht $(BACKUP_DIR) 2>/dev/null | head -10 || echo "  (无备份)"
	@exit 1
endif
	@if [ ! -f "$(BACKUP_DIR)/$(FILE)" ]; then \
		echo "✗ 备份文件不存在: $(BACKUP_DIR)/$(FILE)"; \
		exit 1; \
	fi
	@echo "⚠️  警告: 将覆盖当前配置!"
	@echo "文件: $(FILE)"
	@echo "按 Ctrl+C 取消，或按 Enter 继续..."
	@read confirm
	@echo "==> 恢复配置..."
	@if [[ "$(FILE)" == *agent*.tar.gz ]]; then \
		AGENT=$$(echo "$(FILE)" | sed 's/-agent-.*//'); \
		echo "恢复 $$AGENT agent 配置..."; \
		mkdir -p $(HOME)/.openclaw/agents/$$AGENT/agent; \
		tar -xzf $(BACKUP_DIR)/$(FILE) -C $(HOME)/.openclaw/agents/$$AGENT/agent; \
		echo "✓ $$AGENT agent 配置已恢复"; \
	elif [[ "$(FILE)" == *.json ]]; then \
		echo "恢复主配置文件..."; \
		cp $(BACKUP_DIR)/$(FILE) $(HOME)/.openclaw/openclaw.json; \
		echo "✓ 主配置已恢复"; \
	else \
		echo "✗ 未知备份格式"; \
		exit 1; \
	fi
	@echo ""
	@echo "提示: 运行 'make restart' 使配置生效"

# ============================================================
# 维护
# ============================================================

update: ## 从 GitHub Release 更新源码
	@echo "==> 更新 OpenClaw 源码..."
	@chmod +x update-source.sh
	@./update-source.sh

check-deps: ## 检查依赖状态
	@echo "==> 检查依赖..."
	@echo "┌─ 宿主机依赖 ───────────────────────────────────────────────┐"
	@command -v docker >/dev/null 2>&1 && echo "│  ✓ Docker: $$(docker --version | cut -d' ' -f3)" || echo "│  ✗ Docker 未安装"
	@command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 && echo "│  ✓ Docker Compose: $$(docker compose version --short)" || echo "│  ✗ Docker Compose 未安装"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "┌─ 代理服务 ─────────────────────────────────────────────────┐"
	@nc -z host.docker.internal 7897 2>/dev/null && echo "│  ✓ HTTP 代理 (7897) 可达" || echo "│  ✗ HTTP 代理 (7897) 不可达"
	@nc -z host.docker.internal 15721 2>/dev/null && echo "│  ✓ Claude 代理 (15721) 可达" || echo "│  ✗ Claude 代理 (15721) 不可达"
	@echo "└─────────────────────────────────────────────────────────────┘"
