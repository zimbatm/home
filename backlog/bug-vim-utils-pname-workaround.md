# bug-vim-utils-pname-workaround

## What

Remove `overlays/vim-utils-pname-fix.nix` once nixvim or nixpkgs fixes the
pname/name fallback in `vim-utils.packDir`.

## Why

flake.lock bump f5bd72e (nixpkgs b12141ef → 0726a0ec) introduced

```nix
allAndOptPluginNames = map (plugin: plugin.pname) (allPlugins ++ opt);
```

in `pkgs/applications/editors/vim/plugins/utils/vim-utils.nix:221`.

The `nvim-config` derivation built by nixvim's
`modules/top-level/files/default.nix` uses `pkgs.runCommandLocal "nvim-config"
{...}` which sets `name` but no `pname` — so any wrapped neovim trips
`error: attribute 'pname' missing` at eval time.

The workaround patches the nixpkgs source to use `plugin.pname or plugin.name`
(non-IFD: `readFile` + `replaceStrings` + `toFile`), wired into three call
sites: `flake.nix#pkgsFor` (flake outputs), `modules/nixos/common.nix`
(system pkgs / home-manager), and `packages/nvim/default.nix`
(nixvim's own pkgs eval).

## How much

Small. Once upstream lands a fix:

1. Delete `overlays/vim-utils-pname-fix.nix`.
2. Drop the three references (overlay arg in `pkgsFor`, `nixpkgs.overlays`
   in `common.nix`, `nixpkgs.overlays` module config in `packages/nvim`).
3. `nix flake update` and verify all 3 hosts dry-build.

## Blockers

Upstream fix in either repo unblocks removal:

- nixvim: add `pname = "nvim-config";` to the `runCommandLocal` call in
  `modules/top-level/files/default.nix`.
- nixpkgs: change `plugin.pname` to `plugin.pname or plugin.name` in
  `pkgs/applications/editors/vim/plugins/utils/vim-utils.nix:221`.
