// grind-base.js — generic implementer-heavy improvement loop.
//
// NOT a standalone workflow. A per-project file defines `export const meta`
// and `const CONFIG = {...}` first; the /grind command concatenates that
// file + this one and passes the result to Workflow({script: ...}).
//
// CONFIG contract (everything except `name`, `fastCheck`, `specialists` is optional):
//   name:         'iets'                                  — project label, used in worktree paths
//   fastCheck:    'cargo test && cargo clippy -- -D warnings'  — must-pass check (impl + merge)
//   specialists:  { scholar: (ctx)=>prompt, ... }          — rotating lens agents; ctx = {round, picks, BASE_SETUP, MAIN_GUARD}
//   architect:    (ctx)=>prompt                            — macro-structure review every archCadence rounds
//   archCadence:  5
//   implementers: 6
//   wtParent:     '../<name>-grind'                        — worktree parent dir
//   treeGuard:    'scripts/grind/tree-guard.sh'            — optional; run in BASE_SETUP
//   triageExtra:  (ctx)=>'project-specific triage rules'   — contention guards, regression checks
//   implGate:     (ctx)=>'shell + instructions'            — per-implementer gate (perf, etc.)
//   mergeGate:    (impl)=>{needsGate,cmd,instructions}     — per-merge gate logic
//   benchFinal:   (mergedThisRound)=>'prompt'              — compounding check after all merges
//   metaExtra:    (ctx)=>'project-specific meta checks'    — baseline drift, notifications, etc.
//   forceSpecialist: (triage)=>name|null                   — override rotation (e.g. scholar_pending)
//   triageSchema: {extra props}                            — additional triage output fields
//
// The base provides: round loop, worktree discipline, triage→work→merge→meta
// phases, serialized merge queue, dry-streak/stop-signal, orphan salvage.
//
// Cross-repo dispatch: a specialist that finds work belonging to a sibling
// writes `../<sibling>/backlog/<area>-<slug>.md` (not local backlog/), then
// commits+pushes there directly. The sibling's own triage picks it up. This
// is how security-research files `sec-*` into the audited repo, mutator files
// nixpkgs patches, curator files UX items into kin/iets, etc. Before pushing
// into a sibling, run that sibling's fast-check (see CONFIG.siblingCheck or
// the per-project guard).

const MAX_ROUNDS = args?.rounds ?? Infinity
const IMPLEMENTERS = args?.implementers ?? CONFIG.implementers ?? 6
const DRY_LIMIT = args?.dryLimit ?? 2
const ARCH_CADENCE = args?.archCadence ?? CONFIG.archCadence ?? 5
const SPECIALIST_NAMES = CONFIG.rotation ?? Object.keys(CONFIG.specialists)
const REPO = '$(git rev-parse --show-toplevel)'
const WT_PARENT = CONFIG.wtParent ?? `${REPO}/../${CONFIG.name}-grind`
const BASE = `${WT_PARENT}/_base`
let round = 0
let dryStreak = 0
let allCommits = []

const BASE_SETUP = `
## Setup — work in the grind base worktree, not the user's tree

\`\`\`sh
BASE="${BASE}"
git fetch origin main
git worktree add -f --detach "$BASE" origin/main 2>/dev/null || \\
  (cd "$BASE" && git reset --hard origin/main)
cd "$BASE"
${CONFIG.treeGuard ? `${CONFIG.treeGuard}  # main tree dirty → loud fail` : ''}
\`\`\`
`

const MAIN_GUARD = `
## Commit discipline — REQUIRED

You're on a detached HEAD in \`_base\`. Do NOT create branches. Your
output is append-only docs (backlog/, tests/, docs/) — zero conflict
risk with implementers in their own worktrees.

\`\`\`sh
git add <your files> && git commit -m "..."
git pull --rebase origin main  # specialist and merge queue both push; rebase past any race
git push origin HEAD:main
\`\`\`
`

