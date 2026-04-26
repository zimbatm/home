# bump: kin (unblocks simplify-drop-default-nix-shim)

## What

`nix flake update kin` — pin is at 65eccea0, kin origin/main is 104
commits ahead. Target: land past **8b24bfd5** `feat(evaluator): Iets
bootstraps from flake.lock when default.nix absent` (merged 75286174).

## Why

Unblocks `backlog/simplify-drop-default-nix-shim.md` condition #2 —
once pinned past 8b24bfd5, `default.nix` can be `git rm`'d (kin's
`_iets_entry()` reads `flake.lock` directly; the shim is dead).

Also picks up 849f82dd hetzner-profile gc tightening (3d-daily +
limine maxGenerations=20) — neutral for home (no hetzner hosts) but
keeps profile imports current.

## How much

One `nix flake update kin` + `kin gen` + 3-host eval/dry-build gate.
Watch for evaluator.py 438→497L churn (kin meta(r15) flagged
ARCH-GATE-FIRE 470L seam) — eval-only impact, no NixOS module changes
in 65eccea0..origin/main affecting home machines.

## Blockers

None. Bumper-owned; priority `kin` is #2 after nixpkgs per CLAUDE.md.
nixpkgs is 4d-fresh per drift @ 30fe0e2, so kin is next-oldest internal.
