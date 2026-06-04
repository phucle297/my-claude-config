#!/bin/bash
# OpenAI Codex CLI config install module. Sourced by install.sh.
# Depends on lib/common.sh (logging, $CODEX_DIR, $SCRIPT_DIR, helpers).

setup_codex_dirs() {
  mkdir -p "$CODEX_DIR/scripts"
  info "Codex dirs ready"
}

install_codex_scripts() { install_scripts_to "$CODEX_DIR/scripts"; }

install_codex_instructions() {
  # Back up only the config file we overwrite — NOT the whole dir. The Codex
  # CLI stores its runtime binary under ~/.codex/packages/ and a launcher
  # symlink at ~/.local/bin/codex points into it, so moving the dir aside
  # (backup_tracked_dir) would dangle the symlink and break `codex`.
  local dst="$CODEX_DIR/instructions.md"
  if [ -f "$dst" ]; then
    local bak="${dst}.bak-$(date +%Y%m%d%H%M%S)"
    cp -f "$dst" "$bak" && info "Backed up $dst → $bak"
  fi
  cp -f "$SCRIPT_DIR/AGENTS.md" "$dst"
  info "Installed $dst"
}

# Register MCP servers in ~/.codex/config.toml to match Claude's set:
#   - context7  (stdio) — registered via `codex mcp add` (no auth)
#   - mcp-agent-mail (streamable HTTP) — needs a STATIC bearer header, which
#     `codex mcp add` cannot set (it only supports --bearer-token-env-var),
#     so we read the token from ~/.claude.json and append the TOML table.
# Both steps are idempotent: `codex mcp get` skips servers already present.
install_codex_mcp() {
  if ! has codex; then
    warn "codex not in PATH — skipping MCP registration (run: ./install.sh codex after install)"
    return
  fi
  touch "$CODEX_DIR/config.toml"
  install_codex_context7
  install_codex_mcp_agent_mail
  install_codex_mempalace
}

# context7 — stdio, no auth
install_codex_context7() {
  if codex mcp get context7 &>/dev/null; then
    info "context7 MCP already registered"
    return
  fi
  codex mcp add context7 -- npx -y @upstash/context7-mcp \
    && info "Registered context7 MCP" \
    || warn "Failed to register context7 MCP"
}

# mcp-agent-mail — streamable HTTP with a STATIC bearer header, which
# `codex mcp add` cannot set (only --bearer-token-env-var), so we read the
# token from ~/.claude.json and append the TOML table directly.
install_codex_mcp_agent_mail() {
  if codex mcp get mcp-agent-mail &>/dev/null; then
    info "mcp-agent-mail MCP already registered"
    return
  fi
  if ! has jq; then
    warn "jq not found — cannot read mcp-agent-mail token. Skipping mcp-agent-mail MCP."
    return
  fi
  local cfg="$CODEX_DIR/config.toml"
  local token
  token="$(jq -r '.mcpServers["mcp-agent-mail"].headers.Authorization // empty' \
    "$HOME/.claude.json" 2>/dev/null | sed 's/^Bearer //')"
  if [ -z "$token" ]; then
    warn "mcp-agent-mail token not in ~/.claude.json — skipping. Add manually to $cfg:"
    warn '  [mcp_servers.mcp-agent-mail]'
    warn '  url = "http://127.0.0.1:8765/api/"'
    warn '  http_headers = { Authorization = "Bearer <TOKEN>" }'
    return
  fi
  cat >> "$cfg" <<EOF

[mcp_servers.mcp-agent-mail]
url = "http://127.0.0.1:8765/api/"
http_headers = { Authorization = "Bearer $token" }
EOF
  info "Registered mcp-agent-mail MCP (token from ~/.claude.json)"
}

# mempalace — per-project palace via the cwd-deriving wrapper. Codex spawns
# stdio MCP servers with cwd = the project dir (verified), so one global
# registration yields a per-project palace: ~/.mempalace/projects/<repo>.
install_codex_mempalace() {
  if codex mcp get mempalace &>/dev/null; then
    info "mempalace MCP already registered"
    return
  fi
  has mempalace-mcp || warn "mempalace-mcp not on PATH — wrapper will fail until installed"
  install_mempalace_wrapper || return
  codex mcp add mempalace -- "$HOME/.local/bin/mempalace-project" \
    && info "Registered per-project mempalace MCP" \
    || warn "Failed to register mempalace MCP"
}

print_codex_next_steps() {
  echo ""
  echo "=== Codex setup done ==="
  echo ""
  echo "mempalace is registered ONCE and auto-resolves to a per-project"
  echo "palace from the repo cwd: ~/.mempalace/projects/<repo>"
  echo "(launched outside a repo -> shared default palace ~/.mempalace/palace)."
  echo ""
  echo "Per-project setup (run once per repo):"
  echo "  cd ~/Projects/<org>/<project>"
  echo "  cp ~/.codex/instructions.md AGENTS.md"
  echo "  bd init && touch .beads/PRIME.md"
  echo "  mempalace --palace ~/.mempalace/projects/\$(basename \$PWD) init . --yes --no-llm"
  echo ""
  echo "Set env var (add to shell rc):"
  echo "  export CODEX_SCRIPTS=\"\$HOME/.codex/scripts\""
  echo ""
  echo "Verify MCP servers (context7 + mcp-agent-mail + mempalace):"
  echo "  codex mcp list        # or /mcp inside a codex session"
}

# Full Codex install cycle.
# NOTE: no backup_tracked_dir here — ~/.codex is shared with the Codex CLI
# runtime (packages/, tmp/) and a launcher symlink in ~/.local/bin points
# into it. Moving the dir aside breaks `codex`. Config files are overwritten
# in place; install_codex_instructions backs up the one file it replaces.
install_codex() {
  step "Configuring Codex..."
  setup_codex_dirs
  install_codex_scripts
  install_codex_instructions
  install_codex_mcp
  print_codex_next_steps
}
