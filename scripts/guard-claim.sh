#!/bin/bash
# Block Edit/Write/MultiEdit when no bead is claimed in this repo.
# Any agent's claim counts — subagents can edit under the orchestrator's claim.
# Skip silently when beads isn't initialised (repo without bd) so we never
# false-positive in non-bd projects.
bd where >/dev/null 2>&1 || exit 0

CLAIMED=$(bd list --claimed --json 2>/dev/null | jq length 2>/dev/null)
CLAIMED="${CLAIMED:-0}"
if [ "$CLAIMED" -eq 0 ]; then
  echo "ERROR: No task claimed. Run score-task.sh + bd update --claim before editing files." >&2
  exit 1
fi
exit 0
