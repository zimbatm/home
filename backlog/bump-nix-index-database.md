# bump: nix-index-database bedba598 → c43246d4

**What:** `nix flake update nix-index-database` (bedba598, 2026-04-12 →
upstream HEAD c43246d4 as of 2026-04-22). 10d stale.

**Why:** Weekly-regenerated index; staleness directly degrades
`nix-locate`/comma hit rate. Last bump b1f1bb3 was all-host
closure-affecting.

**How much:** One commit. `nix flake update nix-index-database`, gate.
Trivially low-risk (data-only).

**Blockers:** None.
