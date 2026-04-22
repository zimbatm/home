# bump-kin: BLOCKED — pinned at 45cd3818 until EROFS regression fixed

## What

Do NOT `nix flake update kin` past 45cd3818. fee393d deliberately pins
there.

## Why

kin a3795554 (iets-everywhere step-1) switched iets eval to
`--store local://`, which writes .drv direct to /nix/store. On
multi-user nix that's EROFS (no daemon:// in iets yet). 45cd3818 =
a3795554^ has the netrc-bridge fix (63e7a046) without the regression.

## Unblocks-when

`../kin/backlog/bug-iets-store-local-erofs-multiuser.md` is closed
(check: file gone from kin backlog AND `git -C ../kin grep 'local://'
cli/kin/nix.py` shows a writable-store guard or daemon fallback). Then
delete this file and bump normally.

## Blockers

../kin bug-iets-store-local-erofs-multiuser (cross-filed 2026-04-22).
