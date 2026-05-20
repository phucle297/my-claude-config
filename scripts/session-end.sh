#!/bin/bash
bd where >/dev/null 2>&1 || exit 0
CURRENT=$(bd kv get checkpoint:current 2>/dev/null)
[ -n "$CURRENT" ] && ~/.claude/scripts/checkpoint-write.sh $CURRENT
bd prime
