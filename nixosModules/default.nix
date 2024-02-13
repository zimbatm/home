{ ... }:
{
  flake.nixosModules = {
    common = ./common.nix;
    desktop = ./desktop.nix;
    gnome = ./gnome.nix;
    gotosocial = ./gotosocial.nix;
    mycelium = ./mycelium.nix;
    nix-remote-builders = ./nix-remote-builders.nix;
    server = ./server.nix;
  };
}
