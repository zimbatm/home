# `modules/nixos/server.nix` — exported, never imported

**What:** Verify nothing wires `nixosModules.server`, then delete it
(and its `flake.nix:32` export).

`grep -rn 'nixosModules.server' .` → only the export line. Neither
`web2` nor `relay1` import it; both use `profile = "hetzner-cloud"`
which presumably brings srvos-server itself. The module is 7 lines:
`./common.nix` + `inputs.srvos.nixosModules.server` — both of which kin
already provides to server-profile hosts.

**Why:** Vestigial from pre-kin days when hosts imported `server`
manually. Now the profile owns that role.

**How much:** Confirm with
`nix eval .#nixosConfigurations.web2.config.services.openssh.enable`
(srvos-server sets it) — if `true` without our module, delete. ~5 min.

**Blockers:** Low-confidence — needs the eval check before deleting. If
kin's `hetzner-cloud` profile does *not* import srvos-server, then the
right fix is the opposite: web2/relay1 should import this module.
Either way the current state (exported, unused) is wrong.
