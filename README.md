## Overview

> [!IMPORTANT]
> This configuration is not intended to be a universal AI coding setup.
> Heavily optimized for Frontend developers working in Jira-driven teams.

`claude-config` is a personal setup for building a structured, scalable, and persistent workflow around AI coding agents — primarily **Claude Code** (ultracode fan-outs) and **OpenCode + oh-my-openagent** as the daily driver. Model and provider are user-configured; the workflow is model-agnostic.

The main goal is to solve common problems when working with AI coding agents at scale:

- Losing context between sessions
- Weak task tracking and ownership
- Poor long-term memory across projects
- Uncontrolled file edits from autonomous agents
- Difficult orchestration between planning, implementation, and review
- Token waste from repeatedly reloading project knowledge

---

## Core Technologies

| Tool                    | Purpose                                                    |
| ----------------------- | ---------------------------------------------------------- |
| Claude Code             | Rare large fan-outs (ultracode); kept fully intact         |
| OpenCode + omo          | Daily driver — model-agnostic, Team Mode, parallel agents  |
| beads (`bd`)            | Task management, claiming, checkpoints, orchestration      |
| dolt                    | Backend database required by beads                         |
| mempalace               | Cross-session persistent memory system                     |
| MCP servers             | Extend agents with external tools and memory               |
| bv                      | Code coupling & architecture analysis                      |
| caveman plugin          | Compressed AI communication mode (Claude Code only)        |
| Atlassian plugin        | Jira & Confluence integration (Claude Code only)           |
| Hooks system            | Automates session lifecycle and safety checks              |

---

## Key Features

### Persistent AI Memory

`mempalace` retains long-term project knowledge across sessions — no rebuilding context every time. Works in both Claude Code and OpenCode via MCP.

### Task-Based Workflow

`beads` provides structured task management with task claiming, checkpoints, progress tracking, session recovery, and orchestration support.

### Safe Autonomous Editing

Custom hooks prevent accidental edits unless a task is explicitly claimed.

### Session Recovery

Automatic checkpointing restores previous work context when a new session starts.

### Parallel Agent Orchestration (omo)

oh-my-openagent Team Mode runs up to 3 concurrent agents. Set `background_task.providerConcurrency` in `oh-my-openagent.json` to match your provider's rate limits. For 15+ agent fan-outs, use Claude Code ultracode.

---

## Structure

```
claude-config/
├── install.sh                      # Installer — supports: all | claude | opencode
├── CLAUDE.md                       # Global Claude Code instructions (→ ~/.claude/CLAUDE.md)
├── CLAUDE_TEMPLATE_PROJECT.md      # Per-project template (→ CLAUDE.md in each repo)
├── AGENTS.md                       # OpenCode orchestrator rules (→ project root)
├── opencode.json                   # OpenCode project config — omo plugin + MCP servers
├── settings.json                   # Claude Code settings (→ ~/.claude/settings.json)
├── agents/                         # Claude Code subagent definitions
│   ├── frontend-dev.md
│   └── reviewer.md
├── .opencode/
│   └── agent/                      # OpenCode subagent definitions
│       ├── frontend-dev.md
│       └── reviewer.md
└── scripts/
    ├── session-start.sh            # Reload checkpoint + tasks
    ├── session-end.sh              # Save checkpoint
    ├── checkpoint-write.sh         # Save task state to bd kv + PRIME.md
    ├── guard-claim.sh              # Block edits without claimed task
    ├── score-task.sh               # Score task size: SMALL / MEDIUM / LARGE
    └── jira-to-bd.sh               # Find or create bead for a Jira key
```

---

## Prerequisites

### Shared (both Claude Code and OpenCode)

#### 1. dolt (required by beads)

```bash
curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash
```

#### 2. beads (bd CLI)

```bash
curl -sSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash
```

#### 3. bv + mcp_agent_mail

```bash
curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh?$(date +%s)" | bash -s -- --yes --skip-beads
```

Installs `bv` (coupling analyzer) and `mcp-agent-mail` MCP server. `--skip-beads` skips the bundled beads-rust variant.

Add alias:

```bash
# fish / bash / zsh
alias am='cd "/root/.local/share/mcp_agent_mail" && scripts/run_server_with_token.sh'
```

#### 4. mempalace

```bash
# https://github.com/mempalace/mempalace
```

Provides `mempalace` CLI and `mempalace-mcp` binary for cross-session memory.

#### 5. jq

```bash
sudo apt install jq   # or brew install jq
```

---

### Claude Code

```bash
# Download from https://claude.ai/download
```

---

### OpenCode + omo

#### 1. OpenCode CLI

```bash
curl -fsSL https://opencode.ai/install | bash
```

#### 2. oh-my-openagent (omo)

```bash
npx oh-my-openagent install --no-tui --platform=opencode --skip-auth
```

> `bun` / `bunx` is preferred if available: `bunx oh-my-openagent install`

#### 3. Configure your provider

Run the interactive auth flow:

```bash
opencode providers
# or: opencode auth
```

This registers your API key(s) for whichever provider you use (Anthropic, OpenAI, Gemini, MiniMax, etc.).

Alternatively, add a custom provider directly in `opencode.json`:

```json
"provider": {
  "my-provider": {
    "npm": "@ai-sdk/anthropic",
    "options": {
      "baseURL": "https://api.my-provider.io/anthropic/v1",
      "apiKey": "{env:MY_PROVIDER_API_KEY}"
    },
    "models": { "model-name": { "name": "model-name" } }
  }
}
```

Then set which model omo agents use via `opencode models` and update `background_task.providerConcurrency` in `oh-my-openagent.json` to match your provider's rate limits.

---

