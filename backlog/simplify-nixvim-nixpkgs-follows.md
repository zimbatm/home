# nixvim: only direct input without nixpkgs.follows — drops nixpkgs_2

## What

`nixvim` is the sole direct input in `flake.nix` that does **not** set
`inputs.nixpkgs.follows = "nixpkgs"`. Every other input with a nixpkgs
dep already follows (kin, iets, home-manager, srvos, nix-index-database,
llm-agents, nix-skills). Result: lock carries a second full nixpkgs:

```
$ jq -r '.nodes.nixvim.inputs' flake.lock
{ "flake-parts": "flake-parts_2", "nixpkgs": "nixpkgs_2", "systems": "systems_3" }
$ jq -r '.nodes.nixpkgs.locked.rev, .nodes.nixpkgs_2.locked.rev' flake.lock
4c1018dae018162ec878d42fec712642d214fdfa
b63fe7f000adcfa269967eeff72c64cafecbbebe
```

Two distinct nixpkgs revs evaluated. `nixpkgs_2` is the heaviest
duplicate node in the lock (the others — flake-parts_2, systems_2/3,
blueprint_2 — are tiny utility flakes; drift@1785d19 already ruled
those transitives not-actionable-here).

## Why

- One nixpkgs eval, not two — faster `nix flake update`, smaller closure
  for the eval cache, consistent package set between `packages.nvim`
  (built from nixvim's nixpkgs) and the rest of the system.
- Consistency: makes the inputs block uniform — every line that can
  follow nixpkgs, does.

## How

`flake.nix:12`, change:
```nix
nixvim.url = "github:nix-community/nixvim";
```
to:
```nix
nixvim = { url = "github:nix-community/nixvim"; inputs.nixpkgs.follows = "nixpkgs"; };
```
then `nix flake lock` (no `--update-input`, just relock). Expect
`nixpkgs_2` to vanish from `flake.lock`; `flake-parts_2` stays (nixvim
still declares its own flake-parts) but its `nixpkgs-lib` now resolves
to root nixpkgs.

## How much

−1 lock node (`nixpkgs_2`). 1-line flake.nix edit. Net: lock shrinks
~25 lines.

## Blockers / risk

nixvim upstream pins its own nixpkgs for a reason — `makeNixvim` may
hit a nixpkgs API drift against our nixos-unstable rev. If
`packages.nvim` fails to eval/build after the follows, **don't pin
back** — instead check whether `packages.nvim` is still wanted at all
(both `myvim` and `nvim` exist; terminal/default.nix installs both).
That'd be a separate simplify.

## Gate

```sh
nix flake lock
jq -e '.nodes | has("nixpkgs_2") | not' flake.lock
nix build --dry-run .#packages.x86_64-linux.nvim
for h in nv1 web2 relay1; do nix build --dry-run .#nixosConfigurations.$h.config.system.build.toplevel; done
```
