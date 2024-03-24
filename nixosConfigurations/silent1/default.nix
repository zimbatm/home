# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, inputs, ... }:

{
  imports = [
    ./samba.nix
    ./hardware-configuration.nix
    inputs.self.nixosModules.server
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.extraModprobeConfig = ''
    options kvm ignore_msrs=1
  '';

  environment.systemPackages = [
    pkgs.hdparm
    pkgs.rclone
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.hostName = "silent1";

  powerManagement.powerUpCommands = ''
    # auto-shutdown HDDs after 2 minutes of inactivity
    ${pkgs.hdparm}/bin/hdparm -S24 /dev/sd*

    # powertop settings
    echo '1' > '/sys/module/snd_hda_intel/parameters/power_save'
    echo '1500' > '/proc/sys/vm/dirty_writeback_centisecs'
    echo 'auto' > '/sys/bus/i2c/devices/i2c-2/device/power/control'
    echo 'auto' > '/sys/bus/i2c/devices/i2c-9/device/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:00.0/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:11.0/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:12.0/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:12.2/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:13.0/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:13.2/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:14.2/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:14.3/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:14.4/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:14.5/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:16.0/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:16.2/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:18.0/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:18.1/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:18.2/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:18.3/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:18.4/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:00:18.5/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:03:00.0/power/control'
    echo 'auto' > '/sys/bus/pci/devices/0000:04:00.0/power/control'
    echo 'min_power' > '/sys/class/scsi_host/host0/link_power_management_policy'
    echo 'min_power' > '/sys/class/scsi_host/host1/link_power_management_policy'
    echo 'min_power' > '/sys/class/scsi_host/host2/link_power_management_policy'
    echo 'min_power' > '/sys/class/scsi_host/host3/link_power_management_policy'
    echo 'min_power' > '/sys/class/scsi_host/host4/link_power_management_policy'
    echo 'min_power' > '/sys/class/scsi_host/host5/link_power_management_policy'
  '';

  security.acme.acceptTerms = true;
  security.acme.certs."wild-ztm" = {
    credentialsFile = "/var/secrets/namecheap-credentials.env";
    dnsProvider = "namecheap";
    domain = "*.ztm.io";
    email = "zimbatm@zimbatm.com";
    postRun = "systemctl reload nginx.service";
  };

  users.users.nginx.extraGroups = [ "acme" ];

  services.nginx = {
    enable = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    statusPage = true;
    commonHttpConfig = ''
      resolver 127.0.0.1 valid=5s;
    '';
  };

  services.k3s.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "18.09"; # Did you read the comment?
}
