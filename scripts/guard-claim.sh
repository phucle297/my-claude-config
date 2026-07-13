#!/bin/bash
# Block file-edit tools when no bead is claimed in this repo.
# Works for Claude Code and Grok Build CLI hooks:
#   - exit 2 = explicit deny (both harnesses)
#   - stdout JSON decision=deny (Grok; Claude ignores unknown fields safely)
# Any agent's claim counts — subagents can edit under the orchestrator's claim.
# Skip silently when beads isn't initialised (repo without bd) so we never
# false-positive in non-bd projects.
bd where >/dev/null 2>&1 || exit 0

CLAIMED=$(bd list --claimed --json 2>/dev/null | jq length 2>/dev/null)
CLAIMED="${CLAIMED:-0}"
if [ "$CLAIMED" -eq 0 ]; then
  MSG="No task claimed. Run score-task.sh + bd update --claim before editing files."
  echo "ERROR: $MSG" >&2
  # Grok PreToolUse: JSON deny is authoritative. Claude: exit 2 blocks.
  printf '{"decision":"deny","reason":%s}\n' "$(printf '%s' "$MSG" | jq -Rs . 2>/dev/null || echo "\"$MSG\"")"
  exit 2
fi
exit 0
