#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
OPENCODE_DIR="$HOME/.config/opencode"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[ok]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1" >&2; }

MODE="${1:-all}"  # all | claude | opencode

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------

check_claude_deps() {
  local missing=()
  for cmd in claude jq bd bv mempalace; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing required tools: ${missing[*]}"
    echo ""
    echo "Install guide:"
    echo "  claude    → https://claude.ai/download"
    echo "  jq        → sudo apt install jq  (or brew install jq)"
    echo "  bd        → claude plugin install beads@beads-marketplace"
    echo "              (requires dolt: curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash)"
    echo "  bv + mcp  → curl -fsSL \"https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh?\$(date +%s)\" | bash -s -- --yes --skip-beads"
    echo "  mempalace → https://github.com/mempalace/mempalace"
    exit 1
  fi
}

setup_claude_dirs() {
  mkdir -p "$CLAUDE_DIR/scripts"
  mkdir -p "$CLAUDE_DIR/agents"
  mkdir -p "$CLAUDE_DIR/memory"
  info "Claude dirs ready"
}

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
  echo ""
  echo "Installing Claude plugins..."
  claude plugin install caveman@caveman || warn "caveman install failed — run manually: claude plugin install caveman@caveman"
  claude plugin install beads@beads-marketplace || warn "beads install failed — run manually: claude plugin install beads@beads-marketplace"
  claude plugin install atlassian@claude-plugins-official || warn "atlassian install failed — run manually: claude plugin install atlassian@claude-plugins-official"
  info "Plugins installed"
}

# ---------------------------------------------------------------------------
# OpenCode + omo
# ---------------------------------------------------------------------------

check_opencode_deps() {
  local missing=()
  for cmd in opencode npx jq bd mempalace; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing required tools: ${missing[*]}"
    echo ""
    echo "Install guide:"
    echo "  opencode  → curl -fsSL https://opencode.ai/install | bash"
    echo "  npx       → install Node.js from https://nodejs.org"
    echo "  bd        → see Claude Code prerequisites above"
    echo "  mempalace → https://github.com/mempalace/mempalace"
    exit 1
  fi
}

install_omo() {
  echo ""
  echo "Installing oh-my-openagent..."
  npx oh-my-openagent install \
    --no-tui \
    --platform=opencode \
    --claude=no \
    --openai=no \
    --gemini=no \
    --copilot=no \
    --skip-auth \
    || warn "omo install failed — run manually: npx oh-my-openagent install"
  info "omo installed"
}

setup_opencode_dirs() {
  mkdir -p "$OPENCODE_DIR/scripts"
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
  else
    warn "No .opencode/oh-my-openagent.json in repo — skipping."
  fi

  # tui.json — needed for omo TUI sidebar
  local tui_dst="$OPENCODE_DIR/tui.json"
  if [ ! -f "$tui_dst" ]; then
    printf '{\n  "plugin": ["oh-my-openagent/tui"]\n}\n' > "$tui_dst"
    info "Installed $tui_dst"
  else
    warn "tui.json exists — skipping."
  fi
}

install_opencode_scripts() {
  for f in "$SCRIPT_DIR/scripts/"*.sh; do
    local dst="$OPENCODE_DIR/scripts/$(basename "$f")"
    if [ -f "$dst" ]; then
      warn "Skipping $dst (exists)."
    else
      cp -f "$f" "$dst"
      chmod +x "$dst"
      info "Installed $dst"
    fi
  done
}

print_opencode_next_steps() {
  echo ""
  echo "=== OpenCode setup done ==="
  echo ""
  echo "Per-project setup (run once per repo):"
  echo ""
  echo "  cd ~/Projects/<org>/<project>"
  echo ""
  echo "  # The opencode.json and AGENTS.md in this repo are project-scoped."
  echo "  # Copy them if you want to use the same config in another project:"
  echo "  cp ~/.config/opencode/opencode.json opencode.json   # optional"
  echo "  cp ~/.config/opencode/AGENTS.md AGENTS.md            # optional"
  echo ""
  echo "  # Init beads and mempalace (same as Claude Code)"
  echo "  bd init"
  echo "  mempalace --palace ~/.mempalace/<project> init ."
  echo ""
  echo "  # Set OMO_SCRIPTS so AGENTS.md scripts resolve"
  echo "  export OMO_SCRIPTS=\"\$HOME/.config/opencode/scripts\""
  echo "  # Add to shell rc so it persists"
  echo ""
  echo "Verify:"
  echo "  opencode models                  # configured provider/model listed"
  echo "  opencode                         # /model → your chosen model"
  echo "  bd status                        # beads working"
  echo "  npx oh-my-openagent doctor       # no blocking errors"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

print_claude_next_steps() {
  echo ""
  echo "=== Claude Code setup done ==="
  echo ""
  echo "Per-project setup (run once per repo):"
  echo ""
  echo "  cd ~/Projects/<org>/<project>"
  echo "  mkdir -p .claude .beads"
  echo "  cp ~/.claude/CLAUDE_TEMPLATE_PROJECT.md CLAUDE.md"
  echo "  touch .beads/PRIME.md"
  echo "  bd init"
  echo "  mempalace --palace ~/.mempalace/<project> init ."
  echo "  claude mcp add mempalace -s local -- mempalace-mcp --palace ~/.mempalace/<project>"
  echo ""
  echo "Verify:"
  echo "  claude mcp list                      # mempalace ✓ Connected"
  echo "  ~/.claude/scripts/session-start.sh  # runs without errors"
  echo "  bd status"
}

main() {
  case "$MODE" in
    claude)
      echo "=== Claude Code Config Installer ==="
      echo ""
      check_claude_deps
      setup_claude_dirs
      install_claude_md
      install_scripts
      install_agents
      install_settings
      install_claude_plugins
      print_claude_next_steps
      ;;
    opencode)
      echo "=== OpenCode + omo Config Installer ==="
      echo ""
      check_opencode_deps
      setup_opencode_dirs
      install_omo
      install_omo_config
      install_opencode_scripts
      print_opencode_next_steps
      ;;
    all)
      echo "=== Full Config Installer (Claude Code + OpenCode) ==="
      echo ""
      check_claude_deps
      setup_claude_dirs
      install_claude_md
      install_scripts
      install_agents
      install_settings
      install_claude_plugins
      print_claude_next_steps

      echo ""
      echo "---"
      check_opencode_deps
      setup_opencode_dirs
      install_omo
      install_omo_config
      install_opencode_scripts
      print_opencode_next_steps
      ;;
    *)
      error "Unknown mode: $MODE"
      echo "Usage: ./install.sh [all|claude|opencode]"
      exit 1
      ;;
  esac
}

main
