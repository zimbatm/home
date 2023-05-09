{ pkgs, lib, inputs, ... }:

{
  imports = [
    ./common.nix
    ./ubuntu-light.nix
    ./pinned-nix-registry.nix
    inputs.srvos.nixosModules.desktop
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "zerotierone"
  ];

  # set for VSCode
  boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

  # The sound system of the future. See https://nixos.wiki/wiki/PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    ntfs3g
    pciutils
  ];

  # Select internationalisation properties.
  console.keyMap = "us";
  console.font = "sun12x22";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.networkmanager.enable = true;

  # Allow Samba discovery
  networking.firewall.extraCommands = "iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns";
  services.gvfs.enable = true;

  programs.bash.enableCompletion = true;

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
