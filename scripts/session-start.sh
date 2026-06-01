#!/bin/bash
# Load last checkpoint and reload context
bd where >/dev/null 2>&1 || exit 0

bd prime
LAST_ID=$(bd kv get checkpoint:current 2>/dev/null)
if [ -n "$LAST_ID" ]; then
  CHECKPOINT=$(bd kv get "checkpoint:$LAST_ID" 2>/dev/null)
  if [ -n "$CHECKPOINT" ]; then
    echo "=== CHECKPOINT ==="
    echo "$CHECKPOINT"
    SEARCH_KEYS=$(echo "$CHECKPOINT" | jq -r '.search_keys // ""' 2>/dev/null)
    if [ -n "$SEARCH_KEYS" ]; then
      echo "--- call mempalace_search: $SEARCH_KEYS"
    fi
    echo "=================="
  fi
fi
bd ready --json
