#!/bin/bash
ID="${1:-}"
[ -z "$ID" ] && { echo "ERROR: ID required. Usage: checkpoint-write.sh <bd-id>" >&2; exit 1; }
# Extract keys from bd task
KEYS=$(bd show "$ID" --json 2>/dev/null | jq -r '(if type == "array" then .[0] else . end) | [.title, (.labels // [] | .[])] | join(" ")' 2>/dev/null || echo "")
QUEUE=$(bd children "$ID" --json 2>/dev/null | jq -r '[.[]|select(.status!="closed")|.id] | join(" ")' 2>/dev/null || echo "")
NEXT=$(bd ready --json | jq -r '.[0].id // ""')

PAYLOAD="{\"search_keys\":\"$KEYS\",\"queue\":\"$QUEUE\",\"next\":\"$NEXT\"}"
bd kv set checkpoint:$ID "$PAYLOAD"
bd kv set checkpoint:current $ID

# Update PRIME.md to auto-inject into every session even after compact
mkdir -p .beads
echo "## Last Checkpoint
search: $KEYS
queue: $QUEUE
next: $NEXT" >.beads/PRIME.md

# Save the checkpoint address to diary file
DIARY=~/.claude/memory/diary.md
mkdir -p "$(dirname "$DIARY")"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) checkpoint: bd kv get checkpoint:$ID | mempalace_search $KEYS" >>"$DIARY"

# Auto-close parent if all children are closed
PARENT=$(bd show "$ID" --json | jq -r '(if type == "array" then .[0] else . end) | .parent_id // ""')
if [ -n "$PARENT" ]; then
  OPEN_SIBS=$(bd list --parent "$PARENT" --json 2>/dev/null | jq '[.[] | select(.status != "closed")] | length')
  if [ "$OPEN_SIBS" = "0" ]; then
    bd close "$PARENT" --reason="all children closed" 2>/dev/null
  fi
fi
