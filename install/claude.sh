#!/bin/bash
# Claude Code config install module. Sourced by install.sh.
# Depends on lib/common.sh (logging, has, $CLAUDE_DIR, $SCRIPT_DIR, helpers).

setup_claude_dirs() {
  mkdir -p "$CLAUDE_DIR/scripts" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/memory" "$CLAUDE_DIR/hooks"
  info "Claude dirs ready"
}

install_claude_scripts() { install_scripts_to "$CLAUDE_DIR/scripts"; }

install_agents() {
  for f in "$SCRIPT_DIR/agents/"*.md; do
    [ -f "$f" ] || continue
    cp -f "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
  done
  info "Installed agents to $CLAUDE_DIR/agents"
}

install_skills() {
  [ -d "$SCRIPT_DIR/skills" ] || return 0
  for d in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$d" ] || continue
    cp -rf "$d" "$CLAUDE_DIR/skills/"
  done
  info "Installed skills to $CLAUDE_DIR/skills"
}

install_hooks() {
  for f in "$SCRIPT_DIR/hooks/"*.sh "$SCRIPT_DIR/hooks/"*.js; do
    [ -f "$f" ] || continue
    cp -f "$f" "$CLAUDE_DIR/hooks/$(basename "$f")"
  done
  # Re-apply executable bit on .sh files.
  find "$CLAUDE_DIR/hooks" -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} +
  info "Installed hooks to $CLAUDE_DIR/hooks"
}

install_settings() {
  # NEVER overwrite an existing user settings.json — it likely contains a
  # personal model / provider / env config that took time to tune. The repo
  # settings.json is a MINIMAL default (hooks + plugins only, no provider).
  # See settings.example.jsonc for the full reference template including a
  # minimax/MiniMax provider-routing example.
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    warn "$CLAUDE_DIR/settings.json already exists — preserving your config"
    warn "  To customize: edit ~/.claude/settings.json directly"
    warn "  Reference template: $SCRIPT_DIR/settings.example.jsonc"
    return
  fi
  cp -f "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
  info "Installed $CLAUDE_DIR/settings.json (minimal default — see settings.example.jsonc to add a provider)"
}

install_claude_md() {
  cp -f "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  cp -f "$SCRIPT_DIR/CLAUDE_TEMPLATE_PROJECT.md" "$CLAUDE_DIR/CLAUDE_TEMPLATE_PROJECT.md"
  info "Installed CLAUDE.md + CLAUDE_TEMPLATE_PROJECT.md"
}

install_claude_plugins() {
  if ! has claude; then
    warn "claude CLI not found — skipping plugin install."
    warn "Install Claude Code from https://claude.ai/download then re-run: ./install.sh"
    return
  fi
  step "Installing Claude marketplaces..."
  # Register marketplaces first so the install commands can resolve them.
  # `claude plugin marketplace add` is idempotent — it refreshes the cache if
  # the marketplace already exists. extraKnownMarketplaces in settings.json
  # is NOT enough: the CLI's marketplace cache must be initialized or every
  # install errors with "Plugin not found in marketplace".
  claude plugin marketplace add JuliusBrussee/caveman              2>/dev/null || warn "caveman marketplace add failed"
  claude plugin marketplace add gastownhall/beads                  2>/dev/null || warn "beads marketplace add failed"
  claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || warn "official marketplace add failed"
  claude plugin marketplace add DietrichGebert/ponytail            2>/dev/null || warn "ponytail marketplace add failed"

  step "Installing Claude plugins..."
  # Order must match enabledPlugins in settings.json.
  claude plugin install caveman@caveman                         || warn "caveman install failed"
  claude plugin install beads@beads-marketplace                 || warn "beads install failed"
  claude plugin install superpowers@claude-plugins-official     || warn "superpowers install failed"
  claude plugin install context7@claude-plugins-official        || warn "context7 install failed"
  claude plugin install code-simplifier@claude-plugins-official || warn "code-simplifier install failed"
  claude plugin install skill-creator@claude-plugins-official   || warn "skill-creator install failed"
  claude plugin install ponytail@ponytail                       || warn "ponytail install failed"
  info "Claude plugins installed"
}

