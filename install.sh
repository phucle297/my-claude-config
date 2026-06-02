#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
OPENCODE_DIR="$HOME/.config/opencode"
CURSOR_DIR="$HOME/.cursor"
CODEX_DIR="$HOME/.codex"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[ok]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1" >&2; }
step()  { echo -e "\n${BLUE}==>${NC} $1"; }

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------

OS="$(uname -s)"
ARCH="$(uname -m)"
IS_WSL=false
[[ -f /proc/version ]] && grep -qi microsoft /proc/version && IS_WSL=true

has() { command -v "$1" &>/dev/null; }

pkg_install() {
  if [[ "$OS" == "Darwin" ]]; then
    if has brew; then
      HOMEBREW_NO_AUTO_UPDATE=1 brew install "$@" || warn "brew install $* failed"
    else
      warn "Homebrew not found. Install from https://brew.sh then run: brew install $*"
    fi
  else
    local sudo_cmd=""
    [[ $EUID -ne 0 ]] && sudo_cmd="sudo"
    $sudo_cmd apt-get install -y "$@" 2>/dev/null || \
    $sudo_cmd apt install -y "$@" 2>/dev/null || \
    warn "apt install $* failed — install manually"
  fi
}

# ---------------------------------------------------------------------------
# Dependency auto-installers
# ---------------------------------------------------------------------------

ensure_jq() {
  has jq && { info "jq already installed"; return; }
  step "Installing jq..."
  pkg_install jq
  has jq && info "jq installed" || warn "jq install failed — install manually: sudo apt install jq"
}

ensure_curl() {
  has curl && return
  step "Installing curl..."
  pkg_install curl
}

ensure_node() {
  has node && has npx && { info "Node.js already installed"; return; }
  step "Installing Node.js via fnm..."
  if ! has fnm; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell 2>/dev/null || true
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd 2>/dev/null)" 2>/dev/null || true
  fi
  if has fnm; then
    fnm install --lts 2>/dev/null && fnm use lts-latest 2>/dev/null || true
    eval "$(fnm env 2>/dev/null)" 2>/dev/null || true
  fi
  has node || warn "Node.js install failed. Install manually: https://nodejs.org  (or: fnm install --lts)"
  has node && info "Node.js $(node --version) installed"
}

ensure_uv() {
  has uv && { info "uv already installed"; return; }
  step "Installing uv (Python package manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || true
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
  has uv && info "uv installed" || warn "uv install failed — install manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
}

ensure_dolt() {
  has dolt && { info "dolt already installed"; return; }
  step "Installing dolt..."
  ensure_curl
  curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash 2>/dev/null || \
    warn "dolt install failed — install manually: curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash"
  has dolt && info "dolt installed" || warn "dolt not in PATH after install — restart shell or add to PATH"
}

ensure_beads() {
  has bd && { info "bd (beads) already installed"; return; }
  step "Installing beads (bd)..."
  ensure_curl
  ensure_dolt
  curl -sSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash 2>/dev/null || \
    warn "beads install failed — install manually: curl -sSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash"
  has bd && info "bd installed" || warn "bd not in PATH — restart shell"
}

ensure_bv_mcp() {
  has bv && { info "bv already installed"; return; }
  step "Installing bv + mcp_agent_mail..."
  ensure_curl
  ensure_uv
  curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh?$(date +%s)" \
    | bash -s -- --yes --skip-beads 2>/dev/null || \
    warn "bv/mcp_agent_mail install failed — install manually (see README)"
  has bv && info "bv installed" || warn "bv not found after install"
}

ensure_mempalace() {
  has mempalace && { info "mempalace already installed"; return; }
  warn "mempalace not found. Install manually: https://github.com/mempalace/mempalace"
  warn "After install, run: mempalace --palace ~/.mempalace/<project> init ."
}

ensure_opencode() {
  has opencode && { info "opencode already installed ($(opencode --version 2>/dev/null || echo '?'))"; return; }
  step "Installing OpenCode..."
  ensure_curl
  curl -fsSL https://opencode.ai/install | bash 2>/dev/null || \
    warn "OpenCode install failed — install manually: curl -fsSL https://opencode.ai/install | bash"
  has opencode && info "opencode installed" || warn "opencode not in PATH — restart shell"
}

