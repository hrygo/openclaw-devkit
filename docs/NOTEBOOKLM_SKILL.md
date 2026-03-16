# NotebookLM 技能集成指南

通过自然语言操控 Google NotebookLM，创建播客、视频、测验等内容。

## 功能一览

| 功能 | 说明 |
|------|------|
| 📓 Notebook 管理 | 创建、列表、切换、删除 |
| 📄 多格式来源 | URLs、YouTube、PDF、Word、Google Drive |
| 🎙️ 内容生成 | 播客、视频、幻灯片、测验、闪卡、思维导图 |
| 📥 导出格式 | MP3、MP4、PDF、PNG、Markdown、JSON |

---

## 快速开始

```bash
# 1. 宿主机安装 CLI 并登录
pip install "notebooklm-py[browser]"
notebooklm login

# 2. 宿主机安装 Skill
notebooklm skill install

# 3. 启动容器
make up

# 4. 对话复制 Skill
# 对 OpenClaw 说: "复制 notebooklm skill"
```

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
              │                       │
              │  Docker Compose       │
              │  Bind Mounts (rw)     │
              │                       │
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
│                             (PIP_TOOLS 环境变量)                  │
│                                                                 │
│  OpenClaw ~/.claude/skills/                                     │
│  └── notebooklm/           ← 对话复制到此处                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

共享规则:
  • 认证文件: 直接共享 (JSON 文件跨平台兼容)
  • CLI 工具: 无法共享 (macOS/Windows 二进制 ≠ Linux)
  • Skill 文件: 挂载 + 复制 (文本文件跨平台兼容)
```

---

## 分步配置

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

**企业用户 (Edge SSO):**
```bash
notebooklm login --browser msedge
```

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
notebooklm auth check      # ✓ 认证共享成功
ls /home/node/.claude/skills/  # notebooklm 目录存在
```

### Step 5: 复制 Skill

对 OpenClaw 说：

> "复制 notebooklm skill"

OpenClaw 会从挂载目录复制 Skill 到其配置目录。

---

## 使用示例

### 创建播客

**自然语言（推荐）:**

> 创建一个 NotebookLM 笔记本，添加来源 https://example.com/article，生成深入讨论风格的播客并下载

**等效 CLI:**

```bash
notebooklm create "我的笔记本"
notebooklm use <id>
notebooklm source add "https://example.com/article" --wait
notebooklm generate audio --wait
notebooklm download audio podcast.mp3
```

### 生成测验

> 用当前笔记本生成 20 道测验题，导出 Markdown 格式

```bash
notebooklm generate quiz --quantity more
notebooklm download quiz --format markdown quiz.md
```

### 研究并导入

> 帮我研究 "LLM Function Calling"，搜索网页资料并导入笔记本

```bash
notebooklm source add-research "LLM Function Calling"
```

---

## 支持的内容类型

| 类型 | 选项 | 导出格式 |
|------|------|----------|
| 播客 | 4 种风格、3 种时长、50+ 语言 | MP3/MP4 |
| 视频 | 白板/纪录片等 9 种风格 | MP4 |
| 幻灯片 | 详细版/演讲版 | PDF, PPTX |
| 测验 | 可调难度和数量 | Markdown, JSON |
| 闪卡 | 可调数量 | Markdown, JSON |
| 思维导图 | 知识结构可视化 | JSON |
| 信息图 | 3 种方向、3 种细节级别 | PNG |

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

| 问题 | 解决方案 |
|------|----------|
| 认证失败 | `notebooklm login` 重新登录 |
| 容器无 CLI | `uv pip install --system notebooklm-py` |
| Skill 未生效 | `cp -r /home/node/.claude/skills/notebooklm ~/.claude/skills/` |
| API 限流 | 减少并发，等待后重试 |

---

## 参考资料

- [notebooklm-py GitHub](https://github.com/teng-lin/notebooklm-py)
- [Google NotebookLM](https://notebooklm.google.com/)
