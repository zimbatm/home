{ inputs, ... }:
{
  imports = [
    inputs.srvos.nixosModules.mixins-nginx
    # gotosocial added after data migration (module needs sops→kin secret port)
  ];

  # IPv4 via DHCP, IPv6 via hetzner-ipv6.service (kin profile) — no hardcoded addresses.

  system.stateVersion = "26.05";
}