ensure_omo() {
  step "Installing oh-my-openagent (omo)..."
  ensure_node
  # --no-tui requires the subscription flags. Repo is Claude-centric → claude
  # defaults yes, others no. Override via OMO_CLAUDE/OMO_GEMINI/OMO_COPILOT.
  local omo_claude="${OMO_CLAUDE:-yes}"
  local omo_gemini="${OMO_GEMINI:-no}"
  local omo_copilot="${OMO_COPILOT:-no}"
  local omo_flags=(install --no-tui --platform=opencode --skip-auth
    "--claude=$omo_claude" "--gemini=$omo_gemini" "--copilot=$omo_copilot")
  if has bunx; then
    bunx oh-my-openagent "${omo_flags[@]}" || \
      warn "omo install via bunx failed"
  else
    npx oh-my-openagent "${omo_flags[@]}" || \
      warn "omo install failed — run manually: npx oh-my-openagent ${omo_flags[*]}"
  fi
  info "omo installed"
}

install_all_deps() {
  step "Installing all dependencies..."
  ensure_curl
  ensure_jq
  ensure_node
  ensure_uv
  ensure_dolt
  ensure_beads
  ensure_bv_mcp
  ensure_mempalace
}

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------

# Move a tracked top-level config dir (e.g. ~/.claude, ~/.config/opencode,
# ~/.cursor, ~/.codex) aside as <dir>.bak-<ts> so we can rebuild it fresh
# from source. Avoids littering the parent with per-file .bak-N copies.
backup_tracked_dir() {
  local dst="$1"
  [ -d "$dst" ] || return 0
  local bak="${dst}.bak-$(date +%Y%m%d%H%M%S)"
  mv "$dst" "$bak" && info "Backed up $dst → $bak"
}

# Copy every *.sh from SCRIPT_DIR/scripts/ into <dst_dir> and chmod +x.
install_scripts_to() {
  local dst_dir="$1"
  for f in "$SCRIPT_DIR/scripts/"*.sh; do
    [ -f "$f" ] || continue
    cp -f "$f" "$dst_dir/$(basename "$f")"
    chmod +x "$dst_dir/$(basename "$f")"
  done
  info "Installed scripts to $dst_dir"
}

# ---------------------------------------------------------------------------
# Claude Code config
# ---------------------------------------------------------------------------

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

print_claude_next_steps() {
  echo ""
  echo "=== Claude Code setup done ==="
  echo ""
  echo "Start agent-mail server (required for inbox hooks):"
  echo "  cd ~/.local/share/mcp_agent_mail && uv run python -m mcp_agent_mail.server &"
  echo ""
  echo "Per-project setup (run once per repo):"
  echo "  cd ~/Projects/<org>/<project>"
  echo "  mkdir -p .claude .beads && touch .beads/PRIME.md"
  echo "  cp ~/.claude/CLAUDE_TEMPLATE_PROJECT.md CLAUDE.md"
  echo "  bd init"
  echo "  mempalace --palace ~/.mempalace/<project> init ."
  echo "  claude mcp add mempalace -s local -- mempalace-mcp --palace ~/.mempalace/<project>"
  echo ""
  echo "Verify:"
  echo "  claude mcp list && bd status"
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
  local src="$SCRIPT_DIR/.opencode/oh-my-openagent.json"
  if [ -f "$src" ]; then
    cp -f "$src" "$OPENCODE_DIR/oh-my-openagent.json"
    info "Installed $OPENCODE_DIR/oh-my-openagent.json"
  fi

  local tui_dst="$OPENCODE_DIR/tui.json"
  if [ ! -f "$tui_dst" ]; then
    printf '{\n  "plugin": ["oh-my-openagent/tui"]\n}\n' > "$tui_dst"
    info "Installed $tui_dst"
  fi
}

install_opencode_plugins() {
  for f in "$SCRIPT_DIR/.opencode/plugins/"*; do
    [ -f "$f" ] || continue
    cp -f "$f" "$OPENCODE_DIR/plugins/$(basename "$f")"
  done
  if [ ! -f "$OPENCODE_DIR/package.json" ]; then
    printf '{\n  "dependencies": {\n    "@opencode-ai/plugin": "latest"\n  }\n}\n' > "$OPENCODE_DIR/package.json"
    info "Created $OPENCODE_DIR/package.json"
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
  for f in "$SCRIPT_DIR/agents/"*.md; do
    [ -f "$f" ] || continue
    cp -f "$f" "$dst_dir/$(basename "$f")"
  done
  info "Synced $(ls "$dst_dir"/*.md 2>/dev/null | wc -l) agent file(s) to $dst_dir"
}

OMO_RC_MARKER_BEGIN="# >>> oh-my-openagent slug >>>"
OMO_RC_MARKER_END="# <<< oh-my-openagent slug <<<"

