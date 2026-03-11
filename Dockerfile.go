# syntax=docker/dockerfile:1

# ============================================================
# OpenClaw 1+2 架构 - Go 扩展版
# 基于 openclaw:dev (Standard) 镜像构建
# ============================================================
ARG BASE_IMAGE=openclaw-devkit:dev
ARG GO_VERSION=1.24.2
ARG GOLANGCI_LINT_VERSION=2.11.3
ARG APT_MIRROR=deb.debian.org

# 继承自标准版镜像
FROM ${BASE_IMAGE}

USER root

# ============================================================
# Go 1.26 工具链安装
# ============================================================
# 配置高速镜像和 Apt 重试
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries && \
    if [ "$APT_MIRROR" != "deb.debian.org" ]; then \
    sed -i "s/deb.debian.org/$APT_MIRROR/g" /etc/apt/sources.list.d/debian.sources || \
    sed -i "s/deb.debian.org/$APT_MIRROR/g" /etc/apt/sources.list; \
    fi

RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -C /usr/local -xz && \
    ln -sf /usr/local/go/bin/go /usr/local/bin/go && \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH=/home/node/go
ENV PATH="${GOPATH}/bin:${PATH}"

# ============================================================
# Go 开发工具 (golangci-lint, gopls, dlv, etc.)
# ============================================================
RUN curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh" | \
    sh -s -- -b /usr/local/bin "v${GOLANGCI_LINT_VERSION}"

# Go 工具安装 (并发提速)
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

RUN mkdir -p "${GOPATH}/bin" && chown -R node:node "${GOPATH}" && \
    # 使用 node 用户安装 Go 工具
    if [ "$APT_MIRROR" != "deb.debian.org" ]; then \
    sudo -u node PATH=$PATH:/usr/local/go/bin GOPATH=$GOPATH go env -w GOPROXY=https://goproxy.cn,direct; \
    fi && \
    sudo -u node PATH=$PATH:/usr/local/go/bin GOPATH=$GOPATH go install -v $GO_TOOLS

# 切换回 node 用户
USER node
WORKDIR /app
