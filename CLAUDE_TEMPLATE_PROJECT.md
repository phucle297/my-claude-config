# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->

## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready                    # Find available work
bd show <id>                # View issue details
bd update <id> --claim      # Claim work (sets assignee + in_progress)
bd close <id>               # Complete work
bd reopen <id>              # Re-queue failed work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT create MEMORY.md files

## Task Management (AI only)

- Score first: `~/.claude/scripts/score-task.sh <bd-id>`
- Claim: `bd update <id> --claim --json`
- Close: `bd close <id> --json`
- Re-queue: `bd reopen <id>` → `bd update <id> --claim --json`
- Never TodoWrite — bd only

## Agent Communication

- Assign work: `bd update <id> --claim --json`
- Signal done: `bd mail send orchestrator "done:<id>"`
- Orchestrator reads: `bd mail inbox`

## Large Task Gate

Before any task touching >5 files:

1. `score-task.sh <id>` → must output LARGE
2. Create bd epic → phase subtasks
3. Phase 0 commit required before Phase 1

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** — create issues for anything needing follow-up
2. **Run quality gates** (if code changed) — tests, linters, builds
3. **Update issue status** — close finished work, reopen failed items
4. **PUSH TO REMOTE** — MANDATORY:

   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```

5. **Clean up** — clear stashes, prune remote branches
6. **Verify** — all changes committed AND pushed
7. **Hand off** — provide context for next session

**CRITICAL RULES:**

- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing — that leaves work stranded locally
- NEVER say "ready to push when you are" — YOU must push
- If push fails, resolve and retry until it succeeds

<!-- END BEADS INTEGRATION -->

## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

_Add your project-specific conventions here_
