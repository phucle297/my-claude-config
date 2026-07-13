/**
 * adversarial-verify — Claude Code Workflow script
 *
 * Flow:
 *   1. Implement — claim + build + self-score (0-10)
 *      → self-score < 6: skip straight to Retry
 *   2. Verify — 3 distinct-lens skeptics run in parallel (pipeline)
 *      lens A: correctness & logic bugs
 *      lens B: security vulnerabilities
 *      lens C: edge cases & missing error handling
 *   3. Completeness critic — "what's still missing?"
 *   4. Retry (if failed) — re-implement with all findings, re-verify
 *   5. Result — PASS: close + checkpoint  /  FAIL: reopen + comment
 *
 * Usage (from Claude Code prompt):
 *   "Run adversarial-verify for task <id>: <description>"
 *   Workflow({ scriptPath: 'scripts/adversarial-verify.js',
 *              args: { taskId: 'abc-123', description: '...', maxRetries: 1 } })
 *
 * args:
 *   taskId      — beads task ID (omit for ad-hoc verification without task tracking)
 *   description — full task description + acceptance criteria
 *   maxRetries  — retry limit (default 1)
 */

export const meta = {
  name: 'adversarial-verify',
  description: 'Implement → self-score → 3-lens skeptics → completeness critic → retry on fail',
  phases: [
    { title: 'Implement' },
    { title: 'Verify' },
    { title: 'Completeness' },
    { title: 'Retry' },
    { title: 'Result' },
  ],
}

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const IMPL_SCHEMA = {
  type: 'object',
  properties: {
    summary:        { type: 'string', description: 'What was done and why' },
    files_changed:  { type: 'array', items: { type: 'string' }, description: 'file:lines touched' },
    test_results:   { type: 'string' },
    self_score:     { type: 'number', description: 'Confidence 0-10. Be honest. 6+ = ready for review.' },
    self_concerns:  { type: 'array', items: { type: 'string' }, description: 'Known weaknesses or uncertain areas' },
  },
  required: ['summary', 'files_changed', 'self_score'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    refuted:  { type: 'boolean' },
    severity: { type: 'string', enum: ['P0', 'P1', 'P2', 'P3', 'none'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          location: { type: 'string', description: 'file:line or component name' },
          issue:    { type: 'string' },
          fix:      { type: 'string' },
        },
        required: ['issue'],
      },
    },
  },
  required: ['refuted', 'severity', 'findings'],
}

