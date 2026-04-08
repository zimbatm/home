{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.gotosocial
    inputs.srvos.nixosModules.mixins-nginx
  ];

  # IPv6 from Hetzner — v4 comes via DHCP (kin profile sets useDHCP).
  systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:c014:fac3::1/64";

  system.stateVersion = "26.05";
}
