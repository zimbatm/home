# `lib/` + local `flake-shim.nix` — 112 LoC, zero consumers

**What:** Delete `lib/` (default.nix + mkWineApp.nix, 50 LoC) and the
top-level `flake-shim.nix` (62 LoC).

`grep -rn 'mkWineApp\|self\.lib' --include='*.nix'` → only
`lib/default.nix` itself. flake.nix has no `lib` output. Nothing calls
`mkWineApp` — wine apps were dropped long ago.

`grep -rn flake-shim` → `default.nix:13` imports
`kinSrc + "/lib/flake-shim.nix"` (kin's copy, upstreamed), not the
local one. The local file is the pre-upstream original, now vestigial.

**Why:** ~7% of total repo LoC is dead. mkWineApp predates the current
fleet (no wine packages remain); flake-shim was upstreamed to kin and
default.nix already switched over.

**How much:** `git rm -r lib flake-shim.nix`, then
`nix flake check && nix eval .#nixosConfigurations --apply builtins.attrNames`.
~2 min.

**Blockers:** None. Pure delete; neither path appears in any import
chain reachable from flake outputs.

**Falsifies:** `nix flake check` passes and all three hosts still eval
after the delete.
