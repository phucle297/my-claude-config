#!/bin/bash
# Grok Build CLI config install module. Sourced by install.sh.
# Depends on lib/common.sh (logging, has, $GROK_DIR, $SCRIPT_DIR, helpers).
#
# If ~/.grok exists it is moved to ~/.grok.bak-<ts>, then a fresh tree is
# created. Runtime secrets/state are restored from the bak (auth.json,
# config.toml, sessions, worktrees, etc.). Workflow files (AGENTS.md,
# scripts/, agents/, hooks/, skills/) are always reinstalled from this repo.

ensure_grok() {
  has grok && { info "grok already installed ($(grok --version 2>/dev/null | head -1))"; return; }
  step "Installing Grok Build CLI..."
  ensure_curl
  curl -fsSL https://x.ai/cli/install.sh | bash 2>/dev/null || \
    warn "Grok install failed — install manually: curl -fsSL https://x.ai/cli/install.sh | bash"
  # Common install locations
  export PATH="$HOME/.local/bin:$HOME/.grok/bin:$PATH"
  has grok && info "grok installed" || warn "grok not in PATH after install — restart shell or add ~/.local/bin to PATH"
}

setup_grok_dirs() {
  mkdir -p "$GROK_DIR/scripts" "$GROK_DIR/agents" "$GROK_DIR/hooks" "$GROK_DIR/skills"
  info "Grok dirs ready"
}

install_grok_scripts() { install_scripts_to "$GROK_DIR/scripts"; }

# Install shared agents/*.md into ~/.grok/agents with Grok-friendly frontmatter:
# - model: inherit (drop Claude-specific model pins)
# - drop tools: [...] (Claude tool names; Grok uses capability modes)
# - ensure agents_md: true so project rules still load
install_grok_agents() {
  local src dst name desc body
  for src in "$SCRIPT_DIR/agents/"*.md; do
    [ -f "$src" ] || continue
    dst="$GROK_DIR/agents/$(basename "$src")"
    name="$(basename "$src" .md)"
    desc=""
    if command -v awk >/dev/null 2>&1; then
      desc="$(awk '
        BEGIN { in_fm=0 }
        /^---$/ { if (in_fm) exit; in_fm=1; next }
        in_fm && /^description:[[:space:]]*/ {
          sub(/^description:[[:space:]]*/, "")
          print
          exit
        }
      ' "$src")"
    fi
    [ -n "$desc" ] || desc="$name subagent"
    body="$(awk '
      BEGIN { n=0 }
      /^---$/ { n++; if (n==2) { next } ; if (n==1) next }
      n>=2 { print }
    ' "$src")"
    {
      echo "---"
      echo "name: $name"
      echo "description: $desc"
      echo "model: inherit"
      echo "prompt_mode: full"
      echo "agents_md: true"
      echo "---"
      echo ""
      printf '%s\n' "$body"
    } >"$dst"
  done
  info "Installed agents to $GROK_DIR/agents (model: inherit)"
}

install_grok_skills() {
  [ -d "$SCRIPT_DIR/skills" ] || return 0
  for d in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$d" ] || continue
    cp -rf "$d" "$GROK_DIR/skills/"
  done
  info "Installed skills to $GROK_DIR/skills"
}

install_grok_hooks() {
  local src="$SCRIPT_DIR/hooks/grok-workflow.json"
  if [ ! -f "$src" ]; then
    warn "hooks/grok-workflow.json missing — skipping Grok hooks"
    return 1
  fi
  cp -f "$src" "$GROK_DIR/hooks/workflow.json"
  info "Installed $GROK_DIR/hooks/workflow.json"
}

install_grok_agents_md() {
  cp -f "$SCRIPT_DIR/AGENTS.md" "$GROK_DIR/AGENTS.md"
  # Project template: same beads-oriented instructions as Claude; Grok also
  # loads CLAUDE.md, but AGENTS.md is the native project-rules filename.
  cp -f "$SCRIPT_DIR/CLAUDE_TEMPLATE_PROJECT.md" "$GROK_DIR/AGENTS_TEMPLATE_PROJECT.md"
  info "Installed AGENTS.md + AGENTS_TEMPLATE_PROJECT.md"
}

install_grok_config_hint() {
  # NEVER overwrite ~/.grok/config.toml — holds user model/UI/auth prefs.
  if [ -f "$GROK_DIR/config.toml" ]; then
    info "$GROK_DIR/config.toml already exists — preserving your config"
    info "  Reference template: $SCRIPT_DIR/config.example.toml"
    return
  fi
  if [ -f "$SCRIPT_DIR/config.example.toml" ]; then
    # Install a minimal empty-ish starter only when missing; strip comments
    # are fine in TOML so we can copy the example with a note.
    warn "No $GROK_DIR/config.toml yet — Grok will use built-in defaults"
    warn "  Optional template: $SCRIPT_DIR/config.example.toml"
  fi
}

