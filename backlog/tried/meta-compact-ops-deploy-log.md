# tried: meta-compact-ops-deploy-log

## Outcome
Abandoned pre-merge (2026-04-15). Scope violation — denylist hit.

## Why abandoned
Branch edited `.claude/workflows/grind-base.js`. That file is on the
grind denylist: the grind harness is not permitted to modify its own
orchestration code from inside a round. The item's fix (compact the
ops-deploy log that META reads) reaches into the workflow driver, so
the task as written cannot be executed by /grind.

Worktree `/root/src/home-grind/meta-compact-ops-deploy-log` and branch
`grind/meta-compact-ops-deploy-log` force-removed; no diff salvaged.

## Disposition
Item rerouted to `backlog/needs-human/meta-compact-ops-deploy-log.md`.
Triage skips subdirs, so it will not be re-picked. A human reviews and
either:
- applies the `.claude/workflows/grind-base.js` change directly
  (out-of-band commit), or
- re-scopes the item to grind-safe files only and moves it back to
  `backlog/`, or
- deletes it.

## Re-attempt when
The denylisted change has landed out-of-band, or the item has been
re-scoped to avoid `.claude/workflows/`.
