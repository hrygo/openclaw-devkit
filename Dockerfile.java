# OpenClaw 开发环境定制镜像 (Java 增强版)
# 基于 Dockerfile.dev，增加 Java/JVM 技术栈开发工具
# 集成多语言开发栈: TypeScript (主) + Go + Python + Java
#
# 构建命令:
#   make build-java
#
# 重建并启动:
#   make rebuild-java
#
# 手动运行镜像 (自定义镜像名):
#   OPENCLAW_IMAGE=openclaw:dev-java make up

FROM debian:latest

LABEL org.opencontainers.image.base.name="docker.io/library/debian:latest" \
  org.opencontainers.image.source="https://github.com/openclaw/openclaw" \
  org.opencontainers.image.title="OpenClaw Dev (2025 Java Enhanced)" \
  org.opencontainers.image.description="OpenClaw gateway with 2025 toolchain (Node 22 LTS, Go 1.26, Python 3.13, Java 25)"

# ============================================================
# 第一阶段：安装系统依赖和开发工具链
# ============================================================

ENV DEBIAN_FRONTEND=noninteractive

# 开发工具 + Office 处理依赖 + 浏览器自动化依赖
ARG HTTP_PROXY
ARG HTTPS_PROXY
ENV http_proxy=$HTTP_PROXY
ENV https_proxy=$HTTPS_PROXY

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o Acquire::Retries=3 \
  curl wget jq git ripgrep fd-find bat httpie python3 python3-pip python3-venv build-essential pkg-config \
  pandoc texlive-latex-base texlive-fonts-recommended xvfb libnss3 libatk-bridge2.0-0t64 libdrm2 libxkbcommon0 \
  libgbm1 libasound2t64 libatspi2.0-0t64 libxshmfence1 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
  libdbus-1-3 libgtk-3-0t64 fonts-liberation fonts-noto-color-emoji unzip file sqlite3 zip || \
  (apt-get update --fix-missing && DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-missing --no-install-recommends -o Acquire::Retries=5 \
  curl wget jq git ripgrep fd-find bat httpie python3 python3-pip python3-venv build-essential pkg-config \
  pandoc texlive-latex-base texlive-fonts-recommended xvfb libnss3 libatk-bridge2.0-0t64 libdrm2 libxkbcommon0 \
  libgbm1 libasound2t64 libatspi2.0-0t64 libxshmfence1 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
  libdbus-1-3 libgtk-3-0t64 fonts-liberation fonts-noto-color-emoji unzip file sqlite3 zip)

# ============================================================
# Node.js 22 LTS 手动安装
# ============================================================
ARG NODE_VERSION=22.22.1
RUN ARCH=$(dpkg --print-architecture) && \
  curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.xz" | tar -xJ -C /usr/local --strip-components=1 && \
  groupadd --gid 1000 node && \
  useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# ============================================================
# Go 1.26 (Latest Stable 2025)
# ============================================================
# https://go.dev/dl/
ARG GO_VERSION=1.26.1
RUN ARCH=$(dpkg --print-architecture) && \
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -C /usr/local -xz && \
  ln -sf /usr/local/go/bin/go /usr/local/bin/go && \
  ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH=/home/node/go
ENV PATH="${GOPATH}/bin:${PATH}"

# ============================================================
# GitHub CLI 最新版 (apt 版本过旧: 2.23.0)
# ============================================================
# https://github.com/cli/cli/releases
RUN ARCH=$(dpkg --print-architecture) && \
  GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
  curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.deb" -o /tmp/gh.deb && \
  apt-get update && apt-get install -y /tmp/gh.deb && \
  rm /tmp/gh.deb && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# ============================================================
# 第二阶段：安装语言运行时和包管理器
# ============================================================

# Bun (TypeScript 运行时，比 Node 更快)
ENV BUN_INSTALL=/opt/bun
ENV PATH="${BUN_INSTALL}/bin:${PATH}"
RUN curl -fsSL https://bun.sh/install | bash && \
  ln -sf "${BUN_INSTALL}/bin/bun" /usr/local/bin/bun

