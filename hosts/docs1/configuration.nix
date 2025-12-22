{
  inputs,
  flake,
  pkgs,
  ...
}:
{
  imports = [
    # Minimal import because this will be used by Garnix
    inputs.srvos.nixosModules.mixins-nginx
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # For Garnix
  boot.loader.grub.device = "/dev/sda";
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  # Use nginx to host the docs
  services.nginx.virtualHosts.default = {
    # Not supported by Garnix rn
    # enableACME = true;
    # forceSSL = true;

    # Serve the docs
    locations."/".root = flake.packages.${pkgs.stdenv.hostPlatform.system}.docs;
  };

  system.stateVersion = "24.05";
}
