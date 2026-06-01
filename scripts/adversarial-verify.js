/**
 * adversarial-verify — Claude Code Workflow script
 *
 * Implements a task, then spawns 3 skeptic agents to independently try to
 * REFUTE the result. Accepts only if ≥2/3 skeptics pass.
 * On failure, retries implementation once with skeptic findings as context.
 *
 * Usage (from Claude Code):
 *   Workflow({ script: fs.readFileSync('scripts/adversarial-verify.js', 'utf8'),
 *              args: { taskId: 'my-app-4xz', description: '...', maxRetries: 1 } })
 *
 * args:
 *   taskId      — beads task ID to claim/close
 *   description — full task description / acceptance criteria
 *   maxRetries  — how many times to retry on failure (default 1)
 */

export const meta = {
  name: 'adversarial-verify',
  description: 'Implement a task, adversarially verify with 3 skeptics, retry on failure',
  phases: [
    { title: 'Implement' },
    { title: 'Verify' },
    { title: 'Retry' },
    { title: 'Result' },
  ],
}

const IMPL_SCHEMA = {
  type: 'object',
  properties: {
    summary:      { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
    test_results: { type: 'string' },
  },
  required: ['summary', 'files_changed'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    refuted:  { type: 'boolean' },
    severity: { type: 'string', enum: ['P0', 'P1', 'P2', 'P3', 'none'] },
    findings: { type: 'array', items: { type: 'string' } },
  },
  required: ['refuted', 'severity', 'findings'],
}

const taskId     = args?.taskId      ?? ''
const desc       = args?.description ?? ''
const maxRetries = args?.maxRetries  ?? 1

async function implement(description, priorFindings) {
  const context = priorFindings?.length
    ? `\n\nPrior skeptic findings to address:\n${priorFindings.join('\n')}`
    : ''
  return agent(
    `Implement the following task and close it when done.\n\nTask: ${description}${context}\n\n` +
    (taskId ? `Beads task ID: ${taskId}. Run: bd update ${taskId} --claim --json\n` : '') +
    `After implementing, run tests. Return summary, files changed, and test results.`,
    { label: 'implement', phase: 'Implement', schema: IMPL_SCHEMA }
  )
}

async function verify(impl) {
  const prompt = (i) =>
    `You are skeptic #${i + 1}. Try to REFUTE this implementation. ` +
    `Look for bugs, wrong behavior, edge cases, security issues, missing error handling. ` +
    `Default to refuted=true if uncertain.\n\n` +
    `Implementation summary:\n${impl.summary}\n\n` +
    `Files changed:\n${impl.files_changed.join('\n')}\n\n` +
    `Test results:\n${impl.test_results ?? 'not provided'}`

  return parallel(
    Array.from({ length: 3 }, (_, i) => () =>
      agent(prompt(i), { label: `skeptic-${i + 1}`, phase: 'Verify', schema: VERDICT_SCHEMA })
    )
  )
}

function evalVotes(votes) {
  const valid    = votes.filter(Boolean)
  const passed   = valid.filter(v => !v.refuted)
  const blocker  = valid.some(v => ['P0', 'P1'].includes(v.severity))
  const findings = valid.flatMap(v => v.findings)
  return { ok: passed.length >= 2 && !blocker, findings }
}

// --- main ---

let impl = await implement(desc)
let { ok, findings } = evalVotes(await verify(impl))

if (!ok && maxRetries > 0) {
  log(`Verify failed (${findings.length} findings). Retrying with context...`)
  phase('Retry')
  impl = await implement(desc, findings)
  const result = evalVotes(await verify(impl))
  ok       = result.ok
  findings = result.findings
}

phase('Result')

if (ok) {
  log('PASS — implementation accepted.')
  if (taskId) {
    await agent(
      `Run: bd close ${taskId} "verified: adversarial-verify passed" --json\n` +
      `Then run: $OMO_SCRIPTS/checkpoint-write.sh ${taskId}`,
      { label: 'close-task', phase: 'Result' }
    )
  }
} else {
  log(`FAIL — ${findings.length} unresolved findings after retry.`)
  if (taskId) {
    await agent(
      `Run: bd reopen ${taskId} --json\n` +
      `Add comment: bd comments ${taskId} add "adversarial-verify failed: ${findings.slice(0, 3).join('; ')}"`,
      { label: 'reopen-task', phase: 'Result' }
    )
  }
}

return { ok, findings, impl }
