# syntax=docker/dockerfile:1
ARG BASE_IMAGE=openclaw-runtime:base

# ============================================================
# OpenClaw Application Layer
# ============================================================
FROM ${BASE_IMAGE}

ARG INSTALL_BROWSER=1

ENV NODE_ENV=production
ENV OPENCLAW_PREFER_PNPM=1

# ==============================================================================
# Layer 1: Base Configuration (rarely changes)
# - Directory creation and permissions
# - Package manager configuration
# - Environment variables
# ==============================================================================

# Create directories and configure package managers in single layer
RUN mkdir -p /home/node/.global && \
    mkdir -p /home/node/.local/lib && \
    mkdir -p /home/node/.local/bin && \
    chown -R node:node /home/node/.global && \
    chown -R node:node /home/node/.local && \
    # npm config
    npm config set prefix '/home/node/.global' && \
    npm config set cache '/home/node/.global/_npm-cache' && \
    # pnpm config
    pnpm config set global-dir '/home/node/.global/pnpm' && \
    pnpm config set global-bin-dir '/home/node/.global/bin'

# Environment variables
ENV BUN_INSTALL_PREFIX=/home/node/.global
ENV UV_NO_PROGRESS=1
ENV UV_LINK_MODE=copy
# Base PATH - variant-specific paths added via /etc/profile.d
ENV PATH="/home/node/.opencode/bin:/home/node/.global/bin:/home/node/.local/bin:${PATH}"

# Variant-specific environment setup (Go/Java)
# Detect variant from BASE_IMAGE and configure paths
RUN mkdir -p /etc/profile.d && \
    # Check if base image contains Go (openclaw-runtime:go)
    if echo "${BASE_IMAGE}" | grep -q "openclaw-runtime:go"; then \
        echo 'export PATH="/usr/local/go/bin:/home/node/go/bin:$PATH"' >> /etc/profile.d/variant-env.sh; \
        echo 'export GOPATH=/home/node/go' >> /etc/profile.d/variant-env.sh; \
        echo 'export GOPROXY=https://goproxy.cn,direct' >> /etc/profile.d/variant-env.sh; \
    fi && \
    # Check if base image contains Java (openclaw-runtime:java)
    if echo "${BASE_IMAGE}" | grep -q "openclaw-runtime:java"; then \
        echo 'export PATH="/usr/lib/jvm/java-21/bin:$PATH"' >> /etc/profile.d/variant-env.sh; \
        echo 'export JAVA_HOME=/usr/lib/jvm/java-21' >> /etc/profile.d/variant-env.sh; \
    fi

ENV npm_config_prefix=/home/node/.global
ENV pnpm_config_global_dir=/home/node/.global/pnpm
ENV pnpm_config_global_bin_dir=/home/node/.global/bin

# Fix PATH for login shells - append global bin to PATH in /etc/profile
RUN echo '' >> /etc/profile && \
    echo '# OpenClaw: add global bin to PATH' >> /etc/profile && \
    echo 'export PATH="/home/node/.opencode/bin:/home/node/.global/bin:/home/node/.local/bin:$PATH"' >> /etc/profile

# ==============================================================================
# Layer 2: Static Files
# ==============================================================================

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Bake best-practice shell environment
COPY .bashrc.devkit /home/node/.bashrc
RUN chown node:node /home/node/.bashrc

# ==============================================================================
# Layer 3: Frequently Updated Tools (TOP LAYER)
# - All CLI tools (npm + Python) in single layer
# - Using cache mount for faster installs
# - Use --build-arg CLI_VERSION=xxx to force rebuild
# ==============================================================================

ARG CLI_VERSION=1
ARG OPENCLAW_VERSION=latest
ARG INSTALL_AI_TOOLS=1

# Install Python tools (notebooklm-py) - only if python3 available
RUN if command -v python3 >/dev/null 2>&1 && command -v uv >/dev/null 2>&1; then \
        uv pip install --system --break-system-packages --no-cache notebooklm-py; \
    fi

# Helper function for retry npm install with exponential backoff
RUN --mount=type=cache,target=/root/.npm,uid=1000,gid=1000 \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 60000 && \
    npm config set fetch-retry-maxtimeout 300000 && \
    npm config set socket-timeout 120000

