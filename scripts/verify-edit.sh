#!/bin/bash
set -uo pipefail
# verify-edit.sh — PostToolUse hook for Edit|Write|MultiEdit.
# Auto-detects project type, runs only eslint (no typecheck), prints ONLY on
# error. Never blocks the workflow: always exits 0. Warning, not gate.
#
# Reads the hook JSON on stdin and extracts the edited file path.

# --- parse edited file path from hook stdin JSON ---
INPUT="$(cat 2>/dev/null || true)"
FILE=""
if command -v jq >/dev/null 2>&1; then
  FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)"
fi
# Fallback: grep the first file_path-looking field.
if [ -z "$FILE" ]; then
  FILE="$(printf '%s' "$INPUT" | grep -oE '"file_?[Pp]ath"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
fi

[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

# Only inspect JS/TS sources; skip everything else silently.
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
  *) exit 0 ;;
esac

# --- find project root (nearest package.json / tsconfig.json walking up) ---
find_up() {
  local name="$1" dir
  dir="$(cd "$(dirname "$FILE")" 2>/dev/null && pwd)" || return 1
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    [ -e "$dir/$name" ] && { printf '%s' "$dir"; return 0; }
    dir="$(dirname "$dir")"
  done
  return 1
}

PKG_DIR="$(find_up package.json || true)"

# timeout wrapper (skip if `timeout` absent)
run() { if command -v timeout >/dev/null 2>&1; then timeout 90 "$@"; else "$@"; fi; }

ERRORS=""

# --- lint: eslint config present → lint the single changed file ---
if [ -n "$PKG_DIR" ]; then
  HAS_ESLINT=""
  for c in .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml eslint.config.js eslint.config.mjs eslint.config.cjs; do
    [ -e "$PKG_DIR/$c" ] && { HAS_ESLINT="yes"; break; }
  done
  if [ "$HAS_ESLINT" = "yes" ] && command -v npx >/dev/null 2>&1; then
    OUT="$(cd "$PKG_DIR" && run npx --no-install eslint "$FILE" 2>&1)"
    if [ $? -ne 0 ] && [ -n "$OUT" ]; then
      ERRORS="${ERRORS}--- eslint ---\n$(printf '%s' "$OUT" | head -20)\n"
    fi
  fi
fi

# --- report (only on error). Never block. ---
if [ -n "$ERRORS" ]; then
  printf '\n⚠️  verify-edit found issues in %s:\n' "$FILE" >&2
  printf '%b' "$ERRORS" >&2
fi

exit 0
