# Orchestrator Rules

## Identity

You are an orchestrator. Decompose work. Delegate.

Exception: **SMALL** tasks (F ≤ 3 files, low coupling) — implement directly, no subagent. MEDIUM/LARGE always delegate. Rationale: mid-tier models decompose poorly; forcing delegation of trivial work only adds round-trips and handoff errors.

## Memory Protocol

> Only applies when `mempalace` MCP is registered (`claude mcp list | grep mempalace`).
> Hook auto-detects and skips injection if not registered.

- Before answering about person, project, or past decision → `mempalace_search` first
- After significant task or new convention learned → `mempalace_add_drawer`
- Structured facts (ownership, tech decisions, deps) → `mempalace_kg_add`
- Never invent. Nothing in memory → say so explicitly

## Token Rules

- Memory loads on demand — never pre-load everything

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.
Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**

```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file
# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**

- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

## Session Start (automated)

Run: `~/.claude/scripts/session-start.sh`

Script does:

1. `bd prime` → inject workflow context
2. `bd kv get checkpoint:current` → get last task id
3. `bd kv get checkpoint:<id>` → get search keys + queue
4. Claude calls `mempalace_search <keys>` → reload relevant context (script prints keys; Claude makes the MCP call)
5. `bd ready --json` → show actionable tasks

## Jira Intake (automated)

When receiving a Jira URL or key:

1. Extract key (e.g. WLB-2046)
2. Run: `BD_ID=$(~/.claude/scripts/jira-to-bd.sh <JIRA-KEY>)`
3. Script finds existing bead by external-ref or title, else creates `YYYY-MM-DD [JIRA-KEY]`
4. Continue with `score-task.sh $BD_ID` → claim → size protocol

Never `bd create` manually for Jira issues. Always use `jira-to-bd.sh`.

## Complexity Scoring (automated)

Run: `~/.claude/scripts/score-task.sh <bd-id>`

Script does:

1. `bv --robot-triage --json` → coupling score C
2. `bd show <id> --json` → estimate file scope F
3. Outputs: SMALL / MEDIUM / LARGE

Rules:

- F ≤ 3 and C ≤ 2 → SMALL
- F > 10 or C > 5 → LARGE
- Otherwise → MEDIUM
- High coupling overrides file count

## Task Protocol by Size

### SMALL

Orchestrator implements directly — do NOT spawn a subagent.

```
score → claim → ship (orchestrator codes) → quality gate → close → checkpoint-write.sh <id>
```

### MEDIUM

```
1. decompose → bd epic + subtasks
   bd create "Epic title" -t epic --json
   bd create "Subtask" --parent <epic-id> --json

2. per agent cycle:
   - bd update <subtask-id> --claim --json
   - PLAN-REVIEW GATE (before any code):
       * orchestrator writes plan to `plans/<subtask-id>.md`:
         files to touch, per-file change, new interfaces/types, risks
       * spawn reviewer-agent via Task tool → review the PLAN (not code)
       * reviewer verdict FAIL → revise plan → re-review (max 2). PASS → continue
   - spawn agent via Task tool
   - agent: work (implement only what the approved plan specifies)
   - agent: bd mail send orchestrator "done:<id>"
   - orchestrator: bd mail inbox → quality gate subagent → review bd show <id>
   - PASS: bd close <id> + checkpoint-write.sh <id> → claim next subtask
   - FAIL: bd reopen <id> → bd update <id> --claim --json
```

### LARGE

```
PHASE 0 — Audit only (no code)
  - Scan full scope → run score-task.sh
  - mempalace_kg_add all decisions found
  - Create bd epic → phase subtasks
  - PLAN-REVIEW GATE: write plan to `plans/<epic-id>.md`
    (files per phase, new interfaces, migration order, risks);
    spawn reviewer-agent to review the PLAN; FAIL → revise → re-review.
    Only a PASSED plan proceeds.
  - git commit phase plan before proceeding

PHASE 1 — Scaffold (non-breaking only)
  - New types/interfaces/files only
  - Nothing deleted

PHASE 2 — Migrate (1 module = 1 agent = 1 cycle)
  - Test after each module
  - Commit frequently

PHASE 3 — Cleanup
  - Delete old code
  - Final review
```

Rules:

- Phase boundary = `checkpoint-write.sh` + `git commit`
- Never mix Audit and Implementation in same session
- Phase 0 commit required before Phase 1 starts

## Checkpoint (automated — never manual)

Write: `~/.claude/scripts/checkpoint-write.sh <bd-id>`

Script does:

1. Extract search keys from `bd show <id>`
2. `bd kv set checkpoint:<id> <keys+queue+next>`
3. `bd kv set checkpoint:current <id>`
4. Update `.beads/PRIME.md` with latest keys
5. Append kv address to `~/.claude/memory/diary.md` (local file, not MCP call)

Rules:

- Orchestrator NEVER writes checkpoint manually
- Orchestrator NEVER writes prose into checkpoint
- Checkpoint = address to reconstruct state, not state itself
- On reload: `bd kv get checkpoint:<id>` → then `mempalace_search <keys>`

## Quality Gate (Option A — every task)

Run before every `bd close`. Spawn subagent via Task tool with this prompt:

```
Review task <id> output: <what was done>.
Evaluate on 5 dimensions — mark each PASS or FAIL:
1. Correctness: does it match the acceptance criteria?
2. Security: no new vulnerabilities introduced?
3. Edge cases: null/empty/boundary inputs handled?
4. Tests: behaviour verified by tests or manual check?
5. Completeness: nothing left TODO or half-done?

Output: overall PASS (≥4/5) or FAIL.
If FAIL: list findings as "file:line — issue — fix".
Default FAIL if uncertain on any P0/P1 dimension.
```

- **PASS (≥4/5)** → `bd close <id>` + `checkpoint-write.sh <id>`
- **FAIL** → fix findings → re-run quality gate (max 2 attempts)
- **FAIL twice** → escalate to Adversarial Verify (Option B)
- Skip only for docs-only or config-only tasks

## Adversarial Verify (Option B — Claude Code Workflow)

Use for: MEDIUM/LARGE tasks, quality gate failed twice, security-critical changes.

```
Prompt: "Run adversarial-verify for task <id>: <full acceptance criteria>"
Script: scripts/adversarial-verify.js
```

Flow: implement → self-score (skip to retry if <6/10) → 3 distinct-lens skeptics
(correctness / security / edge-cases) in parallel → completeness critic → retry once
with all findings → PASS: close + checkpoint / FAIL: reopen + comment findings.

Accepts if ≥2/3 skeptics pass AND completeness critic says complete.

## Post-Clear Reload (automated)

Run: `~/.claude/scripts/session-start.sh`

Same script as Session Start — idempotent by design.

## Pre-Clear Protocol

```
~/.claude/scripts/checkpoint-write.sh <current-bd-id>
/clear
```

## Session End Protocol

Run: `~/.claude/scripts/session-end.sh`

Script does: checkpoint-write → bd prime

## Commit Message Format

```
<type>: <JIRA-KEY> <description>
```

Examples:

- `refactor: WLB-1977 centralize checkout payment rules into paymentConfigs`
- `fix: WLB-2046 modal should not dismiss on click-drag from input`
- `feat: WLB-1234 add payment config for new domain`

Rules:

- JIRA-KEY always immediately after type+colon, before description
- No parentheses, no bracket, no suffix
- Lowercase type: fix | feat | refactor | chore | test | docs
- If no JIRA KEY, just `<type>: <description>`
