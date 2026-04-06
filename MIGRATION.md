# kin migration (branch: kin-migration)

## Status

All four hosts evaluate under kin (`.#kinConfigurations.<host>`):

| host | builds | kin adds | kept untouched |
|---|---|---|---|
| no1 | ✓ | identity, wg mesh, kin-secrets, user cert | NVIDIA, sops bridge, srvos |
| nv1 | ✓ | identity, wg mesh | desktop, gnome |
| p1 | ✓ | identity (`kin://…/machine/p1`), wg mesh, 5 secrets | **lanzaboote**, **home-manager**, nixos-hardware |
| docs1 | ✓ | identity, wg mesh | nginx, garnix profile |

`relay` excluded — it's system-manager (not nixosSystem). Stays on blueprint.

## What kin replaces

| before | after |
|---|---|
| `.sops.yaml` with hand-maintained per-host recipient lists | recipients computed from `kin.nix` |
| zerotier + tailscale (both!) | `services.wireguard` over derived ULA `fd43:9803:aeed::/48` |
| `authorized_keys` file + per-host `openssh.authorizedKeys` | `services.identity.users.zimbatm = [ ed25519, sk-ed25519 ]` → CA-signed user certs (FIDO2 key signed too) |
| hardcoded `hashedPassword` in `zimbatm.nix` | `services.users` generates one |
| `networking.extraHosts = "172.28.61.193 no1.zt"` | (use derived-ULA + dns when added) |

## What's incremental

- sops-nix stays loaded with `sops.age.keyFile = "/var/lib/kin/key"` — existing secrets keep working until you `kin set` them.
- blueprint output unchanged (`.#nixosConfigurations.*` still works); kin's are at `.#kinConfigurations.*` for side-by-side diffing.
- Host configs in `hosts/` (symlinked as `machines/`) untouched.

## To do for real

1. Remove `migration-test` admin and re-gen with your real `zimbatm` key:
   ```sh
   sed -i 's/ "migration-test"//' kin.nix
   rm keys/admins/migration-test.*
   KIN_IDENTITY=~/.config/sops/age/keys.txt kin gen
   ```
2. Migrate the 3 sops secrets:
   ```sh
   sops -d hosts/no1/secrets.yaml | yq -r '.nix-remote-builder-key' | \
     kin set user/nix-remote-builder-key/_shared/key
   ```
3. Once all secrets migrated, drop `sops-nix` from `flake-kin.nix` and update consumers from `config.sops.secrets.X.path` → `kin.gen."user/X".key`.
4. Consider dropping zerotier + tailscale once kin0 mesh is up everywhere.
5. Seed each machine's `/var/lib/kin/key` (no1's existing sops-age key works as-is; others need the generated `keys/machines/<m>.key` copied or use on-host keygen).

## Required kin change

Added `specialArgs` to `mkFleet` so host configs can keep referencing `inputs.self.nixosModules.*`. One-line lib change.
