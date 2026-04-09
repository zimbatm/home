# home — working notes for Claude

See README.md for what this is. This file is the agent-facing addendum.

## This is the dogfood

home is the **primary** assise falsification test — Jonas's real machines, fully on kin+maille. Changes here prove or disprove assise pieces under daily-driver load. When something here needs a workaround, that's a signal: either the piece is wrong or the inventory is missing something. File the gap, don't paper over it.

## Deploy is human-gated

These are **real personal machines** — `nv1` is a desktop someone is sitting at. Never run `kin deploy`. The `/grind` loop evals and dry-builds; it commits but does not apply. A person runs `kin deploy <machine>` after reviewing — and after confirming the SSH access path survives the change (see `../kin/docs/howto/lockout-recovery.md`).

Safe: `kin gen`, `kin gen --check`, `nix eval`, `nix build --dry-run`.
Not safe without a human: `kin deploy`, `nixos-rebuild switch`, `kin set` with secrets, anything that touches the running machines.

## Backlog & cross-repo dispatch

`backlog/*.md` is the work queue — `/grind` consumes it. One file per item (`<area>-<slug>.md`: what/why/how-much/blockers); delete when done. `ops-*` items need a human (deploy, `kin set` with secrets) — triage marks them "needs-human" instead of picking. `tried/` and `wontfix/` stop retreading.

**When work belongs elsewhere, file it there:**
- A `nix flake update kin` breaks the build → that's a kin regression. File `../kin/backlog/bug-<slug>.md` with the eval error and the kin commit range, then pin back.
- A dogfood need has no assise piece to satisfy it → file `../meta/backlog/<slug>.md` so the inventory grows.
- A maille/mesh issue surfaces here → `../maille/backlog/bug-<slug>.md`.
- An iets eval divergence → `../iets/backlog/bug-<slug>.md`.

Don't open GitHub issues; don't keep local notes. The sibling's own `/grind` triage picks it up.

## What to edit

- `kin.nix` — the fleet declaration. Users, machines, services, `gen.*` blocks. **The spine** — at most one change per round that touches it.
- `hosts/<name>/configuration.nix` — per-host NixOS (hardware, machine-local quirks). `machines/` is a symlink to `hosts/`.
- `modules/nixos/*.nix`, `modules/home/*` — shared modules. Listed explicitly in `flake.nix` (no auto-discovery, ADR-0006).
- `gen/` — **don't hand-edit.** `kin gen` rewrites it from `kin.nix`. If `gen/` is stale, run `kin gen`, don't patch.
- `default.nix` — the non-flake entrypoint for `iets eval`. Bootstraps kin's upstreamed flake-shim from `flake.lock`.

## /grind

Specialists rotate: **drift** (deployed-vs-declared per host, flake.lock age), **simplifier** (dead modules, unused inputs, lift duplicates — keep this repo small), **bumper** (one input per round, oldest-first; nixpkgs > kin > iets priority). Gate: all 3 kin-managed hosts eval + dry-build. See `.claude/commands/grind.md`.
