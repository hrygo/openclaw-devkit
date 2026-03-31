# OpenClaw 版本修复测试报告

## 修复内容

### 1. Dockerfile 修改
- 新增 `ARG OPENCLAW_VERSION=latest` 参数
- 修改安装命令: `npm install -g openclaw@${OPENCLAW_VERSION}`

### 2. GitHub Actions 修改
- 版本号去除 `v` 前缀（v2026.3.23 → 2026.3.23）
- 保留原始 GitHub 版本用于 tag（v2026.3.23-go）

## 验证步骤

### 本地验证
```bash
# 测试安装指定版本
docker run --rm -it --build-arg OPENCLAW_VERSION=2026.3.23-2 \
  ghcr.io/hrygo/openclaw-devkit:go openclaw --version

# 期望输出: OpenClaw 2026.3.23 (commit_hash)
```

### GitHub Actions 验证
```bash
# 触发强制发布
gh workflow run docker-publish.yml -f force_publish=true

# 查看构建日志
gh run watch
```

## 影响范围
- ✅ 修复版本不匹配问题
- ✅ 保留 latest 默认值向后兼容
- ✅ 支持 GitHub release 与 npm 版本同步

