{ pkgs, inputs, ... }:

{
  imports = [
    ./common.nix
    ./ubuntu-light.nix
    ./pinned-nix-registry.nix
    inputs.srvos.nixosModules.desktop
  ];

  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    ntfs3g
    pciutils
  ];

  # Select internationalisation properties.
  console.keyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.networkmanager.enable = true;

  programs.bash.completion.enable = true;

  # List services that you want to enable:

  # For YubiKeys
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # for dconf in home-manager
  services.dbus.packages = with pkgs; [ pkgs.dconf ];

  services.fwupd.enable = true;

  # Desktop users are developers and use Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false;
}