const COMPLETENESS_SCHEMA = {
  type: 'object',
  properties: {
    gaps: { type: 'array', items: { type: 'string' }, description: 'Missing tests, unhandled paths, unverified claims' },
    verdict: { type: 'string', enum: ['complete', 'incomplete'] },
  },
  required: ['gaps', 'verdict'],
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const taskId     = args?.taskId      ?? ''
const desc       = args?.description ?? ''
const maxRetries = args?.maxRetries  ?? 1

function fmtFindings(findings) {
  return findings.map(f => `${f.location ? f.location + ': ' : ''}${f.issue}${f.fix ? ' → ' + f.fix : ''}`).join('\n')
}

function dedup(findings) {
  const seen = new Set()
  return findings.filter(f => {
    const key = (f.location ?? '') + f.issue.slice(0, 60)
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

function evalVotes(votes) {
  const valid    = votes.filter(Boolean)
  const passed   = valid.filter(v => !v.refuted)
  const blocker  = valid.some(v => ['P0', 'P1'].includes(v.severity))
  const findings = dedup(valid.flatMap(v => v.findings))
  return { ok: passed.length >= 2 && !blocker, findings, blocker }
}

// ---------------------------------------------------------------------------
// Phases
// ---------------------------------------------------------------------------

async function doImplement(description, priorFindings) {
  const context = priorFindings?.length
    ? `\n\nAddress all prior findings before submitting:\n${priorFindings.map(f => `- ${f.issue}${f.fix ? ': ' + f.fix : ''}`).join('\n')}`
    : ''

  return agent(
    `Implement the following task.\n\nTask:\n${description}${context}\n\n` +
    (taskId ? `Beads: bd update ${taskId} --claim --json\n` : '') +
    `Run all available tests after implementing.\n` +
    `Return: summary of what you did, files changed (file:line), test results, ` +
    `self_score (0-10 confidence the implementation is correct and complete), ` +
    `and any self_concerns you have about the implementation.`,
    { label: 'implement', phase: 'Implement', schema: IMPL_SCHEMA }
  )
}

async function doVerify(impl) {
  const base =
    `Implementation summary:\n${impl.summary}\n\n` +
    `Files changed:\n${impl.files_changed.join('\n')}\n\n` +
    `Test results:\n${impl.test_results ?? 'not provided'}\n\n` +
    `Implementer concerns:\n${impl.self_concerns?.join('\n') ?? 'none stated'}`

  const lenses = [
    {
      label: 'skeptic-correctness',
      prompt: `You are a correctness auditor. Look for logic bugs, wrong output, incorrect assumptions, ` +
              `broken invariants, and cases where the implementation doesn't match the spec.\n\n` +
              `Default refuted=true if you find any P0/P1 issue.\n\n${base}`,
    },
    {
      label: 'skeptic-security',
      prompt: `You are a security auditor. Look for injection vulnerabilities, improper auth/authz, ` +
              `insecure data handling, exposed secrets, XSS, CSRF, and OWASP Top-10 issues.\n\n` +
              `Default refuted=true if you find any P0/P1 issue.\n\n${base}`,
    },
    {
      label: 'skeptic-edge-cases',
      prompt: `You are an edge-case hunter. Look for unhandled null/undefined, empty inputs, ` +
              `boundary conditions, race conditions, missing error handling, and paths not covered by tests.\n\n` +
              `Default refuted=true if you find any P0/P1 issue.\n\n${base}`,
    },
  ]

  return pipeline(
    lenses,
    l => agent(l.prompt, { label: l.label, phase: 'Verify', schema: VERDICT_SCHEMA })
  )
}

async function doCompletenessCritic(impl, allFindings) {
  return agent(
    `You are a completeness critic. Given this implementation and the findings from 3 reviewers, ` +
    `identify what is STILL MISSING or UNVERIFIED.\n\n` +
    `Implementation:\n${impl.summary}\n\n` +
    `Reviewer findings already identified:\n${fmtFindings(allFindings)}\n\n` +
    `Return: gaps (things not yet addressed or tested), and verdict (complete/incomplete).`,
    { label: 'completeness-critic', phase: 'Completeness', schema: COMPLETENESS_SCHEMA }
  )
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

// Phase: Implement
let impl = await doImplement(desc)
log(`Self-score: ${impl.self_score}/10${impl.self_concerns?.length ? ` | concerns: ${impl.self_concerns.join('; ')}` : ''}`)

let allFindings = []
let ok = false

if (impl.self_score < 6) {
  log(`Self-score too low (${impl.self_score}). Skipping skeptics, retrying directly...`)
  phase('Retry')
  impl = await doImplement(desc, (impl.self_concerns ?? []).map(c => ({ issue: c })))
}

// Phase: Verify
const votes = await doVerify(impl)
const eval1 = evalVotes(votes)
allFindings = eval1.findings

// Phase: Completeness
const critic = await doCompletenessCritic(impl, allFindings)
if (critic?.verdict === 'incomplete') {
  allFindings.push(...critic.gaps.map(g => ({ issue: g })))
  log(`Completeness critic: ${critic.gaps.length} gaps found`)
}

ok = eval1.ok && critic?.verdict === 'complete'

// Phase: Retry (loop up to maxRetries times if still failing)
let retriesLeft = maxRetries
while (!ok && retriesLeft > 0) {
  retriesLeft--
  log(`Verify failed (${allFindings.length} total findings). Retrying... (${retriesLeft} left after this)`)
  phase('Retry')
  impl = await doImplement(desc, allFindings)

  const votesR  = await doVerify(impl)
  const evalR   = evalVotes(votesR)
  const criticR = await doCompletenessCritic(impl, evalR.findings)

  ok          = evalR.ok && criticR?.verdict === 'complete'
  allFindings = dedup([...evalR.findings, ...(criticR?.gaps ?? []).map(g => ({ issue: g }))])
}

// Phase: Result
phase('Result')

if (ok) {
  log('PASS — adversarial-verify accepted.')
  if (taskId) {
    await agent(
      `Run these commands:\n` +
      `1. bd close ${taskId} "verified: adversarial-verify passed" --json\n` +
      `2. ~/.claude/scripts/checkpoint-write.sh ${taskId}`,
      { label: 'close-task', phase: 'Result' }
    )
  }
} else {
  const summary = allFindings.slice(0, 5).map(f => f.issue).join('; ')
  log(`FAIL — ${allFindings.length} unresolved findings.`)
  if (taskId) {
    await agent(
      `Run these commands:\n` +
      `1. bd reopen ${taskId} --json\n` +
      `2. bd comments ${taskId} add "adversarial-verify failed (${allFindings.length} findings): ${summary}" --json`,
      { label: 'reopen-task', phase: 'Result' }
    )
  }
}

return { ok, findings: allFindings, impl, self_score: impl.self_score }
