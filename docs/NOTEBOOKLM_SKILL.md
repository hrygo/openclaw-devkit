# NotebookLM 技能集成指南

通过自然语言操控 Google NotebookLM，创建播客、视频、测验等内容。

## 功能一览

| 功能            | 说明                                     |
| --------------- | ---------------------------------------- |
| 📓 Notebook 管理 | 创建、列表、切换、删除                   |
| 📄 多格式来源    | URLs、YouTube、PDF、Word、Google Drive   |
| 🎙️ 内容生成      | 播客、视频、幻灯片、测验、闪卡、思维导图 |
| 📥 导出格式      | MP3、MP4、PDF、PNG、Markdown、JSON       |

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

浏览器自动打开，完成 Google 登录后认证保存到 `~/.notebooklm/`。

**验证:**
```bash
notebooklm auth check --test
# ✓ Authentication valid
```

### Step 3: 宿主机安装 Skill

```bash
notebooklm skill install
```

Skill 安装到 `~/.claude/skills/notebooklm/`。

### Step 4: 启动容器

```bash
make up
```

容器启动时自动：
- 挂载认证目录 → 共享 Google 认证
- 挂载 Skills 目录 → 共享 Skill 文件
- 安装 CLI 工具 → 通过 PIP_TOOLS 环境变量

**验证:**
```bash
make shell
notebooklm auth check          # ✓ 认证共享成功
ls /home/node/.claude/skills/  # notebooklm 目录存在
```

### Step 5: 复制 Skill

对 OpenClaw 说：

> 从 ~/.claude/skills 复制 notebooklm skill 到你的 skills 目录，然后告诉我学习到了什么能力?

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
│  /home/node/.claude/skills/notebooklm/                          │
│  └── skill.md              ← Skill 挂载 ✓                        │
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
  • Skill 文件: 挂载 → 复制 (文本文件跨平台兼容)
```

---

## 使用示例

### 案例 1：研究 Agent Skills 最佳实践

**场景**: 使用 NotebookLM 研究 Claude Agent Skills 最佳实践，生成播客便于通勤时收听。

**自然语言（推荐）:**

> 创建一个 Notebook "Agent Skills 最佳实践"，添加来源 https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices，生成深入讨论风格的播客并下载为 agent-skills-podcast.mp3

**等效 CLI:**

```bash
notebooklm create "Agent Skills 最佳实践"
notebooklm use <id>
notebooklm source add "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices" --wait
notebooklm generate audio --wait
notebooklm download audio agent-skills-podcast.mp3
```

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

> 帮我研究 "LLM Function Calling"，搜索网页资料并自动导入到当前笔记本

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

| 类型     | 选项                         | 导出格式       |
| -------- | ---------------------------- | -------------- |
| 播客     | 4 种风格、3 种时长、50+ 语言 | MP3/MP4        |
| 视频     | 白板/纪录片等 9 种风格       | MP4            |
| 幻灯片   | 详细版/演讲版                | PDF, PPTX      |
| 测验     | 可调难度和数量               | Markdown, JSON |
| 闪卡     | 可调数量                     | Markdown, JSON |
| 思维导图 | 知识结构可视化               | JSON           |
| 信息图   | 3 种方向、3 种细节级别       | PNG            |

---

## 常用命令

```bash
# 认证
notebooklm login                    # 登录
notebooklm auth check               # 检查状态

# 笔记本
notebooklm list                     # 列出
notebooklm create "名称"            # 创建
notebooklm use <id>                 # 切换

# 来源
notebooklm source add <url>         # 添加
notebooklm source list              # 列出

# 生成
notebooklm generate audio           # 播客
notebooklm generate video           # 视频
notebooklm generate quiz            # 测验

# 下载
notebooklm download audio ./x.mp3
notebooklm download quiz --format markdown ./quiz.md
```

---

## 故障排除

| 问题         | 解决方案                                                       |
| ------------ | -------------------------------------------------------------- |
| 认证失败     | `notebooklm login` 重新登录                                    |
| 容器无 CLI   | `uv pip install --system notebooklm-py`                        |
| Skill 未生效 | `cp -r /home/node/.claude/skills/notebooklm ~/.claude/skills/` |
| API 限流     | 减少并发，等待后重试                                           |

---

## 参考资料

- [notebooklm-py GitHub](https://github.com/teng-lin/notebooklm-py)
- [Google NotebookLM](https://notebooklm.google.com/)
