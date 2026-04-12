# tried: simplify-lock-follows-dedupe

**Outcome:** abandoned — scope violation (denylist hit)

**What happened:** grind worktree implementation touched `flake.lock`. Adding
`inputs.<x>.inputs.<y>.follows` lines to flake.nix and re-locking necessarily
rewrites the lock; the denylist forbids lock changes outside an explicit
bumper round. The item's own Blockers section predicted this.

**File that tripped it:** `flake.lock`

**Resolution:** branch `grind/simplify-lock-follows-dedupe` deleted, worktree
removed. Original item restored from origin/main and rerouted to
`backlog/needs-human/simplify-lock-follows-dedupe.md`.

**Why needs-human:** triage skips subdirs, so this won't be auto-picked again.
A human reviews and either:
- applies the denylisted change directly (adds the `follows` lines + runs
  `nix flake lock` in one reviewed commit, gates on 3-host eval+dry-build), or
- folds it into `needs-human/harness-fmt-and-checks.md` per the item's own
  suggestion — both need a human-driven lock touch, do them together, or
- re-scopes to a flake.nix-only change a human pre-locks, then moves it back
  to `backlog/`, or
- deletes it.

**Don't retry as-is:** any follows-dedupe requires `nix flake lock` to take
effect, which rewrites flake.lock. There is no lock-free path; re-scope or
hand to a human.
