## Overview

> [!IMPORTANT]
> This configuration is not intended to be a universal Claude Code setup.
> This setup is heavily optimized for Frontend developers working in Jira-driven teams.

`claude-config` is a personal setup for building a structured, scalable, and persistent workflow around Claude Code — focused heavily on modern Frontend development.

The main goal of this configuration is to solve common problems when working with AI coding agents at scale:

- Losing context between sessions
- Weak task tracking and ownership
- Poor long-term memory across projects
- Uncontrolled file edits from autonomous agents
- Difficult orchestration between planning, implementation, and review
- Token waste caused by repeatedly reloading project knowledge

This setup combines Claude Code with task orchestration, persistent memory, checkpointing, MCP servers, hooks, and specialized subagents to create a more reliable AI-assisted development workflow.

---

## Core Technologies

This configuration is built around several tools working together:

| Tool             | Purpose                                               |
| ---------------- | ----------------------------------------------------- |
| Claude Code      | Main AI coding environment                            |
| beads (`bd`)     | Task management, claiming, checkpoints, orchestration |
| dolt             | Backend database required by beads                    |
| mempalace        | Cross-session persistent memory system                |
| MCP servers      | Extend Claude with external tools and memory          |
| bv               | Code coupling & architecture analysis                 |
| caveman plugin   | Compressed AI communication mode                      |
| Atlassian plugin | Jira & Confluence integration                         |
| Hooks system     | Automates session lifecycle and safety checks         |

---

## Key Features

### Persistent AI Memory

Using `mempalace`, Claude can retain long-term project knowledge across sessions instead of rebuilding context every time.

### Task-Based Workflow

`beads` provides structured task management with:

- task claiming
- checkpoints
- progress tracking
- session recovery
- orchestration support

This makes AI-driven development much more predictable and collaborative.

### Safe Autonomous Editing

Custom hooks prevent accidental edits unless a task is explicitly claimed, reducing the risk of uncontrolled agent behavior.

### Session Recovery

Automatic checkpointing restores previous work context when a new session starts.

## Structure

```
claude-config/
├── install.sh                  # One-shot installer
├── CLAUDE.md                   # Global AI instructions (→ ~/.claude/CLAUDE.md)
├── CLAUDE_TEMPLATE_PROJECT.md  # Per-project template (→ .claude/CLAUDE.md in each repo)
├── settings.json               # Claude Code settings (→ ~/.claude/settings.json)
├── agents/
│   ├── frontend-dev.md         # Frontend subagent definition
│   └── reviewer.md             # Code review subagent definition
└── scripts/
    ├── session-start.sh        # Runs on SessionStart hook — reloads checkpoint + tasks
    ├── session-end.sh          # Runs on Stop hook — saves checkpoint
    ├── checkpoint-write.sh     # Saves task state to bd kv + PRIME.md
    ├── guard-claim.sh          # PreToolUse hook — blocks edits without claimed task
    ├── score-task.sh           # Scores task size: SMALL / MEDIUM / LARGE
    └── jira-to-bd.sh           # Finds or creates bead for a Jira key
```

## Prerequisites

Install in this order:

### 1. Claude Code CLI

Download from <https://claude.ai/download>

### 2. dolt (required by beads)

```bash
curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash
```

### 3. beads (bd CLI)

```bash
curl -sSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash

# In Claude Code
/plugin marketplace add gastownhall/beads
/plugin install beads
```

Repo: <https://github.com/gastownhall/beads>

### 4. bv + mcp_agent_mail

```bash
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh?$(date +%s)" | bash -s -- --yes --skip-beads
```

Installs both `bv` (coupling analyzer) and `mcp-agent-mail` MCP server. Flag `--skip-beads` is needed because i want to use the original beads plugin, not the modified one bundled `beads-rust` with mcp_agent_mail.

Add alias

