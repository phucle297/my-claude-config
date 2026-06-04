#!/bin/bash
# Cursor IDE config install module. Sourced by install.sh.
# Depends on lib/common.sh (logging, $CURSOR_DIR, $SCRIPT_DIR, helpers).

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

# Full Cursor install cycle.
install_cursor() {
  step "Configuring Cursor..."
  backup_tracked_dir "$CURSOR_DIR"
  setup_cursor_dirs
  install_cursor_scripts
  install_cursor_rules
  print_cursor_next_steps
}
