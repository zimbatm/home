{ pkgs, inputs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.self.nixosModules.desktop
      inputs.home-manager.nixosModules.default
    ];

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.sway}/bin/sway";
      user = "zimbatm";
    };
  };

  boot.loader.systemd-boot.configurationLimit = 6;
  boot.loader.systemd-boot.enable = true;
  # Only enable during install
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.kernelModules = [ "i915" ];
  boot.kernelParams = [
    "i915.fastboot=1"
    #"plymouth.splash-delay=20"
  ];

  hardware.bluetooth.enable = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.opengl.enable = true;
  #hardware.enableAllFirmware = true; # for brcmfmac's binary blob
  #hardware.opengl.extraPackages = [ pkgs.vaapiIntel ];

  networking.hostName = "x1";

  nix.nixPath = [
    "nixpkgs=${toString pkgs.path}"
  ];

  nix.distributedBuilds = true;
  nix.buildMachines = [
    # { hostName = "build.numtide.com";
    # maxJobs = 8;
    # sshKey = "/root/.ssh/nix";
    # sshUser = "nixBuild";
    # system = "x86_64-linux";
    # }
  ];
  nix.envVars = {
    #NIX_DEBUG_HOOK = "1";
  };
  #nix.sandboxPaths = [ "/nix/cache" ];
  nix.settings.sandbox = "relaxed";

  programs.firejail.enable = true;

  # List services that you want to enable:

  services.openssh.enable = true;

  # fix for Intel CPU throttling
  services.throttled.enable = true;

  # For YubiKeys
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # security!
  services.usbguard = {
    enable = true;
    IPCAllowedGroups = [ "wheel" ];
  };

  swapDevices = [{ device = "/swapfile"; size = 10000; }];

  time.timeZone = "Europe/Paris";

  #virtualisation.virtualbox.host.enable = true;
  #virtualisation.virtualbox.host.enableExtensionPack = true;

  #virtualisation.libvirtd.enable = true;
  #networking.firewall.checkReversePath = false;

  home-manager.extraSpecialArgs.inputs = inputs;
  home-manager.users.zimbatm = {
    imports = [
      inputs.self.legacyPackages.${pkgs.system}.homeConfigurations.sway
    ];

    home.stateVersion = "22.11";
  };

  system.stateVersion = "18.09";
}