# pnpm (Node 包管理器)
RUN corepack enable && corepack prepare pnpm@latest --activate

# Playwright CLI (浏览器自动化命令行工具)
RUN npm install -g @playwright/test@latest

# Claude Code CLI (Anthropic 官方 CLI 工具)
RUN npm install -g @anthropic-ai/claude-code@latest

# OpenCode & Pi-Mono AI Agent 工具
RUN npm install -g opencode-ai @mariozechner/pi-coding-agent

# Python 包 (Office 处理 + 知识库工具)
ARG PYTHON_PACKAGES="\
  python-pptx \
  openpyxl \
  python-docx \
  beautifulsoup4 \
  lxml \
  pyyaml \
  pandoc"
RUN pip3 install --break-system-packages $PYTHON_PACKAGES

# ============================================================
# Go 开发工具链 (golangci-lint, gopls, dlv, etc.)
# ============================================================
# golangci-lint: 综合性 linter (https://golangci-lint.run/)
ARG GOLANGCI_LINT_VERSION=1.64.8
RUN ARCH=$(dpkg --print-architecture) && \
  curl -fsSL "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_LINT_VERSION}/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}.tar.gz" | \
  tar -xz -C /tmp && \
  mv /tmp/golangci-lint-${GOLANGCI_LINT_VERSION}-linux-${ARCH}/golangci-lint /usr/local/bin/ && \
  rm -rf /tmp/golangci-lint-*

# Go 工具安装 (需要 GOPATH 已设置)
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

RUN mkdir -p "${GOPATH}/bin" && \
  for tool in ${GO_TOOLS}; do \
  echo "Installing $tool..." && \
  go install "$tool"; \
  done && \
  # 清理 Go 模块缓存减小镜像体积
  go clean -modcache

# ============================================================
# Java 开发工具链 (JDK 25 LTS, Gradle, Maven, etc.)
# 2026 Java 开发最佳实践
# ============================================================

# SDKMAN 安装 (Java SDK 版本管理器)
# https://sdkman.io/
ENV SDKMAN_DIR=/home/node/.sdkman
RUN curl -fsSL "https://get.sdkman.io" | bash

# JDK 25 LTS, Gradle, Maven 安装
# 2026 Java 开发最佳实践: 使用 Eclipse Temurin (tem) 并清理缓存
ARG JDK_VERSION=25
ARG JDK_VENDOR=tem
ARG GRADLE_VERSION=8.14
ARG MAVEN_VERSION=3.9.9

# JDK 25 LTS, Gradle, Maven cache mounts
RUN --mount=type=cache,target=/home/node/.sdkman/archives,uid=1000,gid=1000 \
  bash -c "source ${SDKMAN_DIR}/bin/sdkman-init.sh && \
  sdk install java ${JDK_VERSION}-${JDK_VENDOR} && \
  sdk install gradle ${GRADLE_VERSION} && \
  sdk install maven ${MAVEN_VERSION}"

ENV JAVA_HOME=${SDKMAN_DIR}/candidates/java/current
ENV PATH="${JAVA_HOME}/bin:${SDKMAN_DIR}/candidates/gradle/current/bin:${SDKMAN_DIR}/candidates/maven/current/bin:${PATH}"
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -Dfile.encoding=UTF-8"


# 安装 Java 开发工具 (Spring Boot, Formatter, Linter, etc.)
ARG SPRING_BOOT_VERSION=3.5.3
ARG GOOGLE_JAVA_FORMAT_VERSION=1.27.0
ARG CHECKSTYLE_VERSION=10.23.1
ARG PMD_VERSION=7.12.0
ARG SPOTBUGS_VERSION=4.9.3

