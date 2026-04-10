# kin.nix users.zimbatm.profile → dangling homeConfigurations ref

## What

`kin.nix:11` sets `profile = "github:zimbatm/home#homeConfigurations.zimbatm"`
but this flake exports no `homeConfigurations` attr:

    $ nix eval .#homeConfigurations --apply builtins.attrNames
    error: flake '...' does not provide attribute 'homeConfigurations'

flake.nix outputs: nixosModules homeModules packages nixosConfigurations
kinManifest devShells formatter. `git log -S homeConfigurations -- flake.nix`
shows it was never exported here.

## Why it matters

kin's users service applies `profile` via `nix profile install <ref>` on
the target at deploy time. With a non-existent attr this either silently
no-ops or fails post-switch — neither is what the line implies. The
actual home-manager config for zimbatm ships via
`home-manager.users.zimbatm` in `hosts/nv1/configuration.nix` (NixOS
module integration), not via standalone profile.

## Fix — pick one

- **Drop it** (likely): delete kin.nix:11. The hm config already lands
  via the NixOS module path on nv1. −1 line in the spine; one less
  dead-on-arrival deploy step. Gate: all 3 hosts eval+dry-build (kin.nix
  schema change is the only risk).
- **Wire it**: add `homeConfigurations.zimbatm = home-manager.lib.homeManagerConfiguration {...}`
  to flake.nix if standalone `home-manager switch` on non-NixOS hosts
  is actually wanted. +~8 LoC.

## Blockers

None for **drop**. Touches kin.nix (spine) so one-change-per-round
applies. Verify `kin gen --check` still passes after.