# Register a single user-scope mempalace MCP that resolves to a per-project
# palace at launch (via the mempalace-project wrapper). One registration ->
# every repo gets its own memories. Replaces the old per-repo
# `claude mcp add mempalace -s local` step.
install_claude_mempalace() {
  if ! has claude; then
    warn "claude CLI not found — skipping mempalace MCP registration"
    return
  fi
  has mempalace-mcp || warn "mempalace-mcp not on PATH — wrapper will fail until installed"
  install_mempalace_wrapper || return

  # Drop a stale non-per-project mempalace if one is registered (e.g. an old
  # `mempalace-mcp` with no --palace). `claude mcp get` resolves across scopes.
  if claude mcp get mempalace &>/dev/null; then
    claude mcp remove mempalace -s user  &>/dev/null || true
    claude mcp remove mempalace -s local &>/dev/null || true
  fi
  claude mcp add mempalace -s user -- "$HOME/.local/bin/mempalace-project" \
    && info "Registered per-project mempalace MCP (user scope)" \
    || warn "Failed to register mempalace MCP"
}

print_claude_next_steps() {
  echo ""
  echo "=== Claude Code setup done ==="
  echo ""
  echo "mempalace is registered ONCE (user scope) and auto-resolves to a"
  echo "per-project palace from the repo cwd: ~/.mempalace/projects/<repo>"
  echo "(launched outside a repo -> shared default palace ~/.mempalace/palace)."
  echo ""
  echo "Per-project setup (run once per repo):"
  echo "  cd ~/Projects/<org>/<project>"
  echo "  mkdir -p .claude .beads && touch .beads/PRIME.md"
  echo "  cp ~/.claude/CLAUDE_TEMPLATE_PROJECT.md CLAUDE.md"
  echo "  bd init"
  echo "  mempalace --palace ~/.mempalace/projects/\$(basename \$PWD) init . --yes --no-llm"
  echo ""
  echo "Verify:"
  echo "  claude mcp list && bd status"
}

# Full Claude Code install cycle.
# If ~/.claude already exists: move it to ~/.claude.bak-<ts>, then rebuild.
# Restores settings.json from the bak when present so provider/env keys survive.
install_claude() {
  step "Configuring Claude Code..."
  local bak=""
  bak="$(backup_tracked_dir "$CLAUDE_DIR" || true)"
  setup_claude_dirs
  install_claude_md
  install_claude_scripts
  install_agents
  install_skills
  install_hooks
  install_settings
  # Prefer the user's previous settings (API keys / provider routing) over the
  # minimal repo default when a backup exists.
  if [ -n "$bak" ] && [ -f "$bak/settings.json" ]; then
    cp -f "$bak/settings.json" "$CLAUDE_DIR/settings.json" \
      && info "Restored settings.json from backup (provider/env preserved)"
  fi
  restore_from_bak "$bak" "$CLAUDE_DIR" history.jsonl
  ensure_claude_ponytail_settings
  install_claude_plugins
  install_claude_mempalace
  print_claude_next_steps
}

# After restoring a bak settings.json, pin ponytail marketplace + enable flag
# without clobbering the user's other plugins/provider env.
ensure_claude_ponytail_settings() {
  local settings="$CLAUDE_DIR/settings.json"
  [ -f "$settings" ] || return 0
  if ! has jq; then
    warn "jq not found — cannot merge ponytail into settings.json"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  if jq '
    .enabledPlugins = (.enabledPlugins // {})
    | .enabledPlugins["ponytail@ponytail"] = true
    | .extraKnownMarketplaces = (.extraKnownMarketplaces // {})
    | .extraKnownMarketplaces.ponytail = {
        "source": { "source": "github", "repo": "DietrichGebert/ponytail" }
      }
  ' "$settings" >"$tmp" && mv -f "$tmp" "$settings"; then
    info "Ensured ponytail is enabled in settings.json"
  else
    rm -f "$tmp"
    warn "Failed to merge ponytail into settings.json"
  fi
}
