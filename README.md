## Overview

`claude-config` is a personal setup for building a structured, scalable, and persistent workflow around AI coding agents. It supports **Claude Code** and **Grok Build CLI** — install either or both.

| | Claude Code | Grok Build CLI |
|---|---|---|
| Global rules | `~/.claude/CLAUDE.md` | `~/.grok/AGENTS.md` |
| Scripts | `~/.claude/scripts/` | `~/.grok/scripts/` |
| Agents | `~/.claude/agents/` | `~/.grok/agents/` |
| Hooks | `~/.claude/settings.json` | `~/.grok/hooks/workflow.json` |
| Config | `~/.claude/settings.json` | `~/.grok/config.toml` |
| Project template | `CLAUDE.md` | `AGENTS.md` |

Model and provider are user-configured; the workflow is model-agnostic.

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
| Supported AI tools      | Claude Code, Grok Build CLI — pick either or both          |
| beads (`bd`)            | Task management, claiming, checkpoints, orchestration      |
| dolt                    | Backend database required by beads                         |
| mempalace               | Cross-session persistent memory system                     |
| MCP servers             | Extend agents with external tools and memory               |
| caveman plugin          | Compressed AI communication mode (Claude; optional on Grok)|
| ponytail plugin         | Lazy-senior-dev mode: YAGNI, stdlib first, minimal diffs   |
| Hooks system            | Automates session lifecycle and safety checks              |

---

## Key Features

### Persistent AI Memory

`mempalace` retains long-term project knowledge across sessions — no rebuilding context every time. Works on both tools via MCP + the shared `mempalace-project` wrapper.

### Task-Based Workflow

`beads` provides structured task management with task claiming, checkpoints, progress tracking, session recovery, and orchestration support.

### Safe Autonomous Editing

Custom hooks prevent accidental edits unless a task is explicitly claimed (Claude `settings.json` hooks + Grok `~/.grok/hooks/workflow.json`).

### Session Recovery

Automatic checkpointing restores previous work context when a new session starts.

### Parallel Agent Orchestration

- **Claude Code** — agent teams / ultracode; agents in `~/.claude/agents/`
- **Grok Build** — `spawn_subagent` + agents in `~/.grok/agents/`

---

## Structure

```
claude-config/
├── install.sh                      # Installer — Claude Code and/or Grok Build
├── CLAUDE.md                       # Global Claude Code instructions (→ ~/.claude/CLAUDE.md)
├── AGENTS.md                       # Global Grok Build instructions (→ ~/.grok/AGENTS.md)
├── CLAUDE_TEMPLATE_PROJECT.md      # Per-project template (→ CLAUDE.md or AGENTS.md)
├── settings.json                   # Claude Code settings (→ ~/.claude/settings.json)
├── settings.example.jsonc          # Claude reference template (model / provider)
├── config.example.toml             # Grok Build reference template (→ optional merge)
├── agents/                         # Agent definitions (shared source)
│   ├── frontend-dev.md
│   ├── reviewer.md
│   ├── security-reviewer.md
│   ├── test-writer.md
│   ├── debugger.md
│   ├── planner.md
│   └── quality-gate.md
├── skills/                         # Skills (→ ~/.claude/skills/ and ~/.grok/skills/)
├── hooks/
│   ├── *.js / *.sh                 # Claude hooks (→ ~/.claude/hooks/)
│   └── grok-workflow.json          # Grok hooks (→ ~/.grok/hooks/workflow.json)
└── scripts/                        # Workflow scripts (→ ~/.claude/scripts/ and ~/.grok/scripts/)
    ├── session-start.sh
    ├── session-end.sh
    ├── checkpoint-write.sh
    ├── guard-claim.sh
    ├── score-task.sh
    ├── jira-to-bd.sh
    ├── worktree-task.sh
    ├── verify-edit.sh
    └── adversarial-verify.js
```

Scripts install location:

| Platform | Scripts go to |
|---|---|
| Claude Code | `~/.claude/scripts/` |
| Grok Build | `~/.grok/scripts/` |

---

## Prerequisites

#### Shared

```bash
# dolt (required by beads)
curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash

# beads (bd CLI)
curl -sSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash

# mempalace — https://github.com/mempalace/mempalace
# jq
sudo apt install jq   # or brew install jq
```

#### Claude Code

```bash
# Download from https://claude.ai/download
```