RUN mkdir -p /home/node/.local/bin /home/node/.local/lib && \
  # Spring Boot CLI (from Maven Central)
  curl -fsSL "https://repo1.maven.org/maven2/org/springframework/boot/spring-boot-cli/${SPRING_BOOT_VERSION}/spring-boot-cli-${SPRING_BOOT_VERSION}-bin.tar.gz" | \
  tar -xz -C /home/node/.local && \
  ln -sf /home/node/.local/spring-${SPRING_BOOT_VERSION}/bin/spring /home/node/.local/bin/spring && \
  # Google Java Format
  curl -fsSL "https://github.com/google/google-java-format/releases/download/v${GOOGLE_JAVA_FORMAT_VERSION}/google-java-format-${GOOGLE_JAVA_FORMAT_VERSION}-all-deps.jar" \
  -o /home/node/.local/lib/google-java-format.jar && \
  printf '#!/bin/bash\njava -jar /home/node/.local/lib/google-java-format.jar "$@"' > /home/node/.local/bin/google-java-format && \
  # Checkstyle
  curl -fsSL "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-${CHECKSTYLE_VERSION}/checkstyle-${CHECKSTYLE_VERSION}-all.jar" \
  -o /home/node/.local/lib/checkstyle.jar && \
  printf '#!/bin/bash\njava -jar /home/node/.local/lib/checkstyle.jar "$@"' > /home/node/.local/bin/checkstyle && \
  # PMD
  curl -fsSL "https://github.com/pmd/pmd/releases/download/pmd_releases%2F${PMD_VERSION}/pmd-dist-${PMD_VERSION}-bin.zip" -o /tmp/pmd.zip && \
  unzip /tmp/pmd.zip -d /home/node/.local && rm /tmp/pmd.zip && \
  ln -sf /home/node/.local/pmd-bin-${PMD_VERSION}/bin/pmd /home/node/.local/bin/pmd && \
  # SpotBugs
  curl -fsSL "https://github.com/spotbugs/spotbugs/releases/download/${SPOTBUGS_VERSION}/spotbugs-${SPOTBUGS_VERSION}.tgz" | \
  tar -xz -C /home/node/.local && \
  ln -sf /home/node/.local/spotbugs-${SPOTBUGS_VERSION}/bin/spotbugs /home/node/.local/bin/spotbugs && \
  # 修改权限
  chmod +x /home/node/.local/bin/* && \
  chown -R node:node /home/node/.local /home/node/.sdkman

ENV PATH="/home/node/.local/bin:${PATH}"


# ============================================================
# 第三阶段：安装 OpenClaw 核心组件
# ============================================================

WORKDIR /app
RUN chown node:node /app

# 复制依赖声明文件（利用 Docker 层缓存）
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

USER node
# 2026 pnpm cache mount
RUN --mount=type=cache,target=/home/node/.local/share/pnpm/store,uid=1000,gid=1000 \
  NODE_OPTIONS=--max-old-space-size=2048 pnpm install --frozen-lockfile

# 安装 Chromium for Playwright (可选，约 300MB)
ARG INSTALL_BROWSER=1
USER root
RUN if [ "${INSTALL_BROWSER}" = "1" ]; then \
  mkdir -p /home/node/.cache/ms-playwright && \
  PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
  node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
  chown -R node:node /home/node/.cache/ms-playwright; \
  fi
USER node

# 复制源代码并构建
COPY --chown=node:node . .
RUN for dir in /app/extensions /app/.agent /app/.agents; do \
  if [ -d "$dir" ]; then \
  find "$dir" -type d -exec chmod 755 {} +; \
  find "$dir" -type f -exec chmod 644 {} +; \
  fi; \
  done
RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# 暴露 CLI
USER root
RUN ln -sf /app/openclaw.mjs /usr/local/bin/openclaw \
  && chmod 755 /app/openclaw.mjs

# ============================================================
# 第四阶段：生产环境配置
# ============================================================

ENV NODE_ENV=production
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright

USER node

# 健康检查
HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# 默认启动 Gateway
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
