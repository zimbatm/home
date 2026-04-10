# tried: ops-gen-stale

## Outcome
Abandoned pre-merge (2026-04-10). Scope violation — denylist hit.

## Why abandoned
Round touched `flake.lock`. That file is on the grind denylist:
lockfile changes are bumper-only, one-input-per-round, and never a
side-effect of an ops-* item. The merge gate rejected the worktree on
the denylist check regardless of whether the change was later
reverted.

Worktree `/root/src/home-grind/ops-gen-stale` and branch
`grind/ops-gen-stale` force-removed; no diff salvaged.

## Re-attempt when
The item is `ops-*` (human-gated identity material) — triage should
route it to `needs-human/` rather than picking it. A human runs
`kin gen`, reviews the gen/ identity diff, and commits. No flake.lock
edit is required for that; if a kin bump is wanted first, file a
separate bumper item.

## Note
`backlog/ops-gen-stale.md` left in place (matches origin/main).
