#!/bin/bash
# Load last checkpoint and reload context
bd where >/dev/null 2>&1 || exit 0

# Worktree context: if this dir was set up by worktree-task.sh, surface its
# epic + actor so tasks get nested + attributed even in a shared beads DB.
if [ -f ".beads-worktree.env" ]; then
  # shellcheck disable=SC1091
  . ./.beads-worktree.env 2>/dev/null || true
  echo "=== WORKTREE ==="
  echo "actor: ${BEADS_ACTOR:-?}   epic: ${BD_WORKTREE_EPIC:-?}"
  echo "If BEADS_ACTOR is unset in your shell, run: source .beads-worktree.env"
  echo "New beads auto-nest under this epic; bd writes attributed to this actor."
  echo "================"
fi

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
