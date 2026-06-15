#!/bin/bash
# Hardened: every bd call wrapped in `timeout` so a stuck IPC never holds
# the parent (nohup/setsid) process forever. Hook config marks this script
# async — Claude Code does not wait on it — but bd itself can still hang
# in a way that consumes CPU. Timeouts cap the blast radius.
timeout 3 bd where >/dev/null 2>&1 || exit 0
CURRENT=$(timeout 5 bd kv get checkpoint:current 2>/dev/null) || CURRENT=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "$CURRENT" ] && timeout 10 "${SCRIPT_DIR}/checkpoint-write.sh" "$CURRENT"
timeout 5 bd prime 2>/dev/null || true
