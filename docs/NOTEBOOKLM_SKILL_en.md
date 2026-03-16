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

> Copy the notebooklm skill from ~/.claude/skills to your skills directory, then verify and tell me what capabilities you learned

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
│  /home/node/.claude/skills/notebooklm/                          │
│  └── skill.md              ← Skill mounted ✓                    │
│                                                                 │
│  /usr/local/bin/notebooklm ← Dynamic install at startup         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
        │
        │  Step 5: Copy via chat
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenClaw Config Directory                      │
│                                                                 │
│  ~/.claude/skills/notebooklm/                                   │
│  └── skill.md              ← Copied from mounted directory       │
│                                                                 │
│  After copy, OpenClaw gains NotebookLM control capabilities      │
└─────────────────────────────────────────────────────────────────┘

Sharing Rules:
  • Auth files: Direct share (JSON is cross-platform compatible)
  • CLI tool: Cannot share (macOS/Windows binary ≠ Linux)
  • Skill files: Mount + copy (text files are cross-platform compatible)
```

---

## Usage Examples

### Example 1: Research Agent Skills Best Practices

**Scenario**: Research Claude Agent Skills best practices, generate podcast for commute listening.

**Natural Language (Recommended):**

> Create a NotebookLM notebook "Agent Skills Best Practices", add source https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices, generate deep-dive style podcast and download as agent-skills-podcast.mp3

**Equivalent CLI:**

```bash
notebooklm create "Agent Skills Best Practices"
notebooklm use <id>
notebooklm source add "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices" --wait
notebooklm generate audio --wait
notebooklm download audio agent-skills-podcast.mp3
```

### Example 2: Batch Generate Learning Materials

**Scenario**: Generate quiz and flashcards for a course.

> Generate 20 quiz questions from current notebook, export as Markdown

```bash
notebooklm generate quiz --quantity more
notebooklm download quiz --format markdown quiz.md
```

### Example 3: Research and Auto-Import

**Scenario**: Auto-search and import relevant materials.

> Research "LLM Function Calling", search web resources and import into notebook

```bash
notebooklm source add-research "LLM Function Calling"
```

### Example 4: Generate Mind Map

**Scenario**: Visualize knowledge structure.

> Generate mind map of current notebook, export as JSON

```bash
notebooklm generate mind-map
notebooklm download mind-map mindmap.json
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
