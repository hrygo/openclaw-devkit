# Image Variants Comparison Guide

1+3 Tier Architecture: 1 base image + 3 technical stacks.

---

## 1. Architecture

```
openclaw-runtime:base
    │
    ├─> openclaw-runtime:go     ──> openclaw-devkit:go
    ├─> openclaw-runtime:java   ──> openclaw-devkit:java
    ├─> openclaw-runtime:office ──> openclaw-devkit:office
    └─> openclaw-devkit:latest
```

---

## 2. Image Naming

| Variant | Local Build | Docker Registry |
| :--- | :--- | :--- |
| latest | `openclaw-devkit:latest` | `ghcr.io/hrygo/openclaw-devkit:latest` |
| go | `openclaw-devkit:go` | `ghcr.io/hrygo/openclaw-devkit:go` |
| java | `openclaw-devkit:java` | `ghcr.io/hrygo/openclaw-devkit:java` |
| office | `openclaw-devkit:office` | `ghcr.io/hrygo/openclaw-devkit:office` |

---

## 3. Tools Comparison

### 3.1 Runtime

| Component | dev | go | java | office |
| :--- | :---: | :---: | :---: | :---: |
| Node.js 22 | ✅ | ✅ | ✅ | ✅ |
| Python 3 | ✅ | ✅ | ✅ | ✅ |
| Go 1.26 | ✅ | ✅ | ✅ | ✅ |
| JDK 21 | ❌ | ❌ | ✅ | ❌ |
| Gradle 8.14 | ❌ | ❌ | ✅ | ❌ |

### 3.2 AI Tools (All Versions)

Claude Code | OpenCode | Pi-Mono | uv | Playwright | GitHub CLI

### 3.3 Go Toolchain

golangci-lint | gopls | dlv | staticcheck | gosec | air | mockgen

### 3.4 Office Tools

LibreOffice | OCRmyPDF | Tesseract | Docling | Marker-PDF | pandas | polars

---

## 4. Use Cases

| Requirement | Recommended |
| :--- | :--- |
| General Development | **latest** |
| Go Backend | **go** |
| Java/Spring | **java** |
| Document Processing/RAG | **office** |

---

## 5. Commands

```bash
# Installation
make install           # Standard version (pre-built from registry)
make install go
make install java
make install office

# Switch & Update
make upgrade go       # Detect and pull latest image, restart container
make build java       # Build from source (local)
```
