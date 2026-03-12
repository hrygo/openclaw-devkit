# OpenClaw Docker 构建架构与流程

本项目采用了 **分层运行时 (Hierarchical Runtime)** 架构，通过将静态 SDK 环境与动态应用安装分离，实现了极致的构建速度和缓存利用率。

## 1. 核心架构图 (分层逻辑)

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ 层级 III: 产品发布层 (Product Layer) - 构建频率: 高                         │
│ 镜像: openclaw-devkit:latest, :go, :java, :office                   │
│ 内容: 执行 openclaw.ai/install.sh (官方 Release)                          │
└───────────────────┬───────────────────────────────────┬──────────────────┘
                    │ (FROM)                            │ (FROM)
┌───────────────────┴───────────────────────────────────┴──────────────────┐
│ 层级 II: 技术栈运行时 (Stack Runtimes) - 构建频率: 低                      │
│ 镜像: openclaw-runtime:go, :java, :office                                │
│ 内容: Go SDK 1.26.1, JDK 21, LibreOffice, Python IDP libs                │
└───────────────────────────────────┬──────────────────────────────────────┘
                                    │ (FROM)
┌───────────────────────────────────┴──────────────────────────────────────┐
│ 层级 I: 基础设施层 (Base Foundation) - 构建频率: 极低                      │
│ 镜像: openclaw-runtime:base                                              │
│ 内容: Debian Bookworm Slim, Node.js 22, Bun, uv, Playwright Deps         │
└──────────────────────────────────────────────────────────────────────────┘
```

## 2. 本地构建流程 (Local Build Flow)

开发者通过 `Makefile` 进行本地驱动：

```text
 用户命令:  make build go
           │
           ▼
 [Makefile] 自动逻辑选择:
 1. 检查是否存在 openclaw-runtime:go
 2. 执行: docker build -f Dockerfile 
          --build-arg BASE_IMAGE=openclaw-runtime:go 
          -t openclaw-go .
           │
           ▼
 [Dockerfile] 内部动作:
 1. 继承 runtime:go (包含所有 SDK，跳过下载)
 2. 运行 curl | bash (安装应用)
 3. 产出镜像: [openclaw-go:latest]
```

## 3. GitHub CI 构建流程 (CI/CD Pipeline)

由 `.github/workflows/docker-publish.yml` 驱动，利用 Job 依赖并行构建：

```text
[Job: prepare] ────────────────┐
      │                        │
      ▼                        ▼
[Job: build-runtime-base]      │ (感知版本)
      │                        │
      ▼                        │
[Job: build-runtime-stacks] ───┤ (并行构建 go/java/office)
      │                        │
      ▼                        │
[Job: build-products] <────────┘ (并行拉取对应的 stack 并安装应用)
      │
      ▼
[产物推送至 GHCR]:
  - ghcr.io/hrygo/openclaw-runtime:base
  - ghcr.io/hrygo/openclaw-runtime:go / java / office
  - ghcr.io/hrygo/openclaw-devkit:latest
  - ghcr.io/hrygo/openclaw-devkit:go
  - ... 等
```

## 4. 架构优势总结

1.  **DRY (Don't Repeat Yourself)**: 所有的 Docker 构建逻辑收拢在 `Makefile`，`docker-setup.sh` 只负责环境初始化。
2.  **SOLID (Single Responsibility)**: 
    - `Dockerfile.base`: 只管 OS 和通用工具。
    - `Dockerfile.stacks`: 只管 SDK 环境。
    - `Dockerfile`: 只管应用安装。
3.  **极速缓存**: 更新 OpenClaw 版本时，Layer I 和 Layer II 的数 GB 数据完全来源于本地缓存，无需重新下载或安装。
