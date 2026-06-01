#!/bin/bash
bd where >/dev/null 2>&1 || exit 0
CURRENT=$(bd kv get checkpoint:current 2>/dev/null)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$CURRENT" ] && "${SCRIPT_DIR}/checkpoint-write.sh" "$CURRENT"
bd prime