# Write/refresh the marker block in an rc file (idempotent).
# $1 = rc file path, $2 = block body
_omo_write_rc_block() {
  local rc="$1" body="$2"
  [[ -f "$rc" ]] || touch "$rc" 2>/dev/null || { warn "cannot write $rc"; return 1; }
  # Strip any previous block, then append the fresh one.
  if grep -qF "$OMO_RC_MARKER_BEGIN" "$rc"; then
    local tmp
    tmp="$(mktemp)" || return 1
    awk -v b="$OMO_RC_MARKER_BEGIN" -v e="$OMO_RC_MARKER_END" '
      $0==b {skip=1; next} $0==e {skip=0; next} !skip {print}
    ' "$rc" > "$tmp" && cat "$tmp" > "$rc"
    rm -f "$tmp"
  fi
  {
    printf '%s\n' "$OMO_RC_MARKER_BEGIN"
    printf '%s\n' "$body"
    printf '%s\n' "$OMO_RC_MARKER_END"
  } >> "$rc"
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
  [[ -f "$HOME/.zshrc"  || "${SHELL:-}" == *zsh*  ]] && _omo_write_rc_block "$HOME/.zshrc"  "$posix_body"

  echo "  Slug now auto-derived from git root basename on each opencode/claude launch."
  echo "  Restart shell or source your rc to activate."
}

print_opencode_next_steps() {
  echo ""
  echo "=== OpenCode + omo setup done ==="
  echo ""
  echo "Per-project setup (run once per repo):"
  echo "  cd ~/Projects/<org>/<project>"
  echo "  cp /path/to/claude-config/opencode.json ."
  echo "  cp /path/to/claude-config/AGENTS.md ."
  echo "  bd init && touch .beads/PRIME.md"
  echo "  mempalace --palace ~/.mempalace/<project> init ."
  echo ""
  echo "Configure provider (run once):"
  echo "  opencode providers"
  echo "  # or add provider block to opencode.json directly"
  echo ""
  echo "Verify:"
  echo "  opencode models && bd status && npx oh-my-openagent doctor"
  install_shell_function
}

# ---------------------------------------------------------------------------
# Cursor config
# ---------------------------------------------------------------------------

setup_cursor_dirs() {
  mkdir -p "$CURSOR_DIR/scripts"
  info "Cursor dirs ready"
}

install_cursor_scripts() { install_scripts_to "$CURSOR_DIR/scripts"; }

install_cursor_rules() {
  # Cursor uses .cursor/rules/*.mdc per-project (not a global file path).
  # We stage a .mdc template at ~/.cursor/workflow-template.mdc for users to copy.
  local dst="$CURSOR_DIR/workflow-template.mdc"
  {
    printf -- '---\ndescription: AI orchestrator workflow — bd task tracking, session protocol, quality gates\nalwaysApply: true\n---\n\n'
    cat "$SCRIPT_DIR/CLAUDE.md"
  } > "$dst"
  info "Installed $dst"
}

print_cursor_next_steps() {
  echo ""
  echo "=== Cursor setup done ==="
  echo ""
  echo "Scripts installed to: $CURSOR_DIR/scripts/"
  echo "Workflow rules template: $CURSOR_DIR/workflow-template.mdc"
  echo ""
  echo "Per-project setup (run once per repo):"
  echo "  cd ~/Projects/<org>/<project>"
  echo "  mkdir -p .cursor/rules .beads && touch .beads/PRIME.md"
  echo "  cp ~/.cursor/workflow-template.mdc .cursor/rules/workflow.mdc"
  echo "  bd init"
  echo "  mempalace --palace ~/.mempalace/<project> init ."
  echo ""
  echo "MCP config: create .cursor/mcp.json in each project:"
  echo "  {"
  echo "    \"mcpServers\": {"
  echo "      \"mempalace\": { \"command\": \"mempalace-mcp\", \"args\": [\"--palace\", \"~/.mempalace/<project>\"] }"
  echo "    }"
  echo "  }"
  echo ""
  echo "Note: Cursor global rules go in Settings → Rules for AI (not file-based)."
  echo "  .cursor/rules/ is project-level only."
  echo ""
  echo "Set env var (add to shell rc):"
  echo "  export CURSOR_SCRIPTS=\"\$HOME/.cursor/scripts\""
}

# ---------------------------------------------------------------------------
# Codex config
# ---------------------------------------------------------------------------

setup_codex_dirs() {
  mkdir -p "$CODEX_DIR/scripts"
  info "Codex dirs ready"
}

install_codex_scripts() { install_scripts_to "$CODEX_DIR/scripts"; }

install_codex_instructions() {
  cp -f "$SCRIPT_DIR/AGENTS.md" "$CODEX_DIR/instructions.md"
  info "Installed $CODEX_DIR/instructions.md"
}

