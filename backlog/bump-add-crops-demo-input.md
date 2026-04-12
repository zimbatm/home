# bump: add crops-demo flake input

## What

Add `inputs.crops-demo` to `flake.nix` (with `inputs.nixpkgs.follows =
"nixpkgs"` to keep the lock small) and regenerate `flake.lock`. The
sibling lives at `../crops-demo`; pin to its origin remote, not a path.

Gate: all 3 hosts eval + dry-build with the new input present but
unconsumed.

## Why

`backlog/adopt-crops-userland.md` needs `inputs.crops-demo.nixosModules.vfio-host`
and `inputs.crops-demo.packages.*` — both require the input to exist.
The original plan had `adopt-niri-session` add it, but r14 meta
re-scoped niri to nixpkgs-only (see `tried/adopt-niri-session.md`; the
niri module never consumed crops-demo, only cribbed config.kdl at
authoring time). So the input was never added, and adopt-crops-userland
is currently unactionable.

Adding an input rewrites `flake.lock`, which is denylisted for
implementer (r14: both impl runs that touched it were abandon-routed).
Bumper owns lock changes — precedent `bump-add-treefmt-nix-input` →
f7eaa19.

## How much

~0.1r. One `inputs.*` line + `nix flake lock --update-input crops-demo`
+ gate. No consumers yet, so eval can't break on crops-demo internals.

## Blockers

None. Unblocks `adopt-crops-userland.md`.
