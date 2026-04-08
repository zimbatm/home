{ inputs, kin, ... }:
{
  imports = [
    inputs.self.nixosModules.gotosocial
    inputs.self.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
  ];

  # BIOS+GPT: sda2 is BIOS-boot, sda1 ESP holds kernels. Without this, grub is
  # never updated — reboot would land on gen 17 (Jul 2024).
  boot.loader.grub = { enable = true; device = "/dev/sda"; };
  fileSystems."/boot" = { device = "/dev/disk/by-partlabel/disk-sda-ESP"; fsType = "vfat"; };

  sops.defaultSopsFile = ./secrets.yaml;

  systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:c012:d0d0::1/64";

  home-manager.users.zimbatm = {
    imports = [ inputs.self.homeModules.terminal ];
    home.stateVersion = "22.11";
  };

  system.stateVersion = "18.09";
}
