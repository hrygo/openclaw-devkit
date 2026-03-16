# NotebookLM Skill Integration Guide

Control Google NotebookLM through natural language to create podcasts, videos, quizzes, and more.

## Features

| Feature | Description |
|---------|-------------|
| 📓 Notebook Management | Create, list, switch, delete |
| 📄 Multi-format Sources | URLs, YouTube, PDF, Word, Google Drive |
| 🎙️ Content Generation | Podcasts, videos, slides, quizzes, flashcards, mind maps |
| 📥 Export Formats | MP3, MP4, PDF, PNG, Markdown, JSON |

---

## Quick Start

### Step 1: Install CLI on Host

```bash
# Install CLI tool
pip install "notebooklm-py[browser]"

# Install browser (required for first login)
playwright install chromium
```

### Step 2: Google Authentication

```bash
# Start browser login
notebooklm login
```

Browser opens automatically. After Google login, credentials save to `~/.notebooklm/`.

**Verify:**
```bash
notebooklm auth check --test
# ✓ Authentication valid
```

### Step 3: Install Skill on Host

```bash
notebooklm skill install
```

Skill installs to `~/.claude/skills/notebooklm/`.

### Step 4: Start Container

```bash
make up
```

Container automatically:
- Mounts auth directory → Shares Google authentication
- Mounts Skills directory → Shares Skill files
- Installs CLI tool → Via PIP_TOOLS environment variable

**Verify:**
```bash
make shell
notebooklm auth check          # ✓ Auth shared successfully
ls /home/node/.claude/skills/  # notebooklm directory exists
```

### Step 5: Copy Skill

Tell OpenClaw:

> Please copy the skill from /home/node/.claude/skills/notebooklm/ to your skills directory, then verify the copy succeeded and tell me what capabilities you learned from this skill

---

## Architecture Map

```
┌─────────────────────────────────────────────────────────────────┐
│                        Host Machine                              │
│                                                                 │
│  ~/.notebooklm/                                                 │
│  └── storage_state.json    ← Google auth credentials            │
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
│                        Container                                 │
│                                                                 │
│  /home/node/.notebooklm/                                        │
│  └── storage_state.json    ← Auth shared ✓                      │
│                                                                 │
│  /home/node/.claude/skills/                                     │
│  └── notebooklm/           ← Skill mounted ✓                    │
│                                                                 │
│  /usr/local/bin/notebooklm ← Dynamic install at startup         │
│                                                                 │
│  OpenClaw ~/.claude/skills/                                     │
│  └── notebooklm/           ← Copy via chat                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Sharing Rules:
  • Auth files: Direct share (JSON is cross-platform compatible)
  • CLI tool: Cannot share (macOS/Windows binary ≠ Linux)
  • Skill files: Mount + copy (text files are cross-platform compatible)
```

---

## Usage Examples

### Create a Podcast

**Natural Language (Recommended):**

> Create a NotebookLM notebook, add source https://example.com/article, generate a deep-dive style podcast and download it

**Equivalent CLI:**

```bash
notebooklm create "My Notebook"
notebooklm use <id>
notebooklm source add "https://example.com/article" --wait
notebooklm generate audio --wait
notebooklm download audio podcast.mp3
```

### Generate Quiz

> Generate 20 quiz questions from current notebook, export as Markdown

```bash
notebooklm generate quiz --quantity more
notebooklm download quiz --format markdown quiz.md
```

### Research and Import

> Research "LLM Function Calling", search web resources and import into notebook

```bash
notebooklm source add-research "LLM Function Calling"
```

---

## Supported Content Types

| Type | Options | Export Formats |
|------|---------|----------------|
| Podcast | 4 styles, 3 durations, 50+ languages | MP3/MP4 |
| Video | 9 visual styles (whiteboard/documentary/etc.) | MP4 |
| Slides | Detailed/presentation version | PDF, PPTX |
| Quiz | Configurable difficulty and quantity | Markdown, JSON |
| Flashcards | Configurable quantity | Markdown, JSON |
| Mind Map | Knowledge structure visualization | JSON |
| Infographic | 3 orientations, 3 detail levels | PNG |

---

## Common Commands

```bash
# Authentication
notebooklm login                    # Login
notebooklm auth check               # Check status

# Notebooks
notebooklm list                     # List
notebooklm create "Name"            # Create
notebooklm use <id>                 # Switch

# Sources
notebooklm source add <url>         # Add
notebooklm source list              # List

# Generate
notebooklm generate audio           # Podcast
notebooklm generate video           # Video
notebooklm generate quiz            # Quiz

# Download
notebooklm download audio ./x.mp3
notebooklm download quiz --format markdown ./quiz.md
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Auth failed | `notebooklm login` to re-authenticate |
| No CLI in container | `uv pip install --system notebooklm-py` |
| Skill not working | `cp -r /home/node/.claude/skills/notebooklm ~/.claude/skills/` |
| API rate limited | Reduce concurrency, wait and retry |

---

## References

- [notebooklm-py GitHub](https://github.com/teng-lin/notebooklm-py)
- [Google NotebookLM](https://notebooklm.google.com/)
