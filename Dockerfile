# syntax=docker/dockerfile:1

# ============================================================
# 全局构建参数 (跨所有阶段)
# ============================================================
ARG BUN_VERSION=1.3.10
ARG GO_VERSION=1.26.1
ARG GOLANGCI_LINT_VERSION=1.64.8
ARG PYTHON_PACKAGES="python-pptx openpyxl python-docx beautifulsoup4 lxml pyyaml pandoc"
ARG INSTALL_BROWSER=1

# OpenClaw 开发环境定制镜像 (标准开发版)
# 基于 debian:stable-slim，集成多语言开发栈
#
# 包含工具链: Node.js 22, Go 1.26, Python 3, Bun, pnpm
# 集成开发工具: Playwright, Claude Code, OpenCode
#
# 构建命令:
#   docker build -t openclaw:dev -f Dockerfile .
#
# GitHub CI 优化版本 - 使用官方源，无代理依赖

# ============================================================
# 阶段 1：构建依赖 (builder) - 安装所有开发工具
# ============================================================
FROM debian:stable-slim AS builder

# 定义所有构建参数 (确保每个阶段都能访问)
ARG BUN_VERSION=1.3.10
ARG GO_VERSION=1.26.1
ARG GOLANGCI_LINT_VERSION=1.64.8
ARG PYTHON_PACKAGES="python-pptx openpyxl python-docx beautifulsoup4 lxml pyyaml pandoc"
ARG INSTALL_BROWSER=1

LABEL org.opencontainers.image.base.name="docker.io/library/debian:stable-slim" \
  org.opencontainers.image.source="https://github.com/openclaw/openclaw" \
  org.opencontainers.image.title="OpenClaw Dev (2025 Standard)" \
  org.opencontainers.image.description="OpenClaw gateway with 2025 toolchain (Node 22 LTS, Go 1.26, Python 3.13)"

ENV DEBIAN_FRONTEND=noninteractive

# ============================================================
# 安装系统依赖和开发工具链
# ============================================================
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o Acquire::Retries=3 \
    curl wget jq git ripgrep fd-find bat httpie python3 python3-pip python3-venv build-essential pkg-config \
    # 文档处理导出
    pandoc texlive-latex-base texlive-fonts-recommended \
    # 浏览器自动化依赖
    xvfb libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
    libgbm1 libasound2 libatspi2.0-0 libxshmfence1 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
    libdbus-1-3 libgtk-3-0 fonts-liberation fonts-noto-color-emoji \
    # 基础工具
    unzip file sqlite3 zip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ============================================================
# Node.js 22 LTS via NodeSource
# ============================================================
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ============================================================
# Go 1.26 (Latest Stable 2025)
# ============================================================
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -C /usr/local -xz && \
    ln -sf /usr/local/go/bin/go /usr/local/bin/go && \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH=/root/go
ENV PATH="${GOPATH}/bin:${PATH}"

# ============================================================
# GitHub CLI 最新版
# ============================================================
RUN ARCH=$(dpkg --print-architecture) && \
    GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.deb" -o /tmp/gh.deb && \
    apt-get update && apt-get install -y /tmp/gh.deb && \
    rm /tmp/gh.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# ============================================================
# 阶段 1 (续): 安装语言运行时和包管理器
# ============================================================

# Bun (TypeScript 运行时)
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
    aarch64|arm64) BUN_ARCH="aarch64" ;; \
    x86_64|amd64) BUN_ARCH="x64" ;; \
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ARCH}.zip" -o /tmp/bun.zip && \
    unzip /tmp/bun.zip -d /tmp && \
    mkdir -p /root/.bun/bin && \
    mv /tmp/bun-linux-${BUN_ARCH}/bun /root/.bun/bin/bun && \
    chmod +x /root/.bun/bin/bun && \
    rm -rf /tmp/bun.zip /tmp/bun-linux-${BUN_ARCH}
ENV PATH="/root/.bun/bin:${PATH}"

# pnpm (Node 包管理器)
RUN corepack enable && corepack prepare pnpm@latest --activate

# Playwright (浏览器自动化测试框架 + CLI)
RUN npm install -g @playwright/test@latest @playwright/cli@latest

# Claude Code CLI (Anthropic 官方 CLI 工具)
RUN npm install -g @anthropic-ai/claude-code@latest

# OpenCode & Pi-Mono AI Agent 工具
RUN npm install -g opencode-ai @mariozechner/pi-coding-agent

# Python 包 (Office 处理 + 知识库工具)
RUN pip3 install --break-system-packages --no-cache-dir $PYTHON_PACKAGES

# ============================================================
# Go 开发工具链 (golangci-lint, gopls, dlv, etc.)
# ============================================================
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}.tar.gz" | \
    tar -xz -C /tmp && \
    mv /tmp/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}/golangci-lint /usr/local/bin/ && \
    rm -rf /tmp/golangci-lint-*

# Go 工具安装
ARG GO_TOOLS="\
  golang.org/x/tools/gopls@latest \
  github.com/go-delve/delve/cmd/dlv@latest \
  honnef.co/go/tools/cmd/staticcheck@latest \
  github.com/securego/gosec/v2/cmd/gosec@latest \
  golang.org/x/tools/cmd/goimports@latest \
  github.com/air-verse/air@latest \
  github.com/google/mock/mockgen@latest \
  github.com/google/wire/cmd/wire@latest \
  github.com/onsi/ginkgo/v2/ginkgo@latest"

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/root/go/pkg/mod \
    mkdir -p "${GOPATH}/bin" && \
    for tool in ${GO_TOOLS}; do \
        echo "Installing $tool..." && \
        go install "$tool"; \
    done

