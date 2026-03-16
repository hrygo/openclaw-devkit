# OpenClaw × NotebookLM Skill Integration Guide

This guide explains how to integrate and use the Google NotebookLM CLI skill in OpenClaw DevKit, enabling full control of NotebookLM through natural language.

## Table of Contents

- [Overview](#overview)
- [Host Machine Installation & Authentication](#host-machine-installation--authentication)
- [Container Environment Auto-Configuration](#container-environment-auto-configuration)
- [Installing Skill via Natural Language](#installing-skill-via-natural-language)
- [Practical Examples](#practical-examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

**notebooklm-py** is an unofficial Python SDK and CLI tool for Google NotebookLM, providing:

| Feature | Description |
|:--------|:------------|
| 📓 Notebook Management | Create, list, rename, delete |
| 📄 Multi-format Sources | URLs, YouTube, PDF, Word, audio/video, Google Drive |
| 💬 Smart Conversations | Source-based Q&A, custom personas |
| 🔍 Research Agent | Web/Drive deep research, auto-import |
| 🎙️ Content Generation | Podcasts, videos, slides, quizzes, mind maps, etc. |
| 📥 Batch Export | MP3, MP4, PDF, PNG, CSV, JSON, Markdown |

> ⚠️ **Note**: This tool uses undocumented Google APIs that may change at any time. Suitable for prototyping, research, and personal projects.

---

## Host Machine Installation & Authentication

### 1. Install CLI Tool

```bash
# Basic installation
pip install notebooklm-py

# Install browser login support (required for first-time setup)
pip install "notebooklm-py[browser]"
playwright install chromium
```

### 2. Google Account Authentication

```bash
# Start browser login flow
notebooklm login
```

This will automatically open a browser window:

1. Log in to your Google account
2. Complete authentication
3. Credentials are automatically saved to `~/.notebooklm/storage_state.json`

**Enterprise Users** (requiring Edge SSO):

```bash
notebooklm login --browser msedge
```

### 3. Verify Authentication Status

```bash
# Check authentication status
notebooklm auth check --test
```

Expected output:

```
✓ Storage file exists: /Users/you/.notebooklm/storage_state.json
✓ Authentication valid
✓ API access confirmed
```

---

## Container Environment Auto-Configuration

OpenClaw DevKit is pre-configured for NotebookLM support, sharing host authentication with the container.

### Configuration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Host Machine                           │
│                                                             │
│  ~/.notebooklm/                                             │
│  └── storage_state.json  ←── Google auth credentials        │
│                                                             │
└────────────────────┬────────────────────────────────────────┘
                     │ bind mount (rw)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      Container                              │
│                                                             │
│  /home/node/.notebooklm/                                    │
│  └── storage_state.json  ←── Shared with host               │
│                                                             │
│  /root/.notebooklm → /home/node/.notebooklm  (symlink)      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Environment Variable Configuration

Configure auto-installation in `.env` file:

```bash
# Python tool auto-installation
# Format: "package_name[:command_name]" (space-separated for multiple)
PIP_TOOLS=notebooklm-py:notebooklm
```

**Explanation**:
- `notebooklm-py` is the PyPI package name
- `notebooklm` is the CLI command after installation
- Auto-installed via `uv pip install --system` on container startup

### Verify Container Configuration

```bash
# Enter container
make shell

# Check if CLI is available
notebooklm auth check

# List notebooks
notebooklm list
```

---

## Installing Skill via Natural Language

### Method 1: CLI Installation

Execute inside the container:

```bash
notebooklm skill install
```

### Method 2: Natural Language Installation

Simply tell OpenClaw:

> "帮我安装 tiangong-notebooklm 技能，这样我就可以通过自然语言操控 NotebookLM 了"

Or:

> "Install the notebooklm skill so I can manage my Google NotebookLM notebooks"

OpenClaw will automatically execute the installation process.

### Verify Skill Installation

```bash
# Check skill status
notebooklm skill status
```

---

## Practical Examples

### Example 1: Research Agent Skills Best Practices

**Scenario**: Use NotebookLM to research Claude Agent Skills best practices and generate a podcast for listening during commute.

This example demonstrates core NotebookLM Skill usage: create notebook → add source → generate content → download.

#### Workflow Checklist

Copy this checklist to track progress:

```
Progress:
- [ ] Step 1: Create notebook
- [ ] Step 2: Add source (wait for processing)
- [ ] Step 3: Verify source is indexed
- [ ] Step 4: Generate audio
- [ ] Step 5: Download and verify
```

#### Natural Language Instruction (Recommended)

A concise single instruction for OpenClaw to plan and execute autonomously:

**Basic (download locally)**:

> Create a NotebookLM notebook named 'AI Agent Skills Best Practices', add this source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices. Generate a deep-dive style podcast and download it to agent-skills-podcast.mp3

**Advanced (send via Slack)**:

> Create a NotebookLM notebook named 'AI Agent Skills Best Practices', add this source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices. Generate a deep-dive style podcast and send it to me via Slack

#### Equivalent CLI Commands (Manual Execution)

```bash
# Step 1: Create notebook
notebooklm create "AI Agent Skills Best Practices"
# Output: Created notebook: <notebook_id>

# Step 2: Switch to that notebook
notebooklm use <notebook_id>

# Step 3: Add source (--wait ensures processing completes)
notebooklm source add "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices" --wait

# Step 4: Verify source status
notebooklm source list
# Confirm all sources show status: "completed"

# Step 5: Generate podcast (--wait blocks until complete)
notebooklm generate audio "deep-dive discussion style" --wait

# Step 6: Download
notebooklm download audio ./agent-skills-podcast.mp3

# Step 7: Verify file
ls -la ./agent-skills-podcast.mp3
```

#### Key Points

| Point | Description |
|:------|:------------|
| **Concise instruction** | Single sentence contains full intent, OpenClaw decomposes steps automatically |
| **Progress verification** | `--wait` flag ensures async operations complete before continuing |
| **Error prevention** | Verify source status before generating, avoid empty podcasts |
| **Degrees of freedom** | Natural language = high freedom (OpenClaw decides); CLI = low freedom (precise control) |

### Example 2: Batch Generate Learning Materials

**Scenario**: Generate quiz questions and flashcards for a course.

**Natural language**:

> "Using my current notebook, generate a set of difficult quiz questions (20 questions), then generate a set of flashcards, both exported in Markdown format"

**Equivalent CLI**:

```bash
# Generate quiz
notebooklm generate quiz --difficulty hard --quantity more

# Generate flashcards
notebooklm generate flashcards --quantity more

# Export
notebooklm download quiz --format markdown ./quiz.md
notebooklm download flashcards --format markdown ./flashcards.md
```

### Example 3: Create Presentation Video

**Scenario**: Generate a whiteboard-style explainer video or documentary-style video for project documentation.

**Natural language**:

> "Generate a whiteboard-style explainer video, 5 minutes long, about project architecture overview"

Or:

> "Generate a documentary-style video overview"

**Equivalent CLI**:

```bash
# Whiteboard-style video
notebooklm generate video --style whiteboard --wait
notebooklm download video ./overview.mp4

# Documentary-style video (separate command)
notebooklm generate cinematic-video "documentary-style summary" --wait
notebooklm download cinematic-video ./documentary.mp4
```

### Example 4: Research and Auto-Import

**Scenario**: Automatically search and import relevant materials.

**Natural language**:

> "Help me research the topic 'LLM Function Calling', search for relevant materials from the web and automatically import them into the current notebook"

**Equivalent CLI**:

```bash
notebooklm source add-research "LLM Function Calling"
```

### Example 5: Generate Mind Map

**Scenario**: Visualize the knowledge structure in a notebook.

**Natural language**:

> "Generate a mind map of the current notebook, export it in JSON format so I can visualize it in other tools"

**Equivalent CLI**:

```bash
notebooklm generate mind-map
notebooklm download mind-map ./mindmap.json
```

---

## Supported Content Types

| Type | Options | Export Formats |
|:-----|:--------|:---------------|
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

## Troubleshooting

### Authentication Failed

```bash
# Check authentication status
notebooklm auth check --test

# Re-login
notebooklm login
```

### Command Not Found in Container

```bash
# Check if installed
which notebooklm

# Manual installation
uv pip install --system notebooklm-py
```

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

---

## Appendix: Common CLI Commands Reference

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

# Skill
notebooklm skill install            # Install Claude Code skill
notebooklm skill status             # Check skill status
```
