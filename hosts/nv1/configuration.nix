{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    # NovaCustom V5xTNC: Intel Meteor Lake-H + NVIDIA RTX 4060 Max-Q
    # GPU: Intel Arc for display, NVIDIA reserved for VFIO passthrough
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.self.nixosModules.desktop
    inputs.self.nixosModules.gnome
    inputs.self.nixosModules.steam
    inputs.srvos.nixosModules.mixins-systemd-boot
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Intel Arc (Meteor Lake) handles display.
  # NVIDIA RTX 4060 Max-Q reserved for VFIO passthrough (CROPS VM).
  hardware.graphics.enable = true;

  # Claim NVIDIA GPU + audio for vfio-pci at boot, before nvidia driver loads.
  boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=10de:28a0,10de:22be
    softdep nvidia pre: vfio-pci
  '';

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

  # Auto-tune power management settings
  powerManagement.powertop.enable = true;

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