while (round < MAX_ROUNDS && dryStreak < DRY_LIMIT) {
  round++
  log(`=== Round ${round}/${MAX_ROUNDS} (dry ${dryStreak}/${DRY_LIMIT}) ===`)

  // --- Triage --------------------------------------------------------------
  phase('Triage')
  const ctx0 = { round, picks: [], BASE_SETUP, MAIN_GUARD, IMPLEMENTERS }
  const triage = await agent(`
Triage backlog/ for the ${CONFIG.name} project — pick up to ${IMPLEMENTERS} items
for parallel implementation.
${BASE_SETUP}
0. **Salvage orphaned work** — any grind/* worktree is from an interrupted
   prior session. For each: \`git rev-list --count main..<branch>\`
   - **0 commits** → remove worktree + branch
   - **Has commits, backlog file deleted** → completed; merge it
   - **Has commits, backlog file present** → partial work; KEEP worktree,
     add to picks with priority (implementer setup resumes it)
1. \`ls backlog/*.md | grep -v README\` — report count as backlog_count
${CONFIG.triageExtra ? CONFIG.triageExtra(ctx0) : ''}
3. Pick ${IMPLEMENTERS} items by priority. Contention is OK — the merge
   queue serializes. Only avoid duplicate backlog entries. Partial-work
   orphans get top priority.

   **Sibling-cluster guard** — if ≥3 candidate slugs share a ≥20-char
   common prefix, pick AT MOST 1 from that cluster this round (parallel
   work on the same code path = wasted merges).

   **Tracker decompose** — items named \`tracker-*\` or with a \`## Phases\`
   table list independent sub-items. When backlog_count < ${IMPLEMENTERS},
   you MAY pick N independent rows from one tracker as N separate picks.

Prefer: regressions > bugs > correctness > arch > features.
`, {
    label: `triage-r${round}`,
    phase: 'Triage',
    schema: {
      type: 'object',
      properties: {
        picks: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              file: { type: 'string' },
              touches: { type: 'array', items: { type: 'string' } },
              plan: { type: 'string' },
            },
            required: ['file', 'touches', 'plan'],
          },
        },
        backlog_count: { type: 'number' },
        ...(CONFIG.triageSchema ?? {}),
      },
      required: ['picks', 'backlog_count'],
    },
  })

  const picks = triage?.picks ?? []
  const backlogBefore = triage?.backlog_count ?? 0
  if (picks.length === 0) log('Backlog empty or all in-flight — specialist-only round')
  else log(`Picked ${picks.length} items for implementers`)

  // --- Work: 1 specialist + N implementers → merge queue ------------------
  phase('Work')
  const ctx = { round, picks, BASE_SETUP, MAIN_GUARD, IMPLEMENTERS }

  const implStage = pick => {
    const file = pick.file.replace(/^.*\//, '')
    const slug = file.replace(/\.md$/, '')
    return agent(`
You are an IMPLEMENTER for the ${CONFIG.name} project. Item: backlog/${file}.

## Setup
\`\`\`sh
git fetch origin main
WT="${WT_PARENT}/${slug}"
git worktree add "$WT" -b grind/${slug} origin/main 2>/dev/null || \\
  (cd "$WT" && git rebase origin/main)  # resume: catch up first
cd "$WT"
\`\`\`

## Implement
Plan: ${pick.plan}
Expected files: ${pick.touches.join(', ')}

1. Read backlog/${file} + backlog/tried/ (don't repeat abandoned approaches)
2. Implement in "$WT"
3. \`${CONFIG.fastCheck}\`
${CONFIG.implGate ? CONFIG.implGate({ ...ctx, pick, slug }) : '4. Report worst_regression_pct: 0 (no perf gate configured)'}
5. Commit. Phased/tracker items: edit in place, mark your row done;
   \`git rm backlog/${file}\` only on the LAST row. Single-phase: \`git rm\`
   and commit separately. DO NOT push — merge agent handles that.

Report: branch, worktree, commits, files touched, worst_regression_pct.
`, {
      label: `impl-${slug}`,
      phase: 'Work',
      schema: {
        type: 'object',
        properties: {
          branch: { type: 'string' },
          worktree: { type: 'string' },
          commits: { type: 'array', items: { type: 'string' } },
          files_touched: { type: 'array', items: { type: 'string' } },
          backlog_deleted: { type: 'boolean' },
          worst_regression_pct: { type: 'number' },
          worst_regression_query: { type: 'string' },
          notes: { type: 'string' },
        },
        required: ['branch', 'commits', 'worst_regression_pct'],
      },
    }).then(r => r && { ...r, pick })
  }

  // Serialized merge queue: promise chain is the mutex.
  let mergeChain = Promise.resolve()
  let mergedThisRound = 0, abandonedThisRound = 0
  const mergeOne = impl => {
    const prev = mergeChain
    let done
    mergeChain = new Promise(r => { done = r })
    const g = CONFIG.mergeGate
      ? CONFIG.mergeGate(impl)
      : { needsGate: false, cmd: '', instructions: '' }
    return prev.then(() => agent(`
Merge ONE implementer branch into main for the ${CONFIG.name} project.

Branch: ${impl.branch} at ${impl.worktree}
Self-report: ${impl.worst_regression_pct}%${impl.worst_regression_query ? ` (${impl.worst_regression_query})` : ''} — advisory only
Files: ${impl.files_touched?.join(', ') ?? ''}${impl.notes ? '\nNotes: ' + impl.notes : ''}

## Do (in a dedicated merge worktree)
\`\`\`sh
MWT="${WT_PARENT}/_merge"
git fetch origin main
git worktree add -f "$MWT" origin/main 2>/dev/null || \\
  (cd "$MWT" && git reset --hard origin/main)
cd "$MWT"
test "$(basename "$(git rev-parse --show-toplevel)")" = "_merge" || \\
  { echo "ABORT: not in _merge" >&2; exit 1; }
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || \\
  { echo "ABORT: stale _merge state" >&2; exit 1; }
\`\`\`
1. \`git merge --no-ff ${impl.branch}\`; resolve conflicts semantically
2. \`${CONFIG.fastCheck}\` — must pass
3. ${g.needsGate
      ? `**Gate** — \`${g.cmd}\`
${g.instructions}
   - <5%: proceed to push
   - 5–15%: push if correctness/unblock; note trade-off in commit msg
   - >15%: ABANDON — \`git merge --abort\`, write backlog/tried/<slug>.md,
     restore the backlog item, remove worktree, report abandoned:true`
      : `**Gate** — fastCheck passed; no perf gate configured.`}
4. Push, verify it landed, then fast-forward the main checkout:
   \`\`\`sh
   git push origin HEAD:main
   git fetch origin main
   git merge-base --is-ancestor HEAD origin/main || \\
     { echo "ABORT: push lost" >&2; exit 1; }
   git -C "$(git worktree list --porcelain | sed -n '1s/^worktree //p')" \\
     merge --ff-only origin/main || true
   \`\`\`
5. Clean up: \`git worktree remove ${impl.worktree}\`, \`git branch -d ${impl.branch}\`
`, {
      label: `merge-${impl.branch.replace(/.*\//, '')}`,
      phase: 'Merge',
      schema: {
        type: 'object',
        properties: {
          merged: { type: 'boolean' },
          abandoned: { type: 'boolean' },
        },
        required: ['merged', 'abandoned'],
      },
    })).then(m => {
      if (m?.merged) { mergedThisRound++; allCommits.push(impl.branch) }
      if (m?.abandoned) abandonedThisRound++
    }).finally(done)
  }

  const specName = CONFIG.forceSpecialist?.(triage)
    ?? SPECIALIST_NAMES[(round - 1) % SPECIALIST_NAMES.length]
  const specTask = () => agent(CONFIG.specialists[specName](ctx),
    { label: `${specName}-r${round}`, phase: 'Work' })
  const runArch = CONFIG.architect && round % ARCH_CADENCE === 0
  const archTask = () => agent(CONFIG.architect(ctx),
    { label: `architect-r${round}`, phase: 'Work' })

  const [specOut, archOut] = await parallel([
    specTask,
    ...(runArch ? [archTask] : [() => null]),
    () => pipeline(picks, implStage, impl => impl ? mergeOne(impl) : null),
  ])
  await mergeChain

  const ok = x => x ? '✓' : '—'
  log(`${specName} ${ok(specOut)}${runArch ? ` architect ${ok(archOut)}` : ''} · Merged ${mergedThisRound}/${picks.length}, Abandoned ${abandonedThisRound}`)

  if (mergedThisRound > 0 && CONFIG.benchFinal) {
    phase('Merge')
    await agent(CONFIG.benchFinal({ ...ctx, mergedThisRound }),
      { label: `bench-final-r${round}`, phase: 'Merge' })
  }

  // --- Meta ---------------------------------------------------------------
  phase('Meta')
  const meta = await agent(`
You are the META supervisor for the ${CONFIG.name} grind round ${round}.
${BASE_SETUP}
## This round
Specialist: ${specName}=${ok(specOut)}${runArch ? `, architect=${ok(archOut)}` : ''}
Merged: ${mergedThisRound}/${picks.length}, Abandoned: ${abandonedThisRound}

## Checks

**Leftover worktrees** — any grind/* worktree that survived the merge queue:
merge if commits ahead, remove if empty.

**Chronic deferrals** — \`git log --all --oneline -- backlog/\` for items
rm'd and restored ≥2 times. Break smaller, or move to backlog/tried/ with
"needs-design-decision".

**Contention misses** — \`git log --merges -5 --stat\`. Same files keep
conflicting → propose tightening triage rules in backlog/meta-contention.md.
${CONFIG.metaExtra ? CONFIG.metaExtra(ctx) : ''}
**Stop signal** — if \`.grind-stop\` exists, remove it and report
stop_requested:true.

Fix directly what you can. File backlog/meta-<slug>.md for human-input
issues. Report current backlog_count.
`, {
    label: `meta-r${round}`,
    phase: 'Meta',
    schema: {
      type: 'object',
      properties: {
        fixes_applied: { type: 'array', items: { type: 'string' } },
        issues_filed: { type: 'array', items: { type: 'string' } },
        user_attention: { type: 'string' },
        backlog_count: { type: 'number' },
        stop_requested: { type: 'boolean' },
      },
      required: ['fixes_applied', 'issues_filed', 'backlog_count', 'stop_requested'],
    },
  })

  if (meta?.user_attention) log(`⚠ Meta flagged: ${meta.user_attention}`)
  if (meta?.stop_requested) {
    log('Stop signal — exiting cleanly after round ' + round)
    return { rounds: round, commits: allCommits, stopped: 'stop-signal' }
  }

  const backlogAfter = meta?.backlog_count ?? backlogBefore
  const madeProgress = picks.length > 0 || backlogAfter > backlogBefore
  dryStreak = madeProgress ? 0 : dryStreak + 1
  if (dryStreak > 0) log(`Dry round (${dryStreak}/${DRY_LIMIT})`)
}

const stopped = dryStreak >= DRY_LIMIT ? 'dry-streak' : 'round-cap'
return { rounds: round, commits: allCommits, stopped }
