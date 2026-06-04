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
  cp -f "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
  info "Installed $CLAUDE_DIR/settings.json"
}

install_claude_md() {
  cp -f "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  cp -f "$SCRIPT_DIR/CLAUDE_TEMPLATE_PROJECT.md" "$CLAUDE_DIR/CLAUDE_TEMPLATE_PROJECT.md"
  info "Installed CLAUDE.md + CLAUDE_TEMPLATE_PROJECT.md"
}

install_claude_plugins() {
  if ! has claude; then
    warn "claude CLI not found — skipping plugin install."
    warn "Install Claude Code from https://claude.ai/download then re-run: ./install.sh claude"
    return
  fi
  step "Installing Claude plugins..."
  # Order must match enabledPlugins in settings.json.
  claude plugin install caveman@caveman                         || warn "caveman install failed"
  claude plugin install beads@beads-marketplace                 || warn "beads install failed"
  claude plugin install superpowers@claude-plugins-official     || warn "superpowers install failed"
  claude plugin install context7@claude-plugins-official        || warn "context7 install failed"
  claude plugin install code-simplifier@claude-plugins-official || warn "code-simplifier install failed"
  claude plugin install skill-creator@claude-plugins-official   || warn "skill-creator install failed"
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
  echo "Start agent-mail server (required for inbox hooks):"
  echo "  cd ~/.local/share/mcp_agent_mail && uv run python -m mcp_agent_mail.server &"
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
install_claude() {
  step "Configuring Claude Code..."
  backup_tracked_dir "$CLAUDE_DIR"
  setup_claude_dirs
  install_claude_md
  install_claude_scripts
  install_agents
  install_skills
  install_hooks
  install_settings
  install_claude_plugins
  install_claude_mempalace
  print_claude_next_steps
}