# ============================================================
# 阶段 1 (续): 安装 OpenClaw 核心组件并构建
# ============================================================
WORKDIR /app

# 复制依赖声明文件（利用 Docker 层缓存）
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

# 安装依赖
RUN NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

# 复制源代码并构建
COPY . .

# 构建应用
RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# ============================================================
# 阶段 2：运行时基础镜像 (base) - 仅安装运行时依赖
# ============================================================
FROM debian:stable-slim AS base

ARG BUN_VERSION=1.3.10
ARG PYTHON_PACKAGES="python-pptx openpyxl python-docx beautifulsoup4 lxml pyyaml pandoc"

ENV DEBIAN_FRONTEND=noninteractive

# 安装基础工具 (curl, ca-certificates for HTTPS)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates gnupg

# 安装 Node.js 22.x via NodeSource (more reliable for multi-arch)
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

# 安装运行时依赖
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o Acquire::Retries=3 \
    git openssl \
    # 文档处理
    pandoc texlive-latex-base texlive-fonts-recommended \
    # 浏览器自动化依赖
    xvfb libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
    libgbm1 libasound2 libatspi2.0-0 libxshmfence1 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
    libdbus-1-3 libgtk-3-0 fonts-liberation fonts-noto-color-emoji \
    # 基础工具
    python3 python3-pip python3-venv unzip file sqlite3 zip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 配置 npm 使用官方源
RUN npm install -g pnpm@latest

# 安装 Bun 运行时
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
    aarch64|arm64) BUN_ARCH="aarch64" ;; \
    x86_64|amd64) BUN_ARCH="x64" ;; \
    esac && \
    curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ARCH}.zip" -o /tmp/bun.zip && \
    unzip /tmp/bun.zip -d /tmp && \
    mv /tmp/bun-linux-${BUN_ARCH}/bun /usr/local/bin/bun && \
    chmod +x /usr/local/bin/bun && \
    rm -rf /tmp/bun.zip /tmp/bun-linux-${BUN_ARCH}

# 安装 Python 包
RUN pip3 install --break-system-packages --no-cache-dir $PYTHON_PACKAGES

# ============================================================
# 阶段 3：最终镜像 (runtime) - 复制构建产物
# ============================================================
FROM base AS runtime

WORKDIR /app

# 创建非 root 用户
RUN useradd --create-home --shell /bin/bash node || true

# 复制构建产物
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/package.json .
COPY --from=builder --chown=node:node /app/openclaw.mjs .
COPY --from=builder --chown=node:node /app/extensions ./extensions
COPY --from=builder --chown=node:node /app/skills ./skills
COPY --from=builder --chown=node:node /app/docs ./docs

# 改变目录 owner
RUN chown -R node:node /app

# 安装 Chromium for Playwright (依赖已在 base 阶段安装)
RUN if [ "${INSTALL_BROWSER}" = "1" ]; then \
    mkdir -p /home/node/.cache/ms-playwright && \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    chown -R node:node /home/node/.cache/ms-playwright; \
    fi

# 规范化扩展权限
RUN for dir in /app/extensions /app/.agent /app/.agents; do \
    if [ -d "$dir" ]; then \
    find "$dir" -type d -exec chmod 755 {} +; \
    find "$dir" -type f -exec chmod 644 {} +; \
    fi; \
    done

# 安装 Playwright CLI skills (让 Claude Code 可以调用 Playwright)
RUN mkdir -p /home/node/.claude/skills/playwright-cli/references && \
    curl -fsSL -o /home/node/.claude/skills/playwright-cli/SKILL.md \
    https://raw.githubusercontent.com/microsoft/playwright-cli/main/skills/playwright-cli/SKILL.md && \
    curl -fsSL -o /home/node/.claude/skills/playwright-cli/references/request-mocking.md \
    https://raw.githubusercontent.com/microsoft/playwright-cli/main/skills/playwright-cli/references/request-mocking.md && \
    curl -fsSL -o /home/node/.claude/skills/playwright-cli/references/running-code.md \
    https://raw.githubusercontent.com/microsoft/playwright-cli/main/skills/playwright-cli/references/running-code.md && \
    curl -fsSL -o /home/node/.claude/skills/playwright-cli/references/session-management.md \
    https://raw.githubusercontent.com/microsoft/playwright-cli/main/skills/playwright-cli/references/session-management.md && \
    curl -fsSL -o /home/node/.claude/skills/playwright-cli/references/storage-state.md \
    https://raw.githubusercontent.com/microsoft/playwright-cli/main/skills/playwright-cli/references/storage-state.md && \
    curl -fsSL -o /home/node/.claude/skills/playwright-cli/references/test-generation.md \
    https://raw.githubusercontent.com/microsoft/playwright-cli/main/skills/playwright-cli/references/test-generation.md && \
    curl -fsSL -o /home/node/.claude/skills/playwright-cli/references/tracing.md \
    https://raw.githubusercontent.com/microsoft/playwright-cli/main/skills/playwright-cli/references/tracing.md && \
    curl -fsSL -o /home/node/.claude/skills/playwright-cli/references/video-recording.md \
    https://raw.githubusercontent.com/microsoft/playwright-cli/main/skills/playwright-cli/references/video-recording.md

# 暴露 CLI
RUN ln -sf /app/openclaw.mjs /usr/local/bin/openclaw \
    && chmod 755 /app/openclaw.mjs

# 环境变量
ENV NODE_ENV=production \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    OPENCLAW_PREFER_PNPM=1

# 使用非 root 用户
USER node

# 健康检查
HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# 暴露端口
EXPOSE 18789 18790

# 启动命令
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
