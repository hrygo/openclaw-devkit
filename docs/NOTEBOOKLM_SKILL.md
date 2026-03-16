# OpenClaw × NotebookLM 技能集成指南

本指南介绍如何在 OpenClaw DevKit 中集成和使用 Google NotebookLM CLI 技能，实现通过自然语言操控 NotebookLM 的全部功能。

## 目录

- [功能一览](#功能一览)
- [快速开始](#快速开始)
- [架构映射图](#架构映射图)
- [使用示例](#使用示例)
- [常用命令](#常用命令)
- [故障排除](#故障排除)

---

## 功能一览

**notebooklm-py** 是 Google NotebookLM 的非官方 Python SDK 和 CLI 工具，提供：

| 功能            | 说明                                           |
| :-------------- | :--------------------------------------------- |
| 📓 Notebook 管理 | 创建、列表、重命名、删除                       |
| 📄 多格式来源    | URLs、YouTube、PDF、Word、音视频、Google Drive |
| 💬 智能对话      | 基于来源的问答、自定义人设                     |
| 🔍 研究代理      | 网页/Drive 深度研究，自动导入                  |
| 🎙️ 内容生成      | 播客、视频、幻灯片、测验、思维导图等           |
| 📥 批量导出      | MP3、MP4、PDF、PNG、CSV、JSON、Markdown        |

> ⚠️ **注意**: 此工具使用未公开的 Google API，可能随时变化。适合原型开发、研究和个人项目。

---

## 快速开始

### Step 1: 宿主机安装 CLI

```bash
# 安装 CLI 工具
pip install "notebooklm-py[browser]"

# 安装浏览器（首次登录需要）
playwright install chromium
```

### Step 2: Google 认证

```bash
# 启动浏览器登录
notebooklm login
```

执行后会自动打开浏览器窗口：

1. 登录你的 Google 账号
2. 完成身份验证
3. 认证信息自动保存到 `~/.notebooklm/storage_state.json`

**验证认证:**
```bash
notebooklm auth check --test
```

输出示例:
```
✓ Storage file exists: /Users/you/.notebooklm/storage_state.json
✓ Authentication valid
✓ API access confirmed
```

### Step 3: 宿主机安装 Skill

```bash
notebooklm skill install
```

Skill 安装到 `~/.claude/skills/notebooklm/` 目录。

### Step 4: 启动容器

```bash
make up
```

容器启动时自动：
- 挂载认证目录 → 共享 Google 认证
- 挂载 Skills 目录 → 共享 Skill 文件
- 安装 CLI 工具 → 通过 PIP_TOOLS 环境变量

**验证容器配置:**
```bash
make shell
notebooklm auth check          # ✓ 认证共享成功
ls /home/node/.claude/skills/  # notebooklm 目录存在
```

### Step 5: 复制 Skill

对 OpenClaw 说：

> 从 ~/.claude/skills 复制 notebooklm skill 到你的 skills 目录，然后告诉我你通过这个 skill 学习到了什么？

---

## 架构映射图

```
┌─────────────────────────────────────────────────────────────────┐
│                        宿主机 (Host)                             │
│                                                                 │
│  ~/.notebooklm/                                                 │
│  └── storage_state.json    ← Google 认证凭证                     │
│                                                                 │
│  ~/.claude/skills/                                              │
│  └── notebooklm/           ← Claude Code Skill                  │
│                                                                 │
└─────────────────────────┬───────────────────────────────────────┘
                          │
              ┌───────────┴───────────┐
              │  Docker Compose       │
              │  Bind Mounts (rw)     │
              ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                        容器 (Container)                          │
│                                                                 │
│  /home/node/.notebooklm/                                        │
│  └── storage_state.json    ← 认证共享 ✓                          │
│                                                                 │
│  /home/node/.claude/skills/                                     │
│  └── notebooklm/           ← Skill 挂载 ✓                        │
│                                                                 │
│  /usr/local/bin/notebooklm ← 容器启动时动态安装                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
        │
        │  Step 5: 通过对话复制
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenClaw 配置目录                              │
│                                                                 │
│  ~/.claude/skills/notebooklm/                                   │
│  └── skill.md              ← 从容器挂载目录复制                   │
│                                                                 │
│  复制后 OpenClaw 获得操控 NotebookLM 的能力                       │
└─────────────────────────────────────────────────────────────────┘

共享规则:
  • 认证文件: 直接共享 (JSON 跨平台兼容)
  • CLI 工具: 无法共享 (macOS/Windows 二进制 ≠ Linux)
  • Skill 文件: 挂载 + 复制 (文本文件跨平台兼容)
```

---

## 使用示例

### 案例 1：研究 Agent Skills 最佳实践

**场景**: 使用 NotebookLM 研究 Claude Agent Skills 最佳实践，生成播客便于通勤时收听。

**自然语言（推荐）:**

> 创建一个 Notebook "Agent Skills 最佳实践"，添加来源 https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices，生成深入讨论风格的播客并下载为 agent-skills-podcast.mp3

**等效 CLI:**

```bash
# Step 1: 创建 notebook
notebooklm create "Agent Skills 最佳实践"
# 输出: Created notebook: <notebook_id>

# Step 2: 切换到该 notebook
notebooklm use <notebook_id>

# Step 3: 添加来源（--wait 确保处理完成）
notebooklm source add "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices" --wait

# Step 4: 验证来源状态
notebooklm source list
# 确认所有来源状态为 "completed"

# Step 5: 生成播客（--wait 阻塞直到完成）
notebooklm generate audio --wait

# Step 6: 下载
notebooklm download audio agent-skills-podcast.mp3

# Step 7: 验证文件
ls -la agent-skills-podcast.mp3
```

**关键要点:**

| 要点         | 说明                                                         |
| :----------- | :----------------------------------------------------------- |
| **简洁指令** | 单句包含完整意图，OpenClaw 自动分解步骤                      |
| **进度验证** | `--wait` 标志确保异步操作完成后再继续                        |
| **错误预防** | 生成前验证 source 状态，避免空播客                           |
| **自由度**   | 自然语言=高自由度（OpenClaw 决策）；CLI=低自由度（精确控制） |

### 案例 2：批量生成学习材料

**场景**: 为一门课程生成测验题和闪卡。

> 用当前笔记本生成 20 道测验题，再生成一套闪卡，都导出 Markdown 格式

```bash
notebooklm generate quiz --quantity more
notebooklm generate flashcards --quantity more
notebooklm download quiz --format markdown quiz.md
notebooklm download flashcards --format markdown flashcards.md
```

### 案例 3：研究与自动导入

**场景**: 自动搜索并导入相关资料。

> 帮我研究 "LLM Function Calling"，搜索网页资料并导入笔记本

```bash
notebooklm source add-research "LLM Function Calling"
```

### 案例 4：生成思维导图

**场景**: 可视化知识结构。

> 生成当前笔记本的思维导图，导出 JSON 格式

```bash
notebooklm generate mind-map
notebooklm download mind-map mindmap.json
```

---

## 支持的内容类型

| 类型               | 选项                                                                            | 导出格式             |
| :----------------- | :------------------------------------------------------------------------------ | :------------------- |
| **Audio Overview** | 4 种风格 (deep-dive/brief/critique/debate)、3 种时长、50+ 语言                  | MP3/MP4              |
| **Video Overview** | 3 种风格 (explainer/brief/cinematic)、9 种视觉风格、独立 `cinematic-video` 别名 | MP4                  |
| **Slide Deck**     | 详细版/演讲版、可调长度                                                         | PDF, PPTX            |
| **Infographic**    | 3 种方向、3 种细节级别                                                          | PNG                  |
| **Quiz**           | 可配置数量和难度                                                                | JSON, Markdown, HTML |
| **Flashcards**     | 可配置数量和难度                                                                | JSON, Markdown, HTML |
| **Report**         | 简报/学习指南/博客文章/自定义提示词                                             | Markdown             |
| **Data Table**     | 自然语言定义结构                                                                | CSV                  |
| **Mind Map**       | 交互式层级可视化                                                                | JSON                 |

---

## 常用命令

```bash
# 认证
notebooklm login                    # 浏览器登录
notebooklm auth check --test        # 检查认证

# Notebook 管理
notebooklm list                     # 列出所有 notebooks
notebooklm create "名称"            # 创建新 notebook
notebooklm use <id>                 # 切换当前 notebook
notebooklm metadata --json          # 导出元数据

# 来源管理
notebooklm source add <url|文件>    # 添加来源
notebooklm source list              # 列出来源
notebooklm source add-research "主题" # 研究并导入

# 问答
notebooklm ask "问题"               # 提问

# 内容生成
notebooklm generate audio           # 生成播客
notebooklm generate video           # 生成视频
notebooklm generate cinematic-video # 生成纪录片风格视频
notebooklm generate quiz            # 生成测验
notebooklm generate flashcards      # 生成闪卡
notebooklm generate slide-deck      # 生成幻灯片
notebooklm generate infographic     # 生成信息图
notebooklm generate mind-map        # 生成思维导图

# 下载
notebooklm download audio ./x.mp3   # 下载音频
notebooklm download video ./x.mp4   # 下载视频
notebooklm download cinematic-video ./x.mp4  # 下载纪录片视频
notebooklm download quiz --format markdown ./x.md  # 下载测验
```

---

## 故障排除

### 认证失败

```bash
# 检查认证状态
notebooklm auth check --test

# 重新登录（在宿主机执行）
notebooklm login
```

### 容器内找不到 CLI

```bash
# 检查是否安装
which notebooklm

# 手动安装（如果 PIP_TOOLS 未配置）
uv pip install --system --break-system-packages notebooklm-py
```

### Skill 未生效

```bash
# 检查 skills 目录（挂载的宿主机目录）
ls /home/node/.claude/skills/notebooklm/

# 检查 skill 文件内容
cat /home/node/.claude/skills/notebooklm/skill.md
```

如果 skill 文件存在但 OpenClaw 未识别，让 OpenClaw 重新读取：

> 请读取 ~/.claude/skills/notebooklm/skill.md 并告诉我你学到了什么能力

### 权限问题

如果遇到 `EACCES` 错误：

```bash
# 检查目录权限
ls -la ~/.notebooklm/

# 修复权限
chmod -R 755 ~/.notebooklm/
```

### API 限流

NotebookLM 有请求频率限制。如遇到限流：

1. 减少并发请求
2. 增加请求间隔
3. 等待一段时间后重试

---

## 参考资料

- [notebooklm-py GitHub](https://github.com/teng-lin/notebooklm-py)
- [notebooklm-py PyPI](https://pypi.org/project/notebooklm-py/)
- [Google NotebookLM 官方网站](https://notebooklm.google.com/)
