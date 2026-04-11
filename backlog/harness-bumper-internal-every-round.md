# bumper: internal inputs every round, external keeps 1/round

**Why:** "Don't bump >1 input per round" treats `kin` the same as
`nixos-hardware`. Internal inputs are co-developed; keeping them fresh
IS the dogfood test. fastCheck (all hosts eval+dry-build) is the gate.

**Internal inputs** (bump every round, together):
- `kin` — `git+ssh://git@github.com/assise/kin`
- `iets` — `git+ssh://git@github.com/jonasc-ant/iets`
- `nix-skills` — `git+ssh://git@github.com/assise/nix-skills`
- `llm-agents` — `github:numtide/llm-agents.nix` (until `simplify-llm-agents-shrink` drops it)

**External** (keep 1/round, oldest-first): `nixpkgs`, `home-manager`,
`srvos`, `nixos-hardware`, `nix-index-database`, `nixvim`.

**Change** — `.claude/grind.config.js:62-70`, bumper prompt:

Current: oldest-locked input, priority `nixpkgs > kin > iets > others`,
1/round cap.

New shape — two phases:
```sh
# Phase 1 — internal, every round, all together
nix flake update kin iets nix-skills llm-agents
<fastCheck> && git commit -am "bump: internal (kin/iets/nix-skills/llm-agents)" || {
  # red = sibling regression; file + cross-file, then revert
  git checkout flake.lock
}
# Phase 2 — external, oldest one, existing logic
nix flake update <oldest-external>
```

Drift-checker (`grind.config.js:49`): change ">30 days stale" → ">7 days
stale" for the *external* inputs only; internal staleness is now the
bumper's job, drop that check from drift-checker.

**Falsifies:** `nix flake metadata --json | jq` should show kin/iets
lastModified within hours of their origin/main HEAD, not days.
