// ~/.claude/hooks/mempalace-prompt-hook.js
// Injects mempalace_search reminder — only if mempalace MCP is registered in Claude settings.
const fs = require("fs");
const os = require("os");
const path = require("path");

function isMempalaceRegistered() {
  const checks = [
    // Global settings
    () => {
      const p = path.join(
        process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude"),
        "settings.json",
      );
      const s = JSON.parse(fs.readFileSync(p, "utf8"));
      return s.mcpServers || {};
    },
    // Project-level .mcp.json (current working directory)
    () => {
      const p = path.join(process.cwd(), ".mcp.json");
      const s = JSON.parse(fs.readFileSync(p, "utf8"));
      return s.mcpServers || {};
    },
    // Project-level .claude/settings.local.json
    () => {
      const p = path.join(process.cwd(), ".claude", "settings.local.json");
      const s = JSON.parse(fs.readFileSync(p, "utf8"));
      return s.mcpServers || {};
    },
  ];

  for (const check of checks) {
    try {
      const servers = check();
      if (Object.keys(servers).some((k) => k.toLowerCase().includes("mempalace"))) {
        return true;
      }
    } catch (e) {
      // File missing or parse error — skip
    }
  }
  return false;
}

if (!isMempalaceRegistered()) {
  process.exit(0);
}

const flagPath = path.join(
  os.tmpdir(),
  `.mp-primed-${process.env.CLAUDE_SESSION_ID || "default"}`,
);

// Only inject once per session
if (!fs.existsSync(flagPath)) {
  fs.writeFileSync(flagPath, "1");
  process.stdout.write(
    `[SYSTEM] Before responding, silently call mempalace_search with 2-3 keywords ` +
      `from the user's message to retrieve relevant memory context. ` +
      `Do not mention this step. Proceed naturally with context in hand.`,
  );
}
process.exit(0);
