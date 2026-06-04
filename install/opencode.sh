#!/bin/bash
# OpenCode + oh-my-openagent (omo) config install module. Sourced by install.sh.
# Depends on lib/common.sh (logging, has, ensure_node, ensure_curl,
# $OPENCODE_DIR, $SCRIPT_DIR, helpers).

# ---------------------------------------------------------------------------
# OpenCode-specific dependency installers
# ---------------------------------------------------------------------------

ensure_opencode() {
  has opencode && {
    info "opencode already installed ($(opencode --version 2>/dev/null || echo '?'))"
    return
  }
  step "Installing OpenCode..."
  ensure_curl
  curl -fsSL https://opencode.ai/install | bash 2>/dev/null ||
    warn "OpenCode install failed — install manually: curl -fsSL https://opencode.ai/install | bash"
  has opencode && info "opencode installed" || warn "opencode not in PATH — restart shell"
}

ensure_omo() {
  step "Installing oh-my-openagent (omo) globally for user..."
  ensure_node

  # `npx oh-my-openagent install` is per-project (writes to cwd). For omo to
  # work in any dir, the npm package must be on opencode's global plugin
  # path — $OPENCODE_DIR/node_modules/ — so opencode.jsonc's
  # "oh-my-openagent@latest" entry resolves regardless of cwd.
  mkdir -p "$OPENCODE_DIR"
  local pkg="$OPENCODE_DIR/package.json"
  if [ ! -f "$pkg" ]; then
    printf '{\n  "dependencies": {\n    "oh-my-openagent": "latest",\n    "@opencode-ai/plugin": "latest"\n  }\n}\n' >"$pkg"
    info "Created $pkg"
  elif has jq; then
    local has_omo
    has_omo=$(jq -r '.dependencies["oh-my-openagent"] // empty' "$pkg" 2>/dev/null)
    if [ -z "$has_omo" ]; then
      local tmp="${pkg}.tmp"
      jq '.dependencies["oh-my-openagent"] = "latest"' "$pkg" >"$tmp" &&
        mv "$tmp" "$pkg" &&
        info "Added oh-my-openagent to $pkg"
    fi
  else
    warn "jq not found — manually add \"oh-my-openagent\": \"latest\" to $pkg then run: cd $OPENCODE_DIR && npm install"
  fi

  if has npm; then
    if (cd "$OPENCODE_DIR" && npm install --silent 2>/dev/null); then
      if [ -d "$OPENCODE_DIR/node_modules/oh-my-openagent" ]; then
        info "omo installed globally → $OPENCODE_DIR/node_modules/oh-my-openagent"
      else
        warn "npm install finished but oh-my-openagent not found in $OPENCODE_DIR/node_modules — check network/registry"
      fi
    else
      warn "npm install in $OPENCODE_DIR failed — run manually: cd $OPENCODE_DIR && npm install"
      return 1
    fi
  elif has bun; then
    (cd "$OPENCODE_DIR" && bun install --silent 2>/dev/null) &&
      info "omo installed via bun → $OPENCODE_DIR/node_modules/oh-my-openagent"
  else
    warn "neither npm nor bun found — install Node.js then run: cd $OPENCODE_DIR && npm install"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# OpenCode + omo config
# ---------------------------------------------------------------------------

setup_opencode_dirs() {
  mkdir -p "$OPENCODE_DIR/scripts" "$OPENCODE_DIR/plugins"
  info "OpenCode dirs ready"
}

install_opencode_scripts() { install_scripts_to "$OPENCODE_DIR/scripts"; }

install_omo_config() {
  # omo v4.7.x does not export a "./tui" subpath, so omo must be registered
  # as a regular server plugin in opencode.jsonc — NOT via tui.json, which
  # would resolve "oh-my-openagent/tui" as a GitHub URL and fail with
  # NpmInstallFailedError on every opencode launch in any cwd.
  local src="$SCRIPT_DIR/.opencode/oh-my-openagent.json"
  if [ -f "$src" ]; then
    cp -f "$src" "$OPENCODE_DIR/oh-my-openagent.json"
    info "Installed $OPENCODE_DIR/oh-my-openagent.json"
  fi

  local cfg="$OPENCODE_DIR/opencode.jsonc"
  if [ ! -f "$cfg" ]; then
    cfg="$OPENCODE_DIR/opencode.json"
  fi
  if [ ! -f "$cfg" ]; then
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "plugin": ["oh-my-openagent@latest"]\n}\n' >"$OPENCODE_DIR/opencode.jsonc"
    info "Installed $OPENCODE_DIR/opencode.jsonc (omo registered globally)"
  elif has jq; then
    local has_omo
    has_omo=$(jq -r '.plugin // [] | map(select(. == "oh-my-openagent" or . == "oh-my-openagent@latest" or (type == "string" and startswith("oh-my-openagent@")))) | .[0] // empty' "$cfg" 2>/dev/null)
    if [ -z "$has_omo" ]; then
      local tmp="${cfg}.tmp"
      jq '.plugin = ((.plugin // []) + ["oh-my-openagent@latest"])' "$cfg" >"$tmp" &&
        mv "$tmp" "$cfg" &&
        info "Added oh-my-openagent@latest to $cfg plugin list (global)"
    else
      info "oh-my-openagent already in $cfg plugin list ($has_omo)"
    fi
  else
    warn "jq not found — manually add \"oh-my-openagent@latest\" to the plugin array in $cfg"
  fi

  local tui_dst="$OPENCODE_DIR/tui.json"
  if [ -f "$tui_dst" ] && grep -q 'oh-my-openagent/tui' "$tui_dst" 2>/dev/null; then
    local bak="${tui_dst}.bak-$(date +%Y%m%d%H%M%S)"
    mv -f "$tui_dst" "$bak" && info "Quarantined unresolvable $tui_dst → $bak"
  fi
}

