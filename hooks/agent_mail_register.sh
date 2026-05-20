#!/usr/bin/env bash
# Called at SessionStart — registers RedPond via macro_start_session for $PWD.
# Saves/loads registration_token from persistent store.
set -uo pipefail

PROJECT="$PWD"
AGENT="RedPond"
URL="http://127.0.0.1:8765/api/"
BEARER="dc5029ac32a9f350508a565af683205cf99f25c896b07c07bc53a9517877ce8c"
TOKEN_STORE="/home/permees/.claude/hooks/agent_mail_tokens.env"

SLUG=$(printf '%s' "$PROJECT" | tr '/' '-' | tr -cd 'a-zA-Z0-9-')
TOKEN_FILE="/tmp/mcp-regtoken-${SLUG}"

# Load existing registration token from persistent store
STORED_TOKEN=$(grep -m1 "^${SLUG}=" "$TOKEN_STORE" 2>/dev/null | cut -d= -f2- || echo "")

# Build args — pass registration_token if we have one
if [[ -n "$STORED_TOKEN" ]]; then
  MACRO_ARGS="{\"human_key\":$(printf '%s' "$PROJECT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),\"program\":\"claude-code\",\"model\":\"claude-sonnet-4-6\",\"agent_name\":\"$AGENT\",\"registration_token\":$(printf '%s' "$STORED_TOKEN" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}"
else
  MACRO_ARGS="{\"human_key\":$(printf '%s' "$PROJECT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),\"program\":\"claude-code\",\"model\":\"claude-sonnet-4-6\",\"agent_name\":\"$AGENT\"}"
fi

RESPONSE=$(curl -s --max-time 5 -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BEARER" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"tools/call\",\"params\":{\"name\":\"macro_start_session\",\"arguments\":${MACRO_ARGS}}}" 2>/dev/null || echo "")

if [[ -z "$RESPONSE" ]]; then exit 0; fi

REG_TOKEN=$(printf '%s' "$RESPONSE" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    content = d.get("result", {}).get("content", [{}])
    text = content[0].get("text", "{}") if content else "{}"
    obj = json.loads(text)
    print(obj.get("registration_token", ""))
except Exception:
    print("")
' 2>/dev/null || echo "")

if [[ -n "$REG_TOKEN" ]]; then
  echo "$REG_TOKEN" > "$TOKEN_FILE"
  # Persist to store (update or append)
  if grep -q "^${SLUG}=" "$TOKEN_STORE" 2>/dev/null; then
    sed -i "s|^${SLUG}=.*|${SLUG}=${REG_TOKEN}|" "$TOKEN_STORE"
  else
    echo "${SLUG}=${REG_TOKEN}" >> "$TOKEN_STORE"
  fi
fi