install_grok_mempalace() {
  if ! has grok; then
    warn "grok CLI not found — skipping mempalace MCP registration"
    return
  fi
  has mempalace-mcp || warn "mempalace-mcp not on PATH — wrapper will fail until installed"
  install_mempalace_wrapper || return

  # Replace any prior mempalace registration (user scope).
  grok mcp remove mempalace --scope user &>/dev/null || true
  if grok mcp add mempalace --scope user -- "$HOME/.local/bin/mempalace-project" &>/dev/null; then
    info "Registered per-project mempalace MCP (user scope)"
  else
    # Fallback without --scope (older CLIs default to user)
    grok mcp add mempalace -- "$HOME/.local/bin/mempalace-project" \
      && info "Registered per-project mempalace MCP" \
      || warn "Failed to register mempalace MCP — run: grok mcp add mempalace -- ~/.local/bin/mempalace-project"
  fi
}

install_grok_plugins() {
  if ! has grok; then
    warn "grok CLI not found — skipping plugin install"
    return
  fi
  step "Installing Grok plugins (best-effort)..."
  # Monorepo plugins use #subdir. --trust skips interactive confirm.
  # Failures are non-fatal — marketplaces move and not all plugins are Grok-native.
  grok plugin install "gastownhall/beads#plugins/beads" --trust 2>/dev/null \
    && info "Installed beads plugin" \
    || warn "beads plugin install skipped/failed (optional)"
  grok plugin install "JuliusBrussee/caveman#plugins/caveman" --trust 2>/dev/null \
    && info "Installed caveman plugin" \
    || warn "caveman plugin install skipped/failed (optional)"
  # Root-level Claude-style plugin; Grok accepts user/repo when layout is compatible.
  grok plugin install "DietrichGebert/ponytail" --trust 2>/dev/null \
    && info "Installed ponytail plugin" \
    || warn "ponytail plugin install skipped/failed (optional — Claude-native layout)"
}

print_grok_next_steps() {
  echo ""
  echo "=== Grok Build CLI setup done ==="
  echo ""
  echo "Installed into ~/.grok/:"
  echo "  AGENTS.md          orchestrator rules"
  echo "  scripts/           beads workflow scripts"
  echo "  agents/            quality-gate, reviewer, ..."
  echo "  hooks/workflow.json  session + claim-guard hooks"
  echo "  skills/            repo skills (additive)"
  echo ""
  echo "mempalace is registered ONCE (user scope) via mempalace-project"
  echo "and resolves to ~/.mempalace/projects/<repo> from the launch cwd."
  echo ""
  echo "Per-project setup (run once per repo):"
  echo "  cd ~/Projects/<org>/<project>"
  echo "  mkdir -p .grok .beads && touch .beads/PRIME.md"
  echo "  cp ~/.grok/AGENTS_TEMPLATE_PROJECT.md AGENTS.md"
  echo "  bd init"
  echo "  mempalace --palace ~/.mempalace/projects/\$(basename \$PWD) init . --yes --no-llm"
  echo ""
  echo "Optional: merge settings from config.example.toml into ~/.grok/config.toml"
  echo ""
  echo "Verify:"
  echo "  grok mcp list"
  echo "  ls ~/.grok/scripts ~/.grok/agents ~/.grok/hooks"
  echo "  bd status"
}

# Full Grok Build install cycle.
# If ~/.grok already exists: move it to ~/.grok.bak-<ts>, create a fresh dir,
# reinstall workflow files from this repo, then restore runtime state
# (auth, personal config, sessions, worktrees, plugins cache, etc.).
install_grok() {
  step "Configuring Grok Build CLI..."
  ensure_grok
  local bak=""
  bak="$(backup_tracked_dir "$GROK_DIR" || true)"
  setup_grok_dirs
  install_grok_agents_md
  install_grok_scripts
  install_grok_agents
  install_grok_skills
  install_grok_hooks
  # Restore runtime secrets/state before config hint / MCP so personal
  # config.toml and auth survive the bak+recreate cycle.
  restore_from_bak "$bak" "$GROK_DIR" \
    auth.json \
    auth.json.lock \
    config.toml \
    trusted_folders.toml \
    trusted_folders.toml.lock \
    agent_id \
    sessions \
    worktrees \
    worktrees.db \
    installed-plugins \
    marketplace-cache \
    logs \
    downloads \
    vendor \
    bundled \
    completions \
    docs \
    bin \
    active_sessions.json \
    CHANGELOG.json \
    CHANGELOG.md \
    README.md \
    version.json \
    models_cache.json \
    slash-mru.json \
    tip_cursor.json \
    .metadata_version
  install_grok_config_hint
  install_grok_mempalace
  install_grok_plugins
  print_grok_next_steps
}
