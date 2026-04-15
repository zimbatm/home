# tried: bug-crops-demo-repo-not-found

**Outcome:** abandoned — scope violation (denylist hit)

**What happened:** grind worktree implementation added a prefetch helper to
keep the gate green while the upstream repo is unreachable. That helper
landed under `.claude/workflows/`, which the grind denylist forbids a
backlog-item branch from touching (harness/workflow files are
orchestration-owned, not item-owned).

**File that tripped it:** `.claude/workflows/prefetch-sibling-inputs.sh`

**Resolution:** branch `grind/bug-crops-demo-repo-not-found` deleted, worktree
removed. Original item restored from origin/main and rerouted to
`backlog/needs-human/bug-crops-demo-repo-not-found.md`.

**Why needs-human:** triage skips subdirs, so this won't be auto-picked again.
A human reviews and either:
- applies the denylisted change directly (commits the prefetch helper +
  grind.config hook in one reviewed harness commit), or
- re-scopes the item to avoid `.claude/` (e.g. fix the actual GitHub access /
  rename in `flake.nix` so no prefetch shim is needed; or vendor the input)
  and moves it back to `backlog/`, or
- deletes it.

**Don't retry as-is:** any mitigation that adds a gate-side prefetch step will
hit the same `.claude/` denylist. Fix the input URL or re-grant repo access
instead; the prefetch is a workaround, not the fix.
