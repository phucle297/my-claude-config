import type { Plugin } from "@opencode-ai/plugin"
import { existsSync, readFileSync } from "fs"
import { join } from "path"
import { homedir } from "os"

const HOME = homedir()

function resolveScriptsDir(): string {
  if (process.env.OMO_SCRIPTS) return process.env.OMO_SCRIPTS
  const opencodeScripts = `${HOME}/.config/opencode/scripts`
  if (existsSync(opencodeScripts)) return opencodeScripts
  return `${HOME}/.claude/scripts`
}
const SCRIPTS_DIR = resolveScriptsDir()
const CLAUDE_HOOKS = existsSync(`${HOME}/.claude/hooks`) ? `${HOME}/.claude/hooks` : `${HOME}/.config/opencode/hooks`

const AGENT_MAIL_URL = "http://127.0.0.1:8765/api/"
const AGENT_MAIL_TOKEN = "aabebf4faba1f9f9bedf133a0cb1ff71d1a8d406903a7881951336beb798b8a6"
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
        const startScript = join(SCRIPTS_DIR, "session-start.sh")
        if (existsSync(startScript)) {
          await $`bash ${startScript}`.cwd(directory).nothrow().quiet()
        }
        // Register agent-mail (mirrors Claude Code SessionStart hook)
        const registerScript = join(CLAUDE_HOOKS, "agent_mail_register.sh")
        if (existsSync(registerScript)) {
          await $`bash ${registerScript}`.cwd(directory).nothrow().quiet()
        }
      }

      if (event.type === "session.deleted") {
        const script = join(SCRIPTS_DIR, "session-end.sh")
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

        const agentName = process.env.AGENT_MAIL_AGENT
          || `cc-${directory.replace(/[^a-zA-Z0-9]/g, "").slice(-12)}`

        await $`bash ${inboxScript}`
          .env({
            AGENT_MAIL_PROJECT: directory,
            AGENT_MAIL_AGENT: agentName,
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
          `On start: run ${SCRIPTS_DIR}/session-start.sh (bd prime + reload checkpoint).`,
          `On end: run ${SCRIPTS_DIR}/session-end.sh (checkpoint-write + bd prime).`,
          `Checkpoint write: ${SCRIPTS_DIR}/checkpoint-write.sh <bd-id>`,
        ].join("\n"),
      )
    },
  }
}