```fish/bash/zsh
# >>> MCP Agent Mail alias
alias am='cd "/root/.local/share/mcp_agent_mail" && scripts/run_server_with_token.sh'
# <<< MCP Agent Mail alias
```

### 5. mempalace

```bash
# Follow install at:
# https://github.com/mempalace/mempalace
```

Provides `mempalace` CLI and `mempalace-mcp` binary for cross-session memory.

## Install

```bash
git clone <this-repo>
cd claude-config
./install.sh
```

Installer:

1. Checks prerequisites (claude, jq, bd)
2. Creates `~/.claude/scripts/`, `~/.claude/agents/`, `~/.claude/memory/`
3. Copies all config files (skips existing — no overwrites)
4. Makes scripts executable
5. Installs `caveman`, `beads`, `atlassian` plugins via `claude plugin install`

## Per-project Setup

Run once per project after cloning:

```bash
cd ~/Projects/<org>/<project>

# 1. Add project CLAUDE.md
cp ~/.claude/CLAUDE_TEMPLATE_PROJECT.md CLAUDE.md

# 2. Init beads
bd init
bd setup claude

# 3. Install beads plugin
claude plugin install beads@beads-marketplace

# 4. Create PRIME.md (checkpoint anchor)
mkdir -p .beads
touch .beads/PRIME.md

# 5. Init mempalace palace for this project
mempalace --palace ~/.mempalace/<project> init .

# 6. Add mempalace MCP at local scope
claude mcp add mempalace -s local -- mempalace-mcp --palace ~/.mempalace/<project>

# 7. Verify
claude mcp list    # mempalace should show ✓ Connected
bd status
```

## Workflow Overview

```
Session start
  └─ session-start.sh → bd prime + reload last checkpoint

New task
  └─ score-task.sh <id> → SMALL / MEDIUM / LARGE
  └─ bd update <id> --claim
  └─ work (guard-claim.sh blocks edits without claimed task)
  └─ bd close <id>
  └─ checkpoint-write.sh <id>

Session end
  └─ session-end.sh → checkpoint-write + bd prime
```

## Hooks wired in settings.json

| Event                          | Hook                                    |
| ------------------------------ | --------------------------------------- |
| `SessionStart`                 | `session-start.sh` — reload checkpoint  |
| `PreToolUse` (edit/write/bash) | `guard-claim.sh` — require claimed task |
| `PreCompact`                   | checkpoint-write + mempalace sweep      |
| `Stop`                         | `session-end.sh` + mempalace sweep      |

## Plugins

| Plugin      | Source                                                     |
| ----------- | ---------------------------------------------------------- |
| `caveman`   | `JuliusBrussee/caveman` — compressed AI communication mode |
| `atlassian` | `claude-plugins-official` — Jira/Confluence integration    |

Install manually if needed:

```bash
claude plugin install caveman@caveman
claude plugin install atlassian@claude-plugins-official
```

## Verify

```bash
claude mcp list                      # mempalace ✓ Connected
~/.claude/scripts/session-start.sh  # runs without errors
bd status                            # beads working
which bd bv mempalace jq             # all binaries found
```

## Troubleshooting

**mempalace failing to connect:**

```bash
mempalace-mcp --help    # confirm binary exists
claude mcp remove mempalace -s local
claude mcp add mempalace -s local -- mempalace-mcp --palace ~/.mempalace/<project>
```

**mempalace "No palace found":**

```bash
mempalace --palace ~/.mempalace/<project> init .
```

**Scripts not executable:**

```bash
chmod +x ~/.claude/scripts/*.sh
```

**bd kv empty after /clear:**

```bash
bd kv list    # check for checkpoint:* keys
# If empty → paste new ticket, Claude creates tasks from scratch
```

**Skills being dropped:**

```bash
# settings.json should already have:
"skillListingBudgetFraction": 0.03
```

**guard-claim.sh blocking all edits:**

```bash
bd update <id> --claim   # claim a task first
# or temporarily bypass by commenting out PreToolUse hook
```
