# Change NixOS a bit to make it more compatible with Ubuntu.
{ ... }:
{
  programs.nix-ld.enable = true;
  services.envfs.enable = true;
}