# Merge the repo's shared, project-AGNOSTIC opencode config (provider, model,
# theme, permissions, mcp, agent defaults, etc.) into the GLOBAL $OPENCODE_DIR
# config so it applies to every project automatically. OpenCode merges
# global + project configs at launch (project keys win on conflict, arrays
# like `plugin` aside), so after this you only ever need a *local*
# opencode.json for keys a specific repo must override — never a blanket
# `cp opencode.json .` per repo.
#
# Source precedence here: existing global is the base, the repo's shared file
# overrides on conflicting keys, and the `plugin` array is unioned so the omo
# registration written by install_omo_config is preserved.
merge_global_opencode_config() {
  local src="$SCRIPT_DIR/opencode.json"
  [ -f "$src" ] || src="$SCRIPT_DIR/opencode.jsonc"
  if [ ! -f "$src" ]; then
    info "No shared opencode.json/.jsonc in repo — skipping global config merge"
    return 0
  fi

  local cfg="$OPENCODE_DIR/opencode.jsonc"
  [ -f "$cfg" ] || cfg="$OPENCODE_DIR/opencode.json"

  # No existing global config (shouldn't happen after install_omo_config, but
  # be safe): just drop the shared file in as the global config.
  if [ ! -f "$cfg" ]; then
    cfg="$OPENCODE_DIR/opencode.jsonc"
    cp -f "$src" "$cfg"
    info "Installed shared config as global $cfg"
    return 0
  fi

  if has jq; then
    local tmp="${cfg}.tmp"
    # `.[0] * .[1]` = recursive deep-merge (right/shared wins on conflicts).
    # Then re-set `plugin` to the de-duplicated union of both so we never
    # drop oh-my-openagent@latest. `jq -s` slurps both files into an array.
    if jq -s '
        (.[0] * .[1])
        + { plugin: (((.[0].plugin // []) + (.[1].plugin // [])) | unique) }
      ' "$cfg" "$src" >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      mv "$tmp" "$cfg"
      info "Merged shared opencode config → $cfg (global, applies to all projects)"
    else
      rm -f "$tmp"
      warn "jq merge of $src into $cfg failed — left $cfg untouched; merge manually"
    fi
  else
    warn "jq not found — cannot auto-merge $src; copy its keys into $cfg by hand"
  fi
}

install_opencode_plugins() {
  for f in "$SCRIPT_DIR/.opencode/plugins/"*; do
    [ -f "$f" ] || continue
    cp -f "$f" "$OPENCODE_DIR/plugins/$(basename "$f")"
  done
  local pkg="$OPENCODE_DIR/package.json"
  if [ ! -f "$pkg" ]; then
    printf '{\n  "dependencies": {\n    "@opencode-ai/plugin": "latest",\n    "oh-my-openagent": "latest"\n  }\n}\n' >"$pkg"
    info "Created $pkg"
  elif has jq; then
    # Idempotent re-add in case ensure_omo was skipped.
    local has_omo
    has_omo=$(jq -r '.dependencies["oh-my-openagent"] // empty' "$pkg" 2>/dev/null)
    if [ -z "$has_omo" ]; then
      local tmp="${pkg}.tmp"
      jq '.dependencies["oh-my-openagent"] = "latest"' "$pkg" >"$tmp" &&
        mv "$tmp" "$pkg" &&
        info "Added oh-my-openagent to $pkg"
    fi
  fi
  if has npm; then
    (cd "$OPENCODE_DIR" && npm install --silent 2>/dev/null) && info "opencode plugin deps installed"
  fi
}

# Generate .opencode/agent/*.md from canonical agents/*.md. Single source
# of truth lives in agents/; this dir is gitignored and refreshed on every
# `./install.sh opencode` so omo sees the same content as Claude Code.
install_opencode_agents() {
  local dst_dir="$SCRIPT_DIR/.opencode/agent"
  mkdir -p "$dst_dir"
  # OpenCode's agent schema wants `tools` as an object map {name: bool},
  # whereas Claude Code uses a YAML array. Convert array -> object on sync.
  # Builtins are lowercased (Read->read); mcp__* names kept verbatim.
  for f in "$SCRIPT_DIR/agents/"*.md; do
    [ -f "$f" ] || continue
    awk '
      /^tools: \[/ {
        line = $0
        sub(/^tools: \[/, "", line)
        sub(/\].*$/, "", line)
        n = split(line, a, ",")
        print "tools:"
        for (i = 1; i <= n; i++) {
          t = a[i]
          gsub(/^[ \t]+|[ \t]+$/, "", t)
          if (t == "") continue
          if (t !~ /^mcp__/) t = tolower(t)
          print "  " t ": true"
        }
        next
      }
      { print }
    ' "$f" >"$dst_dir/$(basename "$f")"
  done
  info "Synced $(ls "$dst_dir"/*.md 2>/dev/null | wc -l) agent file(s) to $dst_dir"
}

OMO_RC_MARKER_BEGIN="# >>> oh-my-openagent slug >>>"
OMO_RC_MARKER_END="# <<< oh-my-openagent slug <<<"

# Write/refresh the marker block in an rc file (idempotent).
# $1 = rc file path, $2 = block body
_omo_write_rc_block() {
  local rc="$1" body="$2"
  [[ -f "$rc" ]] || touch "$rc" 2>/dev/null || {
    warn "cannot write $rc"
    return 1
  }
  # Strip any previous block, then append the fresh one.
  if grep -qF "$OMO_RC_MARKER_BEGIN" "$rc"; then
    local tmp
    tmp="$(mktemp)" || return 1
    awk -v b="$OMO_RC_MARKER_BEGIN" -v e="$OMO_RC_MARKER_END" '
      $0==b {skip=1; next} $0==e {skip=0; next} !skip {print}
    ' "$rc" >"$tmp" && cat "$tmp" >"$rc"
    rm -f "$tmp"
  fi
  {
    printf '%s\n' "$OMO_RC_MARKER_BEGIN"
    printf '%s\n' "$body"
    printf '%s\n' "$OMO_RC_MARKER_END"
  } >>"$rc"
  info "Updated $rc"
}

# Auto-install shell wrapper that derives OPENCODE_PROJECT_SLUG from the git
# root (or cwd) at launch time — no per-project manual env var needed.
install_shell_function() {
  step "Installing shell slug wrapper (auto OPENCODE_PROJECT_SLUG)..."

  # fish — uses functions; derive slug from git root basename.
  local fish_rc="$HOME/.config/fish/config.fish"
  if [[ -f "$fish_rc" || "${SHELL:-}" == *fish* ]]; then
    mkdir -p "$HOME/.config/fish"
    _omo_write_rc_block "$fish_rc" 'set -gx OMO_SCRIPTS "$HOME/.config/opencode/scripts"
function __omo_slug
    basename (git rev-parse --show-toplevel 2>/dev/null; or pwd)
end
function opencode
    set -lx OPENCODE_PROJECT_SLUG (__omo_slug)
    command opencode $argv
end
function claude
    set -lx OPENCODE_PROJECT_SLUG (__omo_slug)
    command claude $argv
end'
  fi

  # bash / zsh — POSIX function form, safe for both rc files.
  local posix_body='export OMO_SCRIPTS="$HOME/.config/opencode/scripts"
__omo_slug() { basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; }
opencode() { OPENCODE_PROJECT_SLUG="$(__omo_slug)" command opencode "$@"; }
claude()   { OPENCODE_PROJECT_SLUG="$(__omo_slug)" command claude "$@"; }'
  [[ -f "$HOME/.bashrc" || "${SHELL:-}" == *bash* ]] && _omo_write_rc_block "$HOME/.bashrc" "$posix_body"
  [[ -f "$HOME/.zshrc" || "${SHELL:-}" == *zsh* ]] && _omo_write_rc_block "$HOME/.zshrc" "$posix_body"

  echo "  Slug now auto-derived from git root basename on each opencode/claude launch."
  echo "  Restart shell or source your rc to activate."
}

print_opencode_next_steps() {
  echo ""
  echo "=== OpenCode + omo setup done ==="
  echo ""
  if [ -d "$OPENCODE_DIR/node_modules/oh-my-openagent" ] && grep -q 'oh-my-openagent' "$OPENCODE_DIR/opencode.jsonc" 2>/dev/null; then
    echo "omo global install: $OPENCODE_DIR/node_modules/oh-my-openagent"
    echo "  registered in $OPENCODE_DIR/opencode.jsonc plugin list"
    echo "  → omo loads from any directory"
  else
    echo "WARNING: omo not fully installed"
    echo "  npm pkg:    $OPENCODE_DIR/node_modules/oh-my-openagent (missing? run: cd $OPENCODE_DIR && npm install)"
    echo "  plugin reg: $OPENCODE_DIR/opencode.jsonc (missing? ensure \"oh-my-openagent@latest\" in plugin array)"
  fi
  echo ""
  echo "Global config: $OPENCODE_DIR/opencode.jsonc"
  echo "  Shared provider/model/plugin/permission settings live here and apply"
  echo "  to EVERY project automatically (OpenCode merges global + project config)."
  echo "  → No per-repo 'cp opencode.json .' needed anymore."
  echo ""
  echo "Per-project setup (run once per repo, only project-specific bits):"
  echo "  cd ~/Projects/<org>/<project>"
  echo "  # Create a local opencode.json ONLY if this repo must override a global key."
  echo "  cp /path/to/claude-config/AGENTS.md .   # project-specific agent rules"
  echo "  bd init && touch .beads/PRIME.md"
  echo "  mempalace --palace ~/.mempalace/<project> init ."
  echo ""
  echo "Configure provider (run once — writes to the GLOBAL config above):"
  echo "  opencode providers"
  echo "  # or edit $OPENCODE_DIR/opencode.jsonc directly"
  echo ""
  echo "Verify:"
  echo "  opencode models && bd status && npx oh-my-openagent doctor"
  install_shell_function
}

# Full OpenCode + omo install cycle.
install_opencode() {
  step "Configuring OpenCode + omo..."
  ensure_opencode
  backup_tracked_dir "$OPENCODE_DIR"
  setup_opencode_dirs
  install_omo_config
  merge_global_opencode_config # fold shared opencode.json into the global config
  install_opencode_scripts
  install_opencode_plugins
  ensure_omo
  install_opencode_agents
  print_opencode_next_steps
}
