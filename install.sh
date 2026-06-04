#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared infra: logging, OS detection, pkg_install, generic dependency
# installers, file helpers, per-tool dir vars.
source "$SCRIPT_DIR/lib/common.sh"

# Per-tool install modules. Each defines its config helpers + an
# install_<tool>() orchestrator. Split out so each tool's logic lives in
# its own file; this entry point only does deps, dispatch, and the menu.
source "$SCRIPT_DIR/install/claude.sh"
source "$SCRIPT_DIR/install/opencode.sh"
source "$SCRIPT_DIR/install/cursor.sh"
source "$SCRIPT_DIR/install/codex.sh"

# ---------------------------------------------------------------------------
# Platform dispatch
# ---------------------------------------------------------------------------

install_platform() {
  case "$1" in
    claude)   install_claude   ;;
    opencode) install_opencode ;;
    cursor)   install_cursor   ;;
    codex)    install_codex    ;;
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
