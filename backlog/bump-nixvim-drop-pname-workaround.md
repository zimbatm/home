# bump-nixvim-drop-pname-workaround

(was `bug-vim-utils-pname-workaround` — renamed for flake.lock-write
routing now that upstream fix is confirmed and removal is unblocked.)

## What

Bump the `nixvim` input past its `pname = "nvim-config"` fix, then remove
`overlays/vim-utils-pname-fix.nix` and its three call sites.

## Why

flake.lock bump f5bd72e (nixpkgs b12141ef → 0726a0ec) introduced

```nix
allAndOptPluginNames = map (plugin: plugin.pname) (allPlugins ++ opt);
```

in `pkgs/applications/editors/vim/plugins/utils/vim-utils.nix:221`.

The `nvim-config` derivation built by nixvim's
`modules/top-level/files/default.nix` uses `pkgs.runCommandLocal "nvim-config"
{...}` which set `name` but no `pname` — so any wrapped neovim tripped
`error: attribute 'pname' missing` at eval time. c37cecc added a non-IFD
source-patch overlay as a workaround.

## Upstream status — FIXED both sides (verified 2026-04-26)

- **nixpkgs** c552f3dd37 (2026-04-24): `plugin.pname or null` fallback.
  Pinned 0726a0ec (2026-04-22) predates this.
- **nixvim** main: `pname = "nvim-config";` added at
  `modules/top-level/files/default.nix:104`. Pinned e61a31b5 (2026-04-25)
  predates this.

Either bump alone resolves the eval error. nixvim is the smaller surface.

## How much

1. `nix flake lock --update-input nixvim` — confirm new rev's
   `modules/top-level/files/default.nix` has `pname = "nvim-config";`.
2. Delete `overlays/vim-utils-pname-fix.nix`.
3. Drop the three references:
   - `flake.nix:65` — `overlays = [ ... ]` in `pkgsFor`
   - `modules/nixos/common.nix:56` — `nixpkgs.overlays`
   - `packages/nvim/default.nix:3` — `nixpkgs.overlays` module config
4. Gate: all 3 hosts eval + dry-build (`kin gen --check`; `nix build
   --dry-run .#nixosConfigurations.<h>.config.system.build.toplevel`).

If the nixvim bump pulls breakage unrelated to this fix, fall back to
`nix flake lock --update-input nixpkgs` instead (larger surface but the
fix is equally present there).

## Blockers

None — upstream landed both fixes; pinned revs are the only gap.
