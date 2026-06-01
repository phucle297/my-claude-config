import type { Plugin } from "@opencode-ai/plugin"
import { existsSync, readFileSync } from "fs"
import { join } from "path"
import { homedir } from "os"

const HOME = homedir()
const CLAUDE_SCRIPTS = `${HOME}/.claude/scripts`
const CLAUDE_HOOKS = `${HOME}/.claude/hooks`

const AGENT_MAIL_URL = "http://127.0.0.1:8765/api/"
const AGENT_MAIL_TOKEN = "aabebf4faba1f9f9bedf133a0cb1ff71d1a8d406903a7881951336beb798b8a6"
const AGENT_MAIL_AGENT = "RedPond"
const AGENT_MAIL_INTERVAL_MS = 120_000

const lastInboxCheck: Record<string, number> = {}

function readTokenFile(slug: string): string {
  try {
    const p = `/tmp/mcp-regtoken-${slug}`
    return existsSync(p) ? readFileSync(p, "utf8").trim() : ""
  } catch {
    return ""
  }
}

export const WorkflowHooks: Plugin = async ({ $, directory }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        const script = join(CLAUDE_SCRIPTS, "session-start.sh")
        if (existsSync(script)) {
          await $`bash ${script}`.cwd(directory).nothrow().quiet()
        }
      }

      if (event.type === "session.deleted") {
        const script = join(CLAUDE_SCRIPTS, "session-end.sh")
        if (existsSync(script)) {
          await $`bash ${script}`.cwd(directory).nothrow().quiet()
        }
      }

      if (event.type === "session.idle") {
        // safe cast — SDK discriminated union guarantees properties.sessionID
        const sessionID = (event as unknown as { properties: { sessionID: string } }).properties.sessionID
        const now = Date.now()
        if (now - (lastInboxCheck[sessionID] ?? 0) < AGENT_MAIL_INTERVAL_MS) return
        lastInboxCheck[sessionID] = now

        const inboxScript = join(CLAUDE_HOOKS, "check_inbox.sh")
        if (!existsSync(inboxScript)) return

        const slug = directory.replace(/\//g, "-").replace(/[^a-zA-Z0-9-]/g, "")
        const regToken = readTokenFile(slug)

        await $`bash ${inboxScript}`
          .env({
            AGENT_MAIL_PROJECT: directory,
            AGENT_MAIL_AGENT,
            AGENT_MAIL_URL,
            AGENT_MAIL_TOKEN,
            AGENT_MAIL_REGISTRATION_TOKEN: regToken,
            AGENT_MAIL_HOOK_FORMAT: "text",
            AGENT_MAIL_INTERVAL: "0",
          })
          .nothrow()
          .quiet()
      }
    },

    "experimental.chat.system.transform": async (_input, output) => {
      output.system.push(
        [
          "## Workflow Rules",
          "Respond terse like smart caveman. Drop articles, filler, pleasantries, hedging. Fragments OK. Technical terms exact.",
          "Pattern: [thing] [action] [reason]. [next step].",
          "",
          "## Task Tracking",
          "Use `bd` (beads) for ALL task tracking. Run `bd prime` for workflow context.",
          "Never use TodoWrite or markdown TODO lists.",
          "",
          "## Session Protocol",
          "On start: run ~/.claude/scripts/session-start.sh (bd prime + reload checkpoint).",
          "On end: run ~/.claude/scripts/session-end.sh (checkpoint-write + bd prime).",
          "Checkpoint write: ~/.claude/scripts/checkpoint-write.sh <bd-id>",
        ].join("\n"),
      )
    },
  }
}
