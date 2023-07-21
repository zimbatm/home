{ inputs, ... }:

{
  imports = [
    ./disko.nix
    inputs.disko.nixosModules.default
    inputs.self.nixosModules.common
    inputs.self.nixosModules.gotosocial
    inputs.sops-nix.nixosModules.default
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
    inputs.srvos.nixosModules.server
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  home-manager.users.zimbatm = {
    imports = [ inputs.self.homeModules.terminal ];
    home.stateVersion = "22.11";
  };

  system.stateVersion = "18.09";
}
