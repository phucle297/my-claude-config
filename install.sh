#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
OPENCODE_DIR="$HOME/.config/opencode"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[ok]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1" >&2; }
step()  { echo -e "\n${BLUE}==>${NC} $1"; }

MODE="${1:-all}"  # all | claude | opencode | deps

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------

OS="$(uname -s)"
ARCH="$(uname -m)"
IS_WSL=false
[[ -f /proc/version ]] && grep -qi microsoft /proc/version && IS_WSL=true

has() { command -v "$1" &>/dev/null; }

pkg_install() {
  # Install system package — Linux (apt) or macOS (brew)
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
    # Try to source fnm for current session
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
  # mempalace has no standard curl install — guide user
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
  if has bunx; then
    bunx oh-my-openagent install --no-tui --platform=opencode --skip-auth 2>/dev/null || \
      warn "omo install via bunx failed"
  else
    npx oh-my-openagent install --no-tui --platform=opencode --skip-auth 2>/dev/null || \
      warn "omo install failed — run manually: npx oh-my-openagent install"
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
  ensure_opencode
  ensure_omo
}

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------

install_file() {
  local src="$1"
  local dst="$2"
  if [ -f "$dst" ]; then
    warn "Skipping $dst (exists). Backup first or remove manually."
  else
    cp -f "$src" "$dst"
    info "Installed $dst"
  fi
}

# ---------------------------------------------------------------------------
# Claude Code config
# ---------------------------------------------------------------------------

setup_claude_dirs() {
  mkdir -p "$CLAUDE_DIR/scripts" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/memory" "$CLAUDE_DIR/hooks"
  info "Claude dirs ready"
}

install_scripts() {
  for f in "$SCRIPT_DIR/scripts/"*.sh; do
    local dst="$CLAUDE_DIR/scripts/$(basename "$f")"
    install_file "$f" "$dst"
    chmod +x "$dst"
  done
}

install_agents() {
  for f in "$SCRIPT_DIR/agents/"*.md; do
    install_file "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
  done
}

install_hooks() {
  for f in "$SCRIPT_DIR/hooks/"*.sh "$SCRIPT_DIR/hooks/"*.js; do
    [ -f "$f" ] || continue
    local dst="$CLAUDE_DIR/hooks/$(basename "$f")"
    install_file "$f" "$dst"
    [[ "$f" == *.sh ]] && chmod +x "$dst"
  done
}

install_settings() {
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    warn "settings.json exists — skipping. Merge manually if needed."
  else
    cp -f "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    info "Installed $CLAUDE_DIR/settings.json"
  fi
}

install_claude_md() {
  install_file "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  install_file "$SCRIPT_DIR/CLAUDE_TEMPLATE_PROJECT.md" "$CLAUDE_DIR/CLAUDE_TEMPLATE_PROJECT.md"
}

install_claude_plugins() {
  if ! has claude; then
    warn "claude CLI not found — skipping plugin install."
    warn "Install Claude Code from https://claude.ai/download then re-run: ./install.sh claude"
    return
  fi
  step "Installing Claude plugins..."
  claude plugin install caveman@caveman         || warn "caveman install failed"
  claude plugin install beads@beads-marketplace || warn "beads install failed"
  info "Claude plugins installed"
}

# ---------------------------------------------------------------------------
# OpenCode + omo config
# ---------------------------------------------------------------------------

setup_opencode_dirs() {
  mkdir -p "$OPENCODE_DIR/scripts" "$OPENCODE_DIR/plugins"
  info "OpenCode dirs ready"
}

install_omo_config() {
  local src="$SCRIPT_DIR/.opencode/oh-my-openagent.json"
  local dst="$OPENCODE_DIR/oh-my-openagent.json"
  if [ -f "$src" ]; then
    if [ -f "$dst" ]; then
      warn "oh-my-openagent.json exists — skipping. Merge manually if needed."
    else
      cp -f "$src" "$dst"
      info "Installed $dst"
    fi
  fi

  local tui_dst="$OPENCODE_DIR/tui.json"
  if [ ! -f "$tui_dst" ]; then
    printf '{\n  "plugin": ["oh-my-openagent/tui"]\n}\n' > "$tui_dst"
    info "Installed $tui_dst"
  fi
}

install_opencode_scripts() {
  for f in "$SCRIPT_DIR/scripts/"*.sh; do
    local dst="$OPENCODE_DIR/scripts/$(basename "$f")"
    if [ ! -f "$dst" ]; then
      cp -f "$f" "$dst"
      chmod +x "$dst"
      info "Installed $dst"
    fi
  done
}

install_opencode_plugins() {
  for f in "$SCRIPT_DIR/.opencode/plugins/"*; do
    [ -f "$f" ] || continue
    local dst="$OPENCODE_DIR/plugins/$(basename "$f")"
    install_file "$f" "$dst"
  done
  # Ensure @opencode-ai/plugin dep is installed
  if [ ! -f "$OPENCODE_DIR/package.json" ]; then
    printf '{\n  "dependencies": {\n    "@opencode-ai/plugin": "latest"\n  }\n}\n' > "$OPENCODE_DIR/package.json"
    info "Created $OPENCODE_DIR/package.json"
  fi
  if has npm; then
    (cd "$OPENCODE_DIR" && npm install --silent 2>/dev/null) && info "opencode plugin deps installed"
  fi
}

suggest_shell_rc() {
  local line='export OMO_SCRIPTS="$HOME/.config/opencode/scripts"'
  echo ""
  echo "Add to your shell rc file:"
  if [[ -f "$HOME/.config/fish/config.fish" ]]; then
    echo "  # fish (~/.config/fish/config.fish):"
    echo "  set -x OMO_SCRIPTS \"\$HOME/.config/opencode/scripts\""
  fi
  echo "  # bash/zsh (~/.bashrc or ~/.zshrc):"
  echo "  $line"
}

# ---------------------------------------------------------------------------
# Next steps
# ---------------------------------------------------------------------------

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

print_opencode_next_steps() {
  echo ""
  echo "=== OpenCode setup done ==="
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
  suggest_shell_rc
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  case "$MODE" in
    deps)
      echo "=== Installing all dependencies ==="
      install_all_deps
      ;;
    claude)
      echo "=== Claude Code Config Installer ==="
      echo ""
      install_all_deps
      setup_claude_dirs
      install_claude_md
      install_scripts
      install_agents
      install_hooks
      install_settings
      install_claude_plugins
      print_claude_next_steps
      ;;
    opencode)
      echo "=== OpenCode + omo Config Installer ==="
      echo ""
      install_all_deps
      setup_opencode_dirs
      ensure_omo
      install_omo_config
      install_opencode_scripts
      install_opencode_plugins
      print_opencode_next_steps
      ;;
    all)
      echo "=== Full Config Installer (Claude Code + OpenCode) ==="
      echo ""
      install_all_deps
      setup_claude_dirs
      install_claude_md
      install_scripts
      install_agents
      install_hooks
      install_settings
      install_claude_plugins
      print_claude_next_steps

      echo ""
      echo "---"
      setup_opencode_dirs
      install_omo_config
      install_opencode_scripts
      install_opencode_plugins
      print_opencode_next_steps
      ;;
    *)
      error "Unknown mode: $MODE"
      echo "Usage: ./install.sh [all|claude|opencode|deps]"
      exit 1
      ;;
  esac
}

main
