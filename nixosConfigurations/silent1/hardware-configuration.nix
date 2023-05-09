# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
  ];

  boot.initrd.availableKernelModules = [
    "ahci"
    "ohci_pci"
    "ehci_pci"
    "xhci_pci"
    "sd_mod"
    "it87" # for sensors
  ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/fd4ef289-1417-4030-8d5c-ebbb9890709c";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/cc4c007c-d01d-4aab-a1bc-40976ad84318";
      fsType = "ext2";
    };

  fileSystems."/data" =
    {
      device = "/dev/sda";
      fsType = "btrfs";
    };

  fileSystems."/mnt" =
    {
      device = "/dev/disk/by-uuid/ca5f565f-e9ac-43dd-9875-fcfaf13a3f30";
      fsType = "btrfs";
    };

  swapDevices = [ ];

  nix.settings.max-jobs = lib.mkDefault 6;
}
