# syntax=docker/dockerfile:1

# ============================================================
# OpenClaw 1+3 DRY 架构 - Java 扩展版
# 基于 openclaw:dev (Standard) 镜像构建
# ============================================================
ARG BASE_IMAGE=openclaw-devkit:dev
ARG SPRING_BOOT_VERSION=3.5.3
ARG APT_MIRROR=deb.debian.org

# 继承自标准版镜像
FROM ${BASE_IMAGE}

USER root

# ============================================================
# Java 开发工具链 (JDK 21 LTS, Gradle, Maven)
# ============================================================

# 安装 OpenJDK 21 via Eclipse Temurin (直接下载 tar.gz，避免 apt 仓库在多平台 buildx 中不稳定)
RUN set -eux && \
    ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
        amd64) TEMURIN_ARCH="x64" ;; \
        arm64) TEMURIN_ARCH="aarch64" ;; \
        *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    TEMURIN_URL=$(curl -fsSL \
        "https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=${TEMURIN_ARCH}&image_type=jdk&jvm_impl=hotspot&os=linux&vendor=eclipse" \
        | grep -o '"link":"[^"]*"' | head -1 | cut -d'"' -f4) && \
    curl -fsSL "$TEMURIN_URL" | tar -xz -C /opt && \
    JDK_DIR=$(ls -d /opt/jdk-21*) && \
    ln -sf "$JDK_DIR" /usr/lib/jvm/java-21
ENV JAVA_HOME=/usr/lib/jvm/java-21
ENV PATH="${JAVA_HOME}/bin:${PATH}"
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -Dfile.encoding=UTF-8"

# 安装 Gradle 8.14
RUN wget -q https://services.gradle.org/distributions/gradle-8.14-bin.zip -O /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt && \
    ln -sf /opt/gradle-8.14/bin/gradle /usr/local/bin/gradle && \
    rm /tmp/gradle.zip

# 安装 Maven 3.9.9
RUN wget -q https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz -O /tmp/maven.tar.gz && \
    tar -xzf /tmp/maven.tar.gz -C /opt && \
    ln -sf /opt/apache-maven-3.9.9/bin/mvn /usr/local/bin/mvn && \
    rm /tmp/maven.tar.gz

# 切换回 node 用户
USER node
WORKDIR /app
