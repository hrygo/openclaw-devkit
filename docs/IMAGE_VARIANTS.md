# 镜像变体对比指南

1+3 阶梯架构：1个基座镜像 + 3类技术栈堆栈。

---

## 1. 架构

```
openclaw-runtime:base
    │
    ├─> openclaw-runtime:go     ──> openclaw-devkit:go
    ├─> openclaw-runtime:java   ──> openclaw-devkit:java
    ├─> openclaw-runtime:office ──> openclaw-devkit:office
    └─> openclaw-devkit:latest
```

---

## 2. 镜像命名

| 变体 | 本地构建 | Docker Registry |
| :--- | :--- | :--- |
| latest | `openclaw-devkit:latest` | `ghcr.io/hrygo/openclaw-devkit:latest` |
| go | `openclaw-devkit:go` | `ghcr.io/hrygo/openclaw-devkit:go` |
| java | `openclaw-devkit:java` | `ghcr.io/hrygo/openclaw-devkit:java` |
| office | `openclaw-devkit:office` | `ghcr.io/hrygo/openclaw-devkit:office` |

---

## 3. 工具对比

### 3.1 运行时

| 组件 | dev | go | java | office |
| :--- | :---: | :---: | :---: | :---: |
| Node.js 22 | ✅ | ✅ | ✅ | ✅ |
| Python 3 | ✅ | ✅ | ✅ | ✅ |
| Go 1.26 | ✅ | ✅ | ✅ | ✅ |
| JDK 21 | ❌ | ❌ | ✅ | ❌ |
| Gradle 8.14 | ❌ | ❌ | ✅ | ❌ |

### 3.2 AI 工具（全部版本）

Claude Code | OpenCode | Pi-Mono | uv | Playwright | GitHub CLI

### 3.3 Go 工具链

golangci-lint | gopls | dlv | staticcheck | gosec | air | mockgen

### 3.4 办公工具

LibreOffice | OCRmyPDF | Tesseract | Docling | Marker-PDF | pandas | polars

---

## 4. 适用场景

| 需求 | 推荐 |
| :--- | :--- |
| 通用开发 | **latest** |
| Go 后端 | **go** |
| Java/Spring | **java** |
| 文档处理/RAG | **office** |

---

## 5. 命令

```bash
# 安装
make install           # 标准版（优先使用本地镜像）
make install go
make install java
make install office

# 切换与更新
make rebuild go        # 检测并拉取最新镜像，重启容器
make build java        # 仅构建（若本地已有镜像则跳过构建直接下载或基于缓存）
```
