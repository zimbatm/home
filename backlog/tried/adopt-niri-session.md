# tried: adopt-niri-session

**Outcome:** abandoned — scope violation (denylist hit)

**What happened:** grind worktree implementation touched `flake.lock`. The
item adds `crops-demo` as a new flake input
(`git+ssh://git@github.com/assise/crops-demo`); `nix flake lock` necessarily
rewrites the lock to record it. The denylist forbids lock changes outside an
explicit bumper round.

**File that tripped it:** `flake.lock`

**Resolution:** branch `grind/adopt-niri-session` deleted, worktree removed.
Original item restored from origin/main and rerouted to
`backlog/needs-human/adopt-niri-session.md`.

**Why needs-human:** triage skips subdirs, so this won't be auto-picked again.
A human reviews and either:
- applies the denylisted change directly (adds the `crops-demo` input + lock
  entry in one reviewed commit, then the module/import/config.kdl can follow
  in a normal grind round), or
- re-scopes to avoid the new input (e.g. enable `programs.niri` from nixpkgs
  alone and vendor a config.kdl without pulling crops-demo as a flake input —
  crib structure by reading `../crops-demo/nix/desktop.nix` at authoring time
  instead of depending on it) and moves it back to `backlog/`, or
- deletes it.

**Don't retry as-is:** any approach that adds a new flake input will hit the
same denylist. Either pre-seed the input by hand or re-scope to nixpkgs-only.

---

**r14 meta re-scope:** moved back to backlog/ with the crops-demo flake
input dropped. The input was never consumed by the module body (only
config.kdl was cribbed-at-authoring-time, which doesn't need a flake
dep). nixpkgs' `programs.niri.enable` + waybar/foot/fuzzel suffice;
noctalia-shell dropped (not in nixpkgs). No flake.lock change → no
denylist hit.
