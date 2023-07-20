{ ... }:
{
  flake.nixosModules = {
    common = ./common.nix;
    desktop = ./desktop.nix;
    gnome = ./gnome.nix;
    gotosocial = ./gotosocial.nix;
    server = ./server.nix;
  };
}
