{ ... }:
{
  boot.tmp.cleanOnBoot = true;
  # Only enable during install.
  # See https://github.com/numtide/srvos/pull/7#discussion_r1056769536
  # boot.loader.efi.canTouchEfiVariables = true;

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.opengl.enable = true;
}
