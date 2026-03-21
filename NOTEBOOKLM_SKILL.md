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

执行后会自动打开浏览器窗口。

#### ⚠️ 登录流程 - 务必按顺序操作

```
1. 浏览器打开 → 在浏览器中完成 Google 登录
2. 等待      → 看到 NotebookLM 首页（不是 Google 登录成功页面）
3. 回终端    → 按 ENTER 键保存认证
4. 完成      → 此时才能关闭浏览器
```

```
❌ 错误: 浏览器登录 → 关闭浏览器 → 尝试按 ENTER
   → 报错: storage_state 保存失败，cookies 未写入

✅ 正确: 浏览器登录 → 等待 NotebookLM 首页 → 在终端按 ENTER → 浏览器自动关闭
```

**为什么这很重要**: 认证 cookies 只有在你按 ENTER **之后**才会保存。提前关闭浏览器会中断保存过程，导致后续命令报 "Missing required cookies" 错误。

---

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
- notebooklm CLI → **已内置于镜像中，通过 volume 持久化**（重启后依然存在）

**验证容器配置:**
```bash
make shell
which notebooklm               # ✓ CLI 已内置并持久化
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
│  /home/node/.local/bin/notebooklm ← Volume 持久化 ✓                      │
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
  • CLI 工具: 镜像内置 (不再需要共享)
  • Skill 文件: 挂载 + 复制 (文本文件跨平台兼容)
```

---

## 使用示例

### 案例 1：研究 Agent Skills 最佳实践

**场景**: 使用 NotebookLM 研究 Claude Agent Skills 最佳实践，生成播客便于通勤时收听。

**自然语言:**

> 创建一个 Notebook "Agent Skills 最佳实践"，添加来源 https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
> 生成深入讨论风格的播客并下载为 agent-skills-podcast.mp3

### 案例 2：批量生成学习材料

**场景**: 为一门课程生成测验题和闪卡。

> 用当前笔记本生成 20 道测验题，再生成一套闪卡，都导出 Markdown 格式

### 案例 3：研究与自动导入

**场景**: 自动搜索并导入相关资料。

> 帮我研究 "LLM Function Calling"，搜索网页资料并导入笔记本


### 案例 4：生成思维导图

**场景**: 可视化知识结构。

> 生成当前笔记本的思维导图，导出 JSON 格式


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

> 注意：notebooklm CLI 已内置于镜像中。如果找不到，请尝试升级镜像：
```bash
make upgrade
```

### Skill 未生效

```bash
# 检查 skills 目录（挂载的宿主机目录）
ls /home/node/.claude/skills/notebooklm/

# 检查 skill 文件内容
cat /home/node/.claude/skills/notebooklm/skill.md
```

如果 skill 文件存在但 OpenClaw 未识别，让 OpenClaw 重新读取：

> 从 ~/.claude/skills 复制 notebooklm skill 到你的 skills 目录，然后告诉我你通过这个 skill 学习到了什么？

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
