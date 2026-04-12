# tried: harness-fmt-and-checks

**Outcome:** abandoned — scope violation (denylist hit)

**What happened:** grind worktree implementation touched `flake.lock`. The
denylist forbids lock changes outside an explicit bumper round; adding
treefmt-nix as a flake input necessarily rewrites the lock.

**File that tripped it:** `flake.lock`

**Resolution:** branch `grind/harness-fmt-and-checks` deleted, worktree
removed. Original item restored from origin/main and rerouted to
`backlog/needs-human/harness-fmt-and-checks.md`.

**Why needs-human:** triage skips subdirs, so this won't be auto-picked again.
A human reviews and either:
- applies the denylisted change directly (adds treefmt-nix input + lock bump
  in one reviewed commit), or
- re-scopes the item to avoid the lock (e.g. consume treefmt-nix via an
  existing input / nixpkgs, or split "add input" into a separate bumper-style
  task) and moves it back to `backlog/`, or
- deletes it.

**Don't retry as-is:** any approach that adds a new flake input will hit the
same denylist. Re-scope first.
