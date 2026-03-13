# syntax=docker/dockerfile:1
ARG BASE_IMAGE=openclaw-runtime:base

# ============================================================
# OpenClaw Application Layer
# ============================================================
FROM ${BASE_IMAGE}

ARG INSTALL_BROWSER=1

ENV NODE_ENV=production
ENV OPENCLAW_PREFER_PNPM=1

# Install OpenClaw via npm
RUN npm install -g openclaw@latest

# Install Tier 3 Fast-Updating AI Agents
# Positioned here so updating these tools doesn't trigger a rebuild of the entire app layer
# We use root to install but ensure they are on path or globally accessible
RUN npm install -g @anthropic-ai/claude-code@latest && \
    # Install placeholder for OpenCode and Pi-Mono
    echo "Installing AI Agents..." && \
    curl -fsSL https://opencode.ai/install.sh | INSTALL_DIR=/usr/local/bin bash || true && \
    curl -fsSL https://pimono.ai/install.sh | INSTALL_DIR=/usr/local/bin bash || true

# Post-installation setup
# (redundant user creation removed - now in base)

# Set permissions for /app if it was created by the install script
# The install script usually installs to a specific path, if it follows standard conventions
# Let's assume it puts things in /usr/local/bin or similar, and/or an app dir.
# If it installs to /home/node/.openclaw, we'll handle that in entrypoint or setup.

# Install Playwright browsers if requested
RUN if [ "${INSTALL_BROWSER}" = "1" ]; then \
    mkdir -p /home/node/.cache/ms-playwright && \
    npx playwright install --with-deps chromium && \
    chown -R node:node /home/node/.cache/ms-playwright; \
    fi

# Copy local entrypoint if needed, or use the one from install script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Environment variables
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright

# Healthcheck
HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

EXPOSE 18789 18790

USER node
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["openclaw", "gateway", "--allow-unconfigured"]
