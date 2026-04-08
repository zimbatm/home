# nv1: hostName/openssh/grub already set by kin+srvos

**What:** Drop from `hosts/nv1/configuration.nix`:
- `networking.hostName = "nv1";` — kin.mkFleet sets it from the machine
  key (verified: web2 evals to `"web2"` with no explicit set).
- `services.openssh.enable = true;` — srvos `common` (pulled via
  desktop→common→`inputs.srvos.nixosModules.common`) enables it.
- `boot.loader.grub.configurationLimit` — nv1 imports
  `mixins-systemd-boot`; grub isn't the loader.
- The 6-line `system.stateVersion` boilerplate comment + the one-word
  `# Hostname` / `# Bootloader.` / `# Enable the OpenSSH daemon.`
  noise comments.

**Why:** nv1 is the largest host file (~75 lines); ~15 of them restate
what kin/srvos already provide or comment the obvious. Keeps the
38-line-kin spirit.

**How much:** Edit + `nix eval` diff:
```sh
nix eval .#nixosConfigurations.nv1.config.networking.hostName        # "nv1"
nix eval .#nixosConfigurations.nv1.config.services.openssh.enable    # true
nix eval .#nixosConfigurations.nv1.config.boot.loader.grub.enable    # false
```
All three should hold *after* the deletes. ~5 min.

**Blockers:** None — eval-verifiable, no deploy needed.
