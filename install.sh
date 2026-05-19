#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[ok]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1" >&2; }

check_deps() {
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

setup_dirs() {
  mkdir -p "$CLAUDE_DIR/scripts"
  mkdir -p "$CLAUDE_DIR/agents"
  mkdir -p "$CLAUDE_DIR/memory"
  info "Directories ready"
}

install_file() {
  local src="$1"
  local dst="$2"
  if [ -f "$dst" ]; then
    warn "Skipping $dst (exists). Backup first or remove manually."
  else
    cp "$src" "$dst"
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
    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    info "Installed $CLAUDE_DIR/settings.json"
  fi
}

install_claude_md() {
  install_file "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  install_file "$SCRIPT_DIR/CLAUDE_TEMPLATE_PROJECT.md" "$CLAUDE_DIR/CLAUDE_TEMPLATE_PROJECT.md"
}

install_plugins() {
  echo ""
  echo "Installing Claude plugins..."
  claude plugin install caveman@caveman || warn "caveman install failed — run manually: claude plugin install caveman@caveman"
  claude plugin install beads@beads-marketplace || warn "beads install failed — run manually: claude plugin install beads@beads-marketplace"
  claude plugin install atlassian@claude-plugins-official || warn "atlassian install failed — run manually: claude plugin install atlassian@claude-plugins-official"
  info "Plugins installed"
}

print_next_steps() {
  echo ""
  echo "=== Done ==="
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
  echo "=== Claude Config Installer ==="
  echo ""

  check_deps
  setup_dirs
  install_claude_md
  install_scripts
  install_agents
  install_settings
  install_plugins
  print_next_steps
}

main "$@"
