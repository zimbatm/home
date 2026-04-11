# flake.nix: dead `flake = inputs.self` specialArg

## What

`flake.nix:64`:

```nix
specialArgs = { inherit inputs; flake = inputs.self; };
```

The `flake` alias is passed to every NixOS module but **nothing reads
it**. All 14 self-package refs go through `inputs.self.*`:

```sh
git grep -nE '\bflake\b' -- '*.nix'        # → only flake.nix:64 + shell vars/comments
git grep -c 'inputs\.self\.' -- '*.nix'    # → 17 (the live path)
```

home-manager modules can't see it either — `common.nix:57` only
forwards `inputs` via `extraSpecialArgs`.

## Why

Leftover from the blueprint→explicit migration (`27246c2`, 2026-04-08):
blueprint passed `{ inputs, flake, perSystem }`; the migration rewrote
all `perSystem`/`flake.*` callers to `inputs.self.*` but left the alias
in `specialArgs`. Three days on, zero adopters.

Dropping it makes `specialArgs` self-documenting (one key, one source of
truth: `inputs`) and removes a second name for the same thing.

## How much

```nix
specialArgs = { inherit inputs; };
```

−1 attr in flake.nix. No eval/build impact (unused arg).

## Gate

```sh
kin gen --check
for h in nv1 web2 relay1; do nix build --dry-run .#nixosConfigurations.$h.config.system.build.toplevel; done
```

## Blockers

None. Confirm kin's own modules don't read a `flake` specialArg
(grep `../kin` for `\bflake\b,` in module headers — unlikely, kin
uses its own arg conventions).
