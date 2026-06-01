// ~/.claude/hooks/mempalace-prompt-hook.js
// Injects mempalace_search reminder — only if mempalace MCP is registered in Claude settings.
const fs = require("fs");
const os = require("os");
const path = require("path");

function isMempalaceRegistered() {
  try {
    const settingsPath = path.join(
      process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude"),
      "settings.json",
    );
    const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
    const servers = settings.mcpServers || {};
    return Object.keys(servers).some((k) => k.toLowerCase().includes("mempalace"));
  } catch (e) {
    return false;
  }
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
