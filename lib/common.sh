#!/bin/bash
# Shared infrastructure for install.sh and install/<tool>.sh modules.
# Sourced (not executed). Provides: logging, OS detection, pkg_install,
# generic dependency installers, file helpers, and per-tool dir vars.
#
# Requires $SCRIPT_DIR (repo root) to be set by the sourcing script before
# any of the install_scripts_to / agent-sync helpers are CALLED.

# Source-guard: safe to source more than once.
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

# ---------------------------------------------------------------------------
# Per-tool config dirs
# ---------------------------------------------------------------------------

CLAUDE_DIR="$HOME/.claude"
OPENCODE_DIR="$HOME/.config/opencode"
CURSOR_DIR="$HOME/.cursor"
CODEX_DIR="$HOME/.codex"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

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
# Generic dependency auto-installers
# (tool-specific installers — ensure_opencode, ensure_omo — live in
#  install/opencode.sh)
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

# Install the per-project mempalace launcher to ~/.local/bin (which is on
# PATH for both Claude and Codex MCP spawns). Idempotent. Referenced by the
# Claude + Codex mempalace MCP registrations so one registration yields a
# per-project palace (the wrapper derives it from the launch cwd).
install_mempalace_wrapper() {
  local src="$SCRIPT_DIR/bin/mempalace-project"
  local dst="$HOME/.local/bin/mempalace-project"
  if [ ! -f "$src" ]; then
    warn "mempalace-project wrapper missing at $src — skipping"
    return 1
  fi
  mkdir -p "$HOME/.local/bin"
  cp -f "$src" "$dst" && chmod +x "$dst" \
    && info "Installed mempalace-project wrapper → $dst" \
    || { warn "Failed to install mempalace-project wrapper"; return 1; }
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
