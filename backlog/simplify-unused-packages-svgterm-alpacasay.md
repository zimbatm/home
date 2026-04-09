# svg-term + alpacasay: exported packages never installed anywhere

## What

`packages/svg-term/` (66 LoC) and `packages/alpacasay/` (6 LoC + llama.cow)
are exported via `flake.nix:43-44` but no host, module, or home-manager
profile pulls them in. Only refs are the flake.nix export lines themselves:

    $ git grep -l svg-term
    flake.nix
    packages/svg-term/default.nix
    $ git grep -l alpacasay
    flake.nix
    packages/alpacasay/default.nix

Contrast: `core`, `myvim`, `nvim` are all consumed by
modules/home/{desktop,terminal} or modules/nixos/zimbatm.nix.

## Why

~72 LoC ≈ 6% of the repo's 1122 .nix LoC, for tools that don't land on
any machine. svg-term in particular is yarn/node build machinery that
adds maintenance surface (fetchYarnDeps hash, nodejs, lockfile drift).

## How much

If unused: `git rm -r packages/svg-term packages/alpacasay` + drop two
lines from flake.nix `packages = ...`. Net −72 LoC, −2 store-path deps.

If used interactively (`nix run .#svg-term`): keep, but add a one-line
comment at the flake.nix export saying so, so the next simplifier round
doesn't re-raise this.

While in there: `modules/home/desktop/activitywatch.nix:1` declares
`inputs` in its arg-set but never uses it — drop for −1 token.

## Blockers

Human call — these are Jonas's personal-toolbox packages and may be
`nix run` targets from other machines. Grep can't see that. Ask before
deleting; do NOT auto-drop.

## Falsifies

If `nix run github:zimbatm/home#svg-term` is in muscle memory or CI
anywhere, dropping breaks it silently (no eval error here).

## Simplifier sweep r260409 — rest came up clean

- All 9 `nixosModules` reachable (common/perlless/zimbatm/ubuntu-light/
  pinned-nix-registry via transitive imports from desktop+common).
- Both `homeModules` reachable via nv1 home-manager.
- All 9 flake inputs referenced (iets via devshell only; nixvim via
  packages/nvim only — both legit).
- No zerotier/tailscale/mesh leftovers in comments.
- No per-host duplication to lift (relay1 intentionally minimal; nv1+web2
  already share via common.nix).
- Recent rounds already landed: d20d655 (−112 LoC lib+shim), c9740f3
  (−17 LoC nv1 defaults).