#### Grok Build CLI

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
grok login   # browser auth on first use
```

---

### Jira (Atlassian) — manual

The Atlassian integration is **intentionally NOT auto-installed**.

**Claude Code:**

```bash
claude plugin install atlassian@claude-plugins-official
```

**Grok Build:** add Atlassian as an MCP server (remote) in `~/.grok/config.toml` or via:

```bash
grok mcp add --transport http atlassian https://mcp.atlassian.com/v1
```

(Use the official Atlassian MCP URL for your setup; OAuth may be required.)

---

## Install

```bash
git clone <this-repo>
cd claude-config
./install.sh
```

Running with no args **auto-detects** Claude Code and Grok Build and shows a menu.

```bash
./install.sh claude    # Claude Code only
./install.sh grok      # Grok Build only
./install.sh all       # both
./install.sh deps      # dependencies only
```

| Tool | Auto-installed? |
|---|---|
| jq | ✅ apt / brew |
| Node.js + npx | ✅ via fnm |
| uv (Python) | ✅ curl install |
| dolt | ✅ curl install |
| beads (`bd`) | ✅ curl install |
| grok CLI | ✅ curl install (when grok selected) |
| mempalace | ⚠️ manual |
| claude CLI | ⚠️ manual — https://claude.ai/download |

**Safety:**

- `~/.claude/settings.json` is never overwritten if it already exists
- `~/.grok/config.toml` is never overwritten (auth + sessions preserved)
- `./install.sh grok` never wipes `~/.grok` (unlike Claude, which rebuilds `~/.claude` from source)

---

## Per-project Setup

### Claude Code

```bash
cd ~/Projects/<org>/<project>
mkdir -p .claude .beads
cp ~/.claude/CLAUDE_TEMPLATE_PROJECT.md CLAUDE.md
touch .beads/PRIME.md
bd init
mempalace --palace ~/.mempalace/projects/$(basename "$PWD") init . --yes --no-llm

claude mcp list    # mempalace ✓ (user-scope from install)
bd status
```

### Grok Build CLI

```bash
cd ~/Projects/<org>/<project>
mkdir -p .grok .beads
cp ~/.grok/AGENTS_TEMPLATE_PROJECT.md AGENTS.md
touch .beads/PRIME.md
bd init
mempalace --palace ~/.mempalace/projects/$(basename "$PWD") init . --yes --no-llm

# Optional: both CLAUDE.md and AGENTS.md can coexist — Grok loads both.
grok mcp list
bd status
```

> **Note:** `./install.sh` registers mempalace MCP once per tool at **user scope**
> via the `mempalace-project` wrapper. It auto-resolves to
> `~/.mempalace/projects/<repo>` from the launch cwd.

---

## Workflow Overview

```
Session start
  └─ session-start.sh → bd prime + reload last checkpoint

New task
  └─ score-task.sh <id>            → SMALL / MEDIUM / LARGE
  └─ bd update <id> --claim
  └─ work
  └─ Quality Gate (quality-gate agent)  → 5-dimension review → PASS≥4/5 or FAIL
       PASS → bd close <id> → checkpoint-write.sh <id>
       FAIL → fix → retry (max 2x) → escalate to adversarial-verify if still failing

Session end
  └─ session-end.sh → checkpoint-write + bd prime
```

---

## Examples

### Fix a bug (SMALL task) — Claude

```bash
bd create "Fix login redirect loop on mobile" --json
# → my-app-4xz

~/.claude/scripts/score-task.sh my-app-4xz
bd update my-app-4xz --claim --json

claude
# prompt: "Fix login redirect loop on mobile. Task my-app-4xz claimed."

bd close my-app-4xz "fixed: check for existing session before redirect" --json
~/.claude/scripts/checkpoint-write.sh my-app-4xz
```

### Fix a bug (SMALL task) — Grok

```bash
bd create "Fix login redirect loop on mobile" --json
# → my-app-4xz

~/.grok/scripts/score-task.sh my-app-4xz
bd update my-app-4xz --claim --json

grok
# prompt: "Fix login redirect loop on mobile. Task my-app-4xz claimed."

