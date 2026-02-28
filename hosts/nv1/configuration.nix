{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p16s-amd-gen1
    inputs.self.nixosModules.desktop
    inputs.self.nixosModules.gnome
    inputs.self.nixosModules.steam
    inputs.iroh-nix.nixosModules.default
    inputs.srvos.nixosModules.mixins-systemd-boot
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.grub.configurationLimit = lib.mkDefault 8;
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 8;

  environment.systemPackages = [
    # For debugging and troubleshooting Secure Boot.
    pkgs.sbctl

    pkgs.perf
  ];

  # Debugging tools
  programs.bcc.enable = true;
  programs.sysdig.enable = true;

  # Bootloader.
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.trusted-users = [ "zimbatm" ];

  # Hostname
  networking.hostName = "nv1";

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # Configure the home-manager profile
  home-manager.users.zimbatm = {
    imports = [ inputs.self.homeModules.desktop ];
    config.home.stateVersion = "22.11";
  };

  # iroh-nix P2P Nix artifact distribution
  services.iroh-nix = {
    enable = true;
    package = inputs.iroh-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
    daemon.enable = true;
    substituter.enable = true;
    relayUrl = "https://relay.iroh.network";
    network = "zimbatm";
    peers = [
      "9a10928c9589fe79e08323907b5dda6e0f3e2ceee5d29589976e480cb026e27d"
    ];
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
