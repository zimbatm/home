# svg-term + alpacasay: exported but never installed — needs-human

## What

`packages/svg-term/` (66 LoC) and `packages/alpacasay/` (6 LoC + llama.cow)
are exported via `flake.nix` but no host, module, or home-manager profile
pulls them in. Only refs are the flake.nix export lines themselves.

## Decision needed (Jonas)

Are these `nix run github:zimbatm/home#svg-term` / `#alpacasay` targets
from other machines or muscle memory? Grep can't see that.

- **If unused** → `git rm -r packages/svg-term packages/alpacasay` + drop
  the two flake.nix export lines. Net −72 LoC, −2 store-path deps,
  no more fetchYarnDeps/nodejs lockfile maintenance.
- **If used interactively** → keep, add a one-line `# nix run target`
  comment at the flake.nix export so the next simplifier round skips it.

## Blockers

needs-human — do NOT auto-drop. Dropping breaks `nix run` callers
silently (no eval error here).