# Layer 3a: Core CLI tools (always installed)
# Essential: openclaw (gateway) + openclaw-lark (Lark integration) + clawhub (Hub)
# Retry wrapper handles ETIMEDOUT/network errors with exponential backoff
RUN --mount=type=cache,target=/root/.npm,uid=1000,gid=1000 \
    sh -c ' \
    npm_retry() { \
        local max_attempts=3 delay=30 attempt=1; \
        while [ $attempt -le $max_attempts ]; do \
            echo "[npm-retry attempt $attempt/$max_attempts] $*"; \
            if "$@"; then \
                echo "[npm-retry] SUCCESS"; return 0; \
            else \
                local ec=$?; \
                if [ $ec -eq 146 ] || [ $ec -eq 143 ] || [ $ec -eq 137 ]; then \
                    echo "[npm-retry] Process killed (signal $ec), retrying..."; \
                else \
                    echo "[npm-retry] Exit $ec, retrying..."; \
                fi; \
                [ $attempt -lt $max_attempts ] && echo "[npm-retry] Waiting ${delay}s..." && sleep $delay; \
                delay=$((delay * 2)); attempt=$((attempt + 1)); \
            fi; \
        done; \
        echo "[npm-retry] FAILED after $max_attempts attempts"; return 1; \
    }; \
    npm_retry npm install -g openclaw@${OPENCLAW_VERSION} && \
    npm_retry npm install -g @larksuite/openclaw-lark@latest && \
    npm_retry npm install -g clawhub@latest && \
    chown -R node:node /home/node/.global'

# Layer 3b: AI Coding Tools (optional, ~500MB, skip for office variant)
# Includes: claude-code, pi-coding-agent, opencode
# Set INSTALL_AI_TOOLS=0 when building office variant
RUN --mount=type=cache,target=/root/.npm,uid=1000,gid=1000 \
    if [ "${INSTALL_AI_TOOLS}" = "1" ]; then \
    sh -c ' \
    npm_retry() { \
        local max_attempts=3 delay=30 attempt=1; \
        while [ $attempt -le $max_attempts ]; do \
            echo "[npm-retry attempt $attempt/$max_attempts] $*"; \
            if "$@"; then \
                echo "[npm-retry] SUCCESS"; return 0; \
            else \
                local ec=$?; \
                if [ $ec -eq 146 ] || [ $ec -eq 143 ] || [ $ec -eq 137 ]; then \
                    echo "[npm-retry] Process killed (signal $ec), retrying..."; \
                else \
                    echo "[npm-retry] Exit $ec, retrying..."; \
                fi; \
                [ $attempt -lt $max_attempts ] && echo "[npm-retry] Waiting ${delay}s..." && sleep $delay; \
                delay=$((delay * 2)); attempt=$((attempt + 1)); \
            fi; \
        done; \
        echo "[npm-retry] FAILED after $max_attempts attempts"; return 1; \
    }; \
    npm_retry npm install -g @anthropic-ai/claude-code@latest && \
    npm_retry npm install -g @mariozechner/pi-coding-agent && \
    chown -R node:node /home/node/.global; \
    fi

# Install OpenCode CLI - AI coding tool, also controlled by INSTALL_AI_TOOLS
RUN if [ "${INSTALL_AI_TOOLS}" = "1" ]; then \
    mkdir -p /home/node/.opencode/bin && \
    chown -R node:node /home/node/.opencode && \
    runuser -u node -- sh -c 'curl -fsSL https://opencode.ai/install | INSTALL_DIR=/home/node/.opencode/bin bash'; \
    fi

# ==============================================================================
# Layer 4: Optional Components
# ==============================================================================

RUN if [ "${INSTALL_BROWSER}" = "1" ]; then \
    mkdir -p /home/node/.cache/ms-playwright && \
    npx playwright install --with-deps chromium && \
    chown -R node:node /home/node/.cache/ms-playwright; \
    fi

ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright

# Healthcheck
HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

EXPOSE 18789 18790

# Ensure /home/node/.notebooklm exists (will be replaced by bind mount at runtime if host path exists)
RUN mkdir -p /home/node/.notebooklm

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["openclaw", "gateway", "--allow-unconfigured"]
USER node
