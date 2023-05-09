{ ... }:
{
  flake.nixosModules = {
    common = ./common.nix;
    desktop = ./desktop.nix;
    gnome = ./gnome.nix;
    server = ./server.nix;
  };
}
