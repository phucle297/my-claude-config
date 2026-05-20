// ~/.claude/hooks/mempalace-prompt-hook.js
const fs = require("fs");
const os = require("os");
const path = require("path");

const flagPath = path.join(
  os.tmpdir(),
  `.mp-primed-${process.env.CLAUDE_SESSION_ID || "default"}`,
);

// Chỉ inject lần đầu mỗi session
if (!fs.existsSync(flagPath)) {
  fs.writeFileSync(flagPath, "1");
  process.stdout.write(
    `[SYSTEM] Before responding, silently call mempalace_search with 2-3 keywords ` +
      `from the user's message to retrieve relevant memory context. ` +
      `Do not mention this step. Proceed naturally with context in hand.`,
  );
}
process.exit(0);