print_codex_next_steps() {
  echo ""
  echo "=== Codex setup done ==="
  echo ""
  echo "Per-project setup (run once per repo):"
  echo "  cd ~/Projects/<org>/<project>"
  echo "  cp ~/.codex/instructions.md AGENTS.md"
  echo "  bd init && touch .beads/PRIME.md"
  echo "  mempalace --palace ~/.mempalace/<project> init ."
  echo ""
  echo "Set env var (add to shell rc):"
  echo "  export CODEX_SCRIPTS=\"\$HOME/.codex/scripts\""
}

# ---------------------------------------------------------------------------
# Platform dispatch
# ---------------------------------------------------------------------------

install_platform() {
  case "$1" in
    claude)
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
      print_claude_next_steps
      ;;
    opencode)
      step "Configuring OpenCode + omo..."
      ensure_opencode
      ensure_omo
      backup_tracked_dir "$OPENCODE_DIR"
      setup_opencode_dirs
      install_omo_config
      install_opencode_scripts
      install_opencode_plugins
      install_opencode_agents
      print_opencode_next_steps
      ;;
    cursor)
      step "Configuring Cursor..."
      backup_tracked_dir "$CURSOR_DIR"
      setup_cursor_dirs
      install_cursor_scripts
      install_cursor_rules
      print_cursor_next_steps
      ;;
    codex)
      step "Configuring Codex..."
      backup_tracked_dir "$CODEX_DIR"
      setup_codex_dirs
      install_codex_scripts
      install_codex_instructions
      print_codex_next_steps
      ;;
    *)
      error "Unknown platform: $1"
      echo "Valid: claude | opencode | cursor | codex" >&2
      exit 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Interactive detection + multi-select
# ---------------------------------------------------------------------------

# Populates SELECTED_PLATFORMS array via interactive menu.
# Sets global SELECTED_PLATFORMS.
SELECTED_PLATFORMS=()

interactive_select() {
  local -a tools=("claude" "opencode" "cursor" "codex")
  local -a labels=("Claude Code" "OpenCode + omo" "Cursor IDE" "OpenAI Codex CLI")
  local -a detected=(false false false false)

  has claude   && detected[0]=true
  has opencode && detected[1]=true
  has cursor   && detected[2]=true
  has codex    && detected[3]=true

  echo "Detected AI coding tools on this system:"
  echo ""
  local i
  for i in "${!tools[@]}"; do
    if ${detected[$i]}; then
      echo -e "  [$(( i + 1 ))] ${GREEN}${labels[$i]}${NC}  ✓ installed"
    else
      echo "  [$(( i + 1 ))] ${labels[$i]}  (not found in PATH)"
    fi
  done
  echo ""
  echo "Enter numbers to configure (e.g. '1', '1 2', '1,2')."
  echo "Press Enter to configure all detected tools."
  echo -n "> "

  local selection
  read -r selection

  SELECTED_PLATFORMS=()

  if [ -z "$selection" ]; then
    for i in "${!tools[@]}"; do
      ${detected[$i]} && SELECTED_PLATFORMS+=("${tools[$i]}")
    done
    if [ ${#SELECTED_PLATFORMS[@]} -eq 0 ]; then
      warn "No tools detected in PATH. Defaulting to Claude Code."
      SELECTED_PLATFORMS=("claude")
    fi
  else
    local num idx
    for num in $(echo "$selection" | tr ',' ' '); do
      if [[ "$num" =~ ^[0-9]+$ ]]; then
        idx=$(( num - 1 ))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#tools[@]}" ]; then
          SELECTED_PLATFORMS+=("${tools[$idx]}")
        else
          warn "Ignoring out-of-range selection: $num"
        fi
      fi
    done
    if [ ${#SELECTED_PLATFORMS[@]} -eq 0 ]; then
      error "No valid selection. Exiting."
      exit 1
    fi
  fi

  echo ""
  echo "Will configure: ${SELECTED_PLATFORMS[*]}"
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  if [ $# -eq 0 ]; then
    echo "=== AI Agent Config Installer ==="
    echo ""
    install_all_deps
    interactive_select
    local platform
    for platform in "${SELECTED_PLATFORMS[@]}"; do
      echo ""
      echo "---"
      install_platform "$platform"
    done

  else
    case "$1" in
      deps)
        echo "=== Installing all dependencies ==="
        install_all_deps
        return
        ;;
      all)
        # Legacy shorthand — install claude + opencode
        echo "=== Full Config Installer (Claude Code + OpenCode) ==="
        echo ""
        install_all_deps
        ensure_opencode
        ensure_omo
        install_platform claude
        echo ""
        echo "---"
        install_platform opencode
        return
        ;;
    esac

    # One or more explicit platforms: ./install.sh claude opencode
    install_all_deps
    local platform
    for platform in "$@"; do
      echo ""
      echo "---"
      install_platform "$platform"
    done
  fi
}

main "$@"