bd close my-app-4xz "fixed: check for existing session before redirect" --json
~/.grok/scripts/checkpoint-write.sh my-app-4xz
```

### Jira ticket intake

```bash
# Claude paths shown; use ~/.grok/scripts/ for Grok
BD_ID=$(~/.claude/scripts/jira-to-bd.sh WLB-2046)
~/.claude/scripts/score-task.sh $BD_ID
bd update $BD_ID --claim --json
claude   # or: grok
```

### Session recovery

```bash
~/.claude/scripts/checkpoint-write.sh <current-task-id>   # or ~/.grok/scripts/
# After /clear or new session:
~/.claude/scripts/session-start.sh
claude   # or: grok — "Resume work. session-start output: <paste>"
```

---

## Hooks

### Claude Code

Wired in `settings.json`:

| Event | Hook | Purpose |
| ----- | ---- | ------- |
| `SessionStart` | `caveman-activate.js` + `session-start.sh` | Mode + checkpoint reload |
| `UserPromptSubmit` | `mempalace-prompt-hook.js` | Inject memory |
| `PreToolUse` (Edit/Write) | `guard-claim.sh` | Block edits without claim |
| `PostToolUse` (Edit/Write) | `verify-edit.sh` | Post-edit lint (async) |
| `Stop` | `session-end.sh` | Checkpoint write |

> **Provider routing:** repo `settings.json` is minimal (hooks + plugins only).
> Copy `model` + `env` from `settings.example.jsonc` for MiniMax / custom endpoints.

### Grok Build CLI

Wired in `~/.grok/hooks/workflow.json` (always trusted — user-global):

| Event | Hook | Purpose |
| ----- | ---- | ------- |
| `SessionStart` | `session-start.sh` | Checkpoint reload |
| `PreToolUse` (edit tools) | `guard-claim.sh` | Block edits without claim |
| `PostToolUse` (edit tools) | `verify-edit.sh` | Post-edit lint |
| `SessionEnd` / `Stop` | `session-end.sh` | Checkpoint write |

Grok maps Claude tool names in matchers (`Edit`/`Write` → `search_replace`). Optional UI/model settings: merge from `config.example.toml` into `~/.grok/config.toml`.

---

## Plugins

### Claude Code

| Plugin | Marketplace | Purpose |
| ------ | ----------- | ------- |
| `caveman` | `JuliusBrussee/caveman` | Compressed communication |
| `ponytail` | `DietrichGebert/ponytail` | Lazy senior dev / YAGNI mode |
| `beads` | `gastownhall/beads` | Task + checkpoint workflow |
| `superpowers` | `claude-plugins-official` | Skill bundle |
| `context7` | `claude-plugins-official` | Live docs |
| `code-simplifier` | `claude-plugins-official` | Diff simplification |
| `skill-creator` | `claude-plugins-official` | Author skills |

Installer: if `~/.claude` exists it is moved to `~/.claude.bak-<ts>`, then rebuilt. `settings.json` (provider keys) and `history.jsonl` are restored from the bak when present.

### Grok Build CLI

`./install.sh grok` best-effort installs:

```bash
grok plugin install gastownhall/beads#plugins/beads --trust
grok plugin install JuliusBrussee/caveman#plugins/caveman --trust
grok plugin install DietrichGebert/ponytail --trust
```

If `~/.grok` exists it is moved to `~/.grok.bak-<ts>`, then rebuilt. Runtime state (`auth.json`, `config.toml`, sessions, worktrees, installed plugins, …) is restored from the bak; workflow files (`AGENTS.md`, `scripts/`, `agents/`, `hooks/`, `skills/`) come from this repo.

Failures are non-fatal (plugin layout may change). Manage via `/plugins` in the TUI.

---

## Verify

### Claude Code

```bash
claude mcp list
~/.claude/scripts/session-start.sh
bd status
```

### Grok Build CLI

```bash
grok --version
grok mcp list
ls ~/.grok/scripts ~/.grok/agents ~/.grok/hooks/workflow.json
~/.grok/scripts/session-start.sh
bd status
```

---

## Troubleshooting

**mempalace failing (Claude):**

```bash
claude mcp remove mempalace -s user
claude mcp add mempalace -s user -- "$HOME/.local/bin/mempalace-project"
```

**mempalace failing (Grok):**

```bash
grok mcp remove mempalace --scope user
grok mcp add mempalace -- "$HOME/.local/bin/mempalace-project"
grok mcp doctor mempalace
```

**mempalace "No palace found":**

```bash
mempalace --palace ~/.mempalace/projects/$(basename "$PWD") init . --yes --no-llm
```

**Scripts not executable:**

```bash
chmod +x ~/.claude/scripts/*.sh
chmod +x ~/.grok/scripts/*.sh
```

**guard-claim.sh blocking all edits:**

```bash
bd update <id> --claim
```

**Grok hooks not running:**

```bash
ls ~/.grok/hooks/workflow.json
# Global hooks are always trusted; project hooks need /hooks-trust
```
