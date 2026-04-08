# Drop kinStatus re-export (kin folded it into kinManifest)

## What

flake.nix:56 does `inherit (kinOut) ... kinStatus;`. kin's
grind/simplify-fold-kinstatus folded the per-machine toplevel into
`kinManifest.machines.<n>.toplevel` and left `kinStatus` as a deprecated
alias for one cycle so this flake keeps evaluating.

Drop `kinStatus` from the inherit. Nothing in this repo reads it (only
re-exported); downstream `kin status` reads `kinManifest.machines`
directly now.

## How much

flake.nix: `inherit (kinOut) nixosConfigurations kinManifest kinStatus;`
→ `inherit (kinOut) nixosConfigurations kinManifest;`. Net −1 token.

## Blockers

Land after the kin change reaches this flake's lock (next `nix flake
update kin`). Then file `../kin/backlog/cleanup-drop-kinstatus-alias.md`
so kin can drop the alias.

## Falsifies

If anything here (or a downstream) actually consumes `.#kinStatus` by
name, this breaks it — grep first.
