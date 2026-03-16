# OpenClaw × NotebookLM Skill Integration Guide

This guide explains how to integrate and use the Google NotebookLM CLI skill in OpenClaw DevKit, enabling full control of NotebookLM through natural language.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Architecture Map](#architecture-map)
- [Usage Examples](#usage-examples)
- [Supported Content Types](#supported-content-types)
- [Common Commands](#common-commands)
- [Troubleshooting](#troubleshooting)

---

## Features

**notebooklm-py** is an unofficial Python SDK and CLI tool for Google NotebookLM, providing:

| Feature | Description |
| :-------| :--------------------------------------------- |
| 📓 Notebook Management | Create, list, rename, delete |
| 📄 Multi-format Sources | URLs, YouTube, PDF, Word, audio/video, Google Drive |
| 💬 Smart Chat | Source-based Q&A, custom personas |
| 🔍 Research Agent | Web/Drive deep research, auto-import |
| 🎙️ Content Generation | Podcasts, videos, slides, quizzes, mind maps, etc. |
| 📥 Batch Export | MP3, MP4, PDF, PNG, CSV, JSON, Markdown |

> ⚠️ **Note**: This tool uses undocumented Google APIs that may change at any time. Suitable for prototyping, research, and personal projects.

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

This will automatically open a browser window:

1. Log in to your Google account
2. Complete authentication
3. Credentials are automatically saved to `~/.notebooklm/storage_state.json`

**Verify Authentication:**
```bash
notebooklm auth check --test
```

Expected output:
```
✓ Storage file exists: /Users/you/.notebooklm/storage_state.json
✓ Authentication valid
✓ API access confirmed
```

### Step 3: Install Skill on Host

```bash
notebooklm skill install
```

Skill installs to `~/.claude/skills/notebooklm/` directory.

### Step 4: Start Container

```bash
make up
```

Container automatically on startup:
- Mounts auth directory → Shares Google authentication
- Mounts Skills directory → Shares Skill files
- Installs CLI tool → Via PIP_TOOLS environment variable

**Verify Container Configuration:**
```bash
make shell
notebooklm auth check          # ✓ Auth shared successfully
ls /home/node/.claude/skills/  # notebooklm directory exists
```

### Step 5: Copy Skill

Tell OpenClaw:

> Copy the notebooklm skill from ~/.claude/skills to your skills directory, then tell me what capabilities you learned from this skill?

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
│  └── storage_state.json    ← Auth shared ✓                       │
│                                                                 │
│  /home/node/.claude/skills/                                     │
│  └── notebooklm/           ← Skill mounted ✓                     │
│                                                                 │
│  /usr/local/bin/notebooklm ← Dynamic install at startup         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
        │
        │  Step 5: Copy via chat
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OpenClaw Config Directory                     │
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

**Scenario**: Use NotebookLM to research Claude Agent Skills best practices, generate podcast for commute listening.

**Natural Language:**

> Create a Notebook "Agent Skills Best Practices", add source https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
> Generate a deep-dive discussion style podcast and download as agent-skills-podcast.mp3

### Example 2: Batch Generate Learning Materials

**Scenario**: Generate quiz questions and flashcards for a course.

> Generate 20 quiz questions from current notebook, then generate flashcards, both exported as Markdown format

### Example 3: Research and Auto-Import

**Scenario**: Auto-search and import relevant materials.

> Help me research "LLM Function Calling", search web resources and import into notebook

### Example 4: Generate Mind Map

**Scenario**: Visualize knowledge structure.

> Generate mind map of current notebook, export as JSON format

---

## Supported Content Types

| Type | Options | Export Formats |
| :--- | :------- | :-------------- |
| **Audio Overview** | 4 styles (deep-dive/brief/critique/debate), 3 durations, 50+ languages | MP3/MP4 |
| **Video Overview** | 3 styles (explainer/brief/cinematic), 9 visual styles, separate `cinematic-video` alias | MP4 |
| **Slide Deck** | Detailed/presentation version, adjustable length | PDF, PPTX |
| **Infographic** | 3 orientations, 3 detail levels | PNG |
| **Quiz** | Configurable quantity and difficulty | JSON, Markdown, HTML |
| **Flashcards** | Configurable quantity and difficulty | JSON, Markdown, HTML |
| **Report** | Brief/study guide/blog post/custom prompts | Markdown |
| **Data Table** | Natural language structure definition | CSV |
| **Mind Map** | Interactive hierarchical visualization | JSON |

---

## Common Commands

```bash
# Authentication
notebooklm login                    # Browser login
notebooklm auth check --test        # Check auth

# Notebook Management
notebooklm list                     # List all notebooks
notebooklm create "Name"            # Create new notebook
notebooklm use <id>                 # Switch current notebook
notebooklm metadata --json          # Export metadata

# Source Management
notebooklm source add <url|file>    # Add source
notebooklm source list              # List sources
notebooklm source add-research "topic" # Research and import

# Q&A
notebooklm ask "question"           # Ask question

# Content Generation
notebooklm generate audio           # Generate podcast
notebooklm generate video           # Generate video
notebooklm generate cinematic-video # Generate documentary video
notebooklm generate quiz            # Generate quiz
notebooklm generate flashcards      # Generate flashcards
notebooklm generate slide-deck      # Generate slides
notebooklm generate infographic     # Generate infographic
notebooklm generate mind-map        # Generate mind map

# Download
notebooklm download audio ./x.mp3   # Download audio
notebooklm download video ./x.mp4   # Download video
notebooklm download cinematic-video ./x.mp4  # Download documentary video
notebooklm download quiz --format markdown ./x.md  # Download quiz
```

---

## Troubleshooting

### Authentication Failed

```bash
# Check authentication status
notebooklm auth check --test

# Re-login (run on host)
notebooklm login
```

### CLI Not Found in Container

```bash
# Check if installed
which notebooklm

# Manual installation (if PIP_TOOLS not configured)
uv pip install --system --break-system-packages notebooklm-py
```

### Skill Not Working

```bash
# Check skills directory (mounted from host)
ls /home/node/.claude/skills/notebooklm/

# Check skill file content
cat /home/node/.claude/skills/notebooklm/skill.md
```

If skill file exists but OpenClaw doesn't recognize it, ask OpenClaw to re-read:

> Copy the notebooklm skill from ~/.claude/skills to your skills directory, then tell me what capabilities you learned from this skill?

### Permission Issues

If you encounter `EACCES` errors:

```bash
# Check directory permissions
ls -la ~/.notebooklm/

# Fix permissions
chmod -R 755 ~/.notebooklm/
```

### API Rate Limiting

NotebookLM has request frequency limits. If rate limited:

1. Reduce concurrent requests
2. Increase request intervals
3. Wait for a while before retrying

---

## References

- [notebooklm-py GitHub](https://github.com/teng-lin/notebooklm-py)
- [notebooklm-py PyPI](https://pypi.org/project/notebooklm-py/)
- [Google NotebookLM Official](https://notebooklm.google.com/)
