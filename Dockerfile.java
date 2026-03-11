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

# 安装 OpenJDK 21 via Eclipse Temurin
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries && \
    if [ "$APT_MIRROR" != "deb.debian.org" ]; then \
    sed -i "s/deb.debian.org/$APT_MIRROR/g" /etc/apt/sources.list.d/debian.sources || \
    sed -i "s/deb.debian.org/$APT_MIRROR/g" /etc/apt/sources.list; \
    fi && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o Acquire::Retries=3 \
    wget apt-transport-https gnupg && \
    mkdir -p /etc/apt/keyrings && \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(cat /etc/os-release | grep VERSION_CODENAME | cut -d= -f2) main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends temurin-21-jdk && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -sf $(ls -d /usr/lib/jvm/temurin-21-jdk-*) /usr/lib/jvm/java-21
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
