# flake.nix: 5 module exports never consumed via `inputs.self.*`

## What

`flake.nix` exports 9 `nixosModules` + 2 `homeModules`. Of those, 5 are
only ever pulled in by **relative path** from sibling modules, never via
`inputs.self.nixosModules.*` / `inputs.self.homeModules.*`:

| export                              | sole consumer            | via              |
|-------------------------------------|--------------------------|------------------|
| `nixosModules.perlless`             | `common.nix`             | `./perlless.nix` |
| `nixosModules.zimbatm`              | `common.nix`             | `./zimbatm.nix`  |
| `nixosModules.pinned-nix-registry`  | `desktop.nix`            | `./pinned-nix-registry.nix` |
| `nixosModules.ubuntu-light`         | `desktop.nix`            | `./ubuntu-light.nix` |
| `homeModules.terminal`              | `home/desktop/default.nix` | `../terminal`  |

Verified no other refs:
```sh
git grep -n 'nixosModules\.\(perlless\|zimbatm\|pinned-nix-registry\|ubuntu-light\)\|homeModules\.terminal' -- '*.nix'
# → only the flake.nix export lines themselves
```

## Why

The flake-level exports are dead surface — dropping them shrinks
`nixosModules` to the 5 actual host entrypoints (`common desktop gnome
gotosocial steam`) and `homeModules` to just `desktop`. Net −5 LoC in
flake.nix; export set then matches what `hosts/*/configuration.nix`
actually reach for.

**Counter-argument / check before doing:** ADR-0006 ("explicit — no
auto-discovery") may intend `nixosModules` as the canonical inventory of
*all* module files, not just entrypoints. If so, wontfix this and add a
one-line comment at the attrset saying so, so the next simplifier round
skips it.

## How much

−5 LoC flake.nix. No eval/build impact (paths still imported relatively).

## Gate

```sh
kin gen --check && nix eval .#nixosConfigurations --apply builtins.attrNames
for h in nv1 web2 relay1; do nix build --dry-run .#nixosConfigurations.$h.config.system.build.toplevel; done
```

## Blockers

None — pure flake.nix edit, no `gen/` or deploy impact. Decide ADR-0006
intent first (5min), then either drop the 5 lines or comment-and-wontfix.
