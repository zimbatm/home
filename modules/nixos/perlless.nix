{ lib, ... }:
{
  # see https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/perlless.nix

  # Remove perl from activation
  boot.initrd.systemd.enable = true; # override SrvOS
  system.etc.overlay.enable = lib.mkDefault true;
  services.userborn.enable = lib.mkDefault true;

  # Random perl remnants
  boot.enableContainers = lib.mkDefault false;
  boot.loader.grub.enable = lib.mkDefault false;
  documentation.info.enable = lib.mkDefault false;
  environment.defaultPackages = lib.mkDefault [ ];
  programs.command-not-found.enable = lib.mkDefault false;
  programs.less.lessopen = lib.mkDefault null;
  system.disableInstallerTools = lib.mkDefault true;

  # Check that the system does not contain a Nix store path that contains the
  # string "perl".
  #
  # Cannot activate because of dependency on Git.
  # system.forbiddenDependenciesRegex = ["perl"];

  # Re-add nixos-rebuild to the systemPackages that was removed by the
  # `system.disableInstallerTools` option.
  # environment.systemPackages = [pkgs.nixos-rebuild];
}
