{ inputs, kin, ... }:
{
  imports = [
    inputs.self.nixosModules.gotosocial
    inputs.self.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:c012:d0d0::1/64";

  home-manager.users.zimbatm = {
    imports = [ inputs.self.homeModules.terminal ];
    home.stateVersion = "22.11";
  };

  system.stateVersion = "18.09";
}
