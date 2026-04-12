# tried: meta-specialist-skip-zero-nixdelta

## Outcome
Abandoned pre-merge (2026-04-12). Scope violation — denylist hit.

## Why abandoned
Branch `grind/meta-specialist-skip-zero-nixdelta` (was 37fa55e) edited
`.claude/workflows/grind-base.js`. That file is on the grind denylist:
the grind harness is not permitted to modify its own orchestration from
inside a round. The backlog item's "How much" targets the rotation
picker, so the task as written cannot be executed by /grind itself.

Worktree `/root/src/home-grind/meta-specialist-skip-zero-nixdelta` and
branch force-removed; no diff salvaged.

## Re-attempt when
Item rerouted to `backlog/needs-human/meta-specialist-skip-zero-nixdelta.md`
(triage skips subdirs, so it won't be re-picked). A human reviews and
either:
- applies the `.claude/workflows/grind-base.js` change directly
  (out-of-band commit), then deletes the needs-human file; or
- re-scopes the item to grind-safe edits only and moves it back to
  `backlog/`; or
- deletes it outright.
