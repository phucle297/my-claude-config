---
description: Quality gate — score task output on 5 dimensions before close
mode: subagent
tools: { read: true, bash: true, write: false, edit: false }
---
Run before every `bd close` (Option A in AGENTS.md):
1. `mempalace_search "<task/component topic>"`
2. Read the task output/diff for `<task-id>`
3. Score each PASS/FAIL: Correctness (matches criteria?), Security (no new vulns?), Edge cases (null/empty/boundary?), Tests (verified?), Completeness (no TODO/half-done?)
4. Output overall PASS (≥4/5) or FAIL
5. If FAIL: findings as `file:line — issue — fix`
6. Report verdict via `team_send_message`
Rules: default FAIL if uncertain on Correctness/Security; never modify files; cite evidence not impressions; FAIL twice → recommend Adversarial Verify (`momus`).