## Install

```bash
git clone <this-repo>
cd claude-config

# Install everything (Claude Code + OpenCode)
./install.sh

# Claude Code only
./install.sh claude

# OpenCode + omo only
./install.sh opencode
```

Installer:

1. Checks prerequisites
2. Creates config dirs
3. Copies all config files (skips existing — no overwrites)
4. Makes scripts executable
5. For Claude Code: installs `caveman`, `beads`, `atlassian` plugins
6. For OpenCode: installs omo, writes `oh-my-openagent.json` and `tui.json` to `~/.config/opencode/`

---

## Per-project Setup

### Claude Code

```bash
cd ~/Projects/<org>/<project>
mkdir -p .claude .beads
cp ~/.claude/CLAUDE_TEMPLATE_PROJECT.md CLAUDE.md
touch .beads/PRIME.md
bd init
mempalace --palace ~/.mempalace/<project> init .
claude mcp add mempalace -s local -- mempalace-mcp --palace ~/.mempalace/<project>

# Verify
claude mcp list    # mempalace ✓ Connected
bd status
```

### OpenCode

```bash
cd ~/Projects/<org>/<project>

# opencode.json and AGENTS.md are already in this repo root.
# For other projects, copy them:
cp /path/to/claude-config/opencode.json .
cp /path/to/claude-config/AGENTS.md .

# Init beads and mempalace (same as Claude Code)
bd init
touch .beads/PRIME.md
mempalace --palace ~/.mempalace/<project> init .

# Set OMO_SCRIPTS so AGENTS.md scripts resolve — add to shell rc
export OMO_SCRIPTS="$HOME/.config/opencode/scripts"

# Verify
opencode models                 # your configured provider/model listed
opencode                        # /model → your chosen model; bd status works
npx oh-my-openagent doctor      # no blocking errors
```

---

## Workflow Overview

```
Session start
  └─ session-start.sh → bd prime + reload last checkpoint

New task
  └─ score-task.sh <id>         → SMALL / MEDIUM / LARGE
  └─ bd update <id> --claim
  └─ work
  └─ bd close <id>
  └─ checkpoint-write.sh <id>

Session end
  └─ session-end.sh → checkpoint-write + bd prime
```

---

## Hooks (Claude Code)

| Event              | Hook                                    |
| ------------------ | --------------------------------------- |
| `SessionStart`     | `caveman-activate.js` — caveman mode badge |
| `SessionStart`     | `agent_mail_register.sh` — register agent with agent-mail |
| `UserPromptSubmit` | `mempalace-prompt-hook.js` — inject memory context |
| `PreToolUse: Edit` | `file_reservations` — reserve file via agent-mail |
| `PostToolUse: Bash`| `check_inbox.sh` — poll agent-mail inbox |
| `Stop`             | `session-end.sh` — checkpoint + bd prime |

## Hooks (OpenCode — manual wiring)

omo has no 1:1 hook events yet. Use these workarounds:

| Claude Code hook | OpenCode equivalent |
| ---------------- | ------------------- |
| `SessionStart: session-start.sh` | Run manually or add to shell rc / tmux session init |
| `UserPromptSubmit: mempalace-prompt-hook.js` | Not needed — AGENTS.md instructs `mempalace_search` explicitly |
| `PreToolUse: Edit → file_reservations` | Not yet portable — gap accepted |
| `PostToolUse: Bash → check_inbox.sh` | Run as background tmux pane |
| `Stop: session-end.sh` | Add `trap '$OMO_SCRIPTS/session-end.sh' EXIT` in tmux pane |

---

## Plugins (Claude Code)

| Plugin      | Source                                                     |
| ----------- | ---------------------------------------------------------- |
| `caveman`   | `JuliusBrussee/caveman` — compressed AI communication     |
| `beads`     | `gastownhall/beads` — task management                      |
| `atlassian` | `claude-plugins-official` — Jira/Confluence integration    |

```bash
claude plugin install caveman@caveman
claude plugin install beads@beads-marketplace
claude plugin install atlassian@claude-plugins-official
```

---

## Verify

### Claude Code

```bash
claude mcp list                      # mempalace ✓ Connected
~/.claude/scripts/session-start.sh  # runs without errors
bd status
which bd bv mempalace jq
```

### OpenCode

```bash
opencode models                      # your configured provider/model listed
opencode                             # /model → your chosen model
bd status                            # beads working
npx oh-my-openagent doctor           # no blocking errors
```

---

## Troubleshooting

**mempalace failing to connect:**

```bash
mempalace-mcp --help
claude mcp remove mempalace -s local
claude mcp add mempalace -- mempalace-mcp
```

**mempalace "No palace found":**

```bash
mempalace --palace ~/.mempalace/<project> init .
```

**Scripts not executable:**

```bash
chmod +x ~/.claude/scripts/*.sh
chmod +x ~/.config/opencode/scripts/*.sh
```

**bd kv empty after /clear:**

```bash
bd kv list    # check for checkpoint:* keys
# If empty → paste new ticket, Claude creates tasks from scratch
```

**guard-claim.sh blocking all edits:**

```bash
bd update <id> --claim   # claim a task first
```

**Model not found:**

```bash
opencode models           # list all available models for your configured provider
opencode providers        # re-run auth if provider missing
```

**omo TUI sidebar missing:**

```bash
# Ensure tui.json exists at ~/.config/opencode/tui.json with:
# { "plugin": ["oh-my-openagent/tui"] }
npx oh-my-openagent doctor
```

**Concurrency throttled by provider:**

```bash
# Lower background_task.providerConcurrency in oh-my-openagent.json
# For 15+ agent fan-outs: use Claude Code ultracode instead
```
