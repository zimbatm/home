{ inputs, ... }:
{
  imports = [
    inputs.srvos.nixosModules.mixins-nginx
    # gotosocial added after data migration (module needs sops→kin secret port)
  ];

  systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:c014:fac3::1/64";

  system.stateVersion = "26.05";
}
