{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.gotosocial
    inputs.srvos.nixosModules.mixins-nginx
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # IPv4 via DHCP, IPv6 via hetzner-ipv6.service (kin profile) — no hardcoded addresses.

  system.stateVersion = "26.05";
}
