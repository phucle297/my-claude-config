# Migrating from Claude Code to OpenCode

Uses [enulus/OpenPackage](https://github.com/enulus/OpenPackage) to convert Claude Code configs to OpenCode format automatically.

---

## Option A — Migrate your own `.claude/` setup

If you have an existing `.claude/` setup you want to bring to OpenCode:

```bash
# 1. Install OpenPackage globally
npm i -g opkg

# 2. In your workspace (where .claude/ lives)
opkg add .claude/           # generates openpackage.yml from your .claude/ directory

# 3. Install converted config for OpenCode
opkg install --platforms opencode
```

`opkg add .claude/` scans your `.claude/` folder and produces an `openpackage.yml` manifest. `opkg install --platforms opencode` then converts agent definitions, MCP config, and settings to the OpenCode format (`.opencode/agent/`, `opencode.json`, etc.).

---

## Option B — Install from this repo directly

```bash
# In your project directory
opkg install gh@phucle297/my-claude-config --platforms opencode

# This converts agents/*.md → .opencode/agent/ and wires MCP config.
# Then manually copy the configs OpenPackage doesn't handle:
cp /path/to/claude-config/opencode.json .
cp /path/to/claude-config/AGENTS.md .
# Configure oh-my-openagent.json at ~/.config/opencode/oh-my-openagent.json
```

> **Note:** `openpackage.yml` does not declare `scripts/` or `hooks/`. These are not copied by `opkg install`. Run `./install.sh opencode` first (or manually copy `scripts/` to `~/.config/opencode/scripts/`) before using per-project scripts.

---

## What OpenPackage handles automatically

| File / Config | Auto-converted? |
|---|---|
| `agents/*.md` → `.opencode/agent/*.md` | ✅ Yes — tool arrays, model names, permissions |
| `mcp` config → platform-specific format | ✅ Yes |
| `CLAUDE.md` → `AGENTS.md` | ❌ No — maintain manually |
| `opencode.json` (provider, plugin) | ❌ No — maintain manually |
| `oh-my-openagent.json` (omo config) | ❌ No — omo-specific, maintain manually |

## What still needs manual migration

| Config | Still needed? | Reason |
|---|---|---|
| `opencode.json` | ✅ Yes | Provider registration + MCP — OpenPackage doesn't generate this |
| `AGENTS.md` | ✅ Yes | Orchestrator rules — no CLAUDE.md → AGENTS.md auto-conversion |
| `oh-my-openagent.json` | ✅ Yes | omo agent behavior, team mode, concurrency — omo-specific |
| `.opencode/agent/*.md` | ⚠️ Generated | OpenPackage generates from `agents/` — edit source in `agents/`, not here |

---

## After migration — per-project setup

```bash
cd ~/Projects/<org>/<project>

# opencode.json and AGENTS.md must be in the project root.
bd init && touch .beads/PRIME.md
mempalace --palace ~/.mempalace/<project> init .

# OPENCODE_PROJECT_SLUG + OMO_SCRIPTS are auto-set by the opencode/claude
# shell wrapper that install.sh writes to your rc (slug = git root basename).
# No manual export needed. Override only for a custom slug:
#   export OPENCODE_PROJECT_SLUG="<custom>"

# Verify
opencode models
npx oh-my-openagent doctor
```

See the [OpenPackage docs](https://github.com/enulus/OpenPackage) for full reference.
