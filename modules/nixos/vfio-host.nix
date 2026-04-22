# NixOS module to reserve a PCI device for VFIO passthrough.
#
# Vendored from crops-demo (repo recreated-private 2026-04). Original
# pulled defaults from ./gpu-default.nix; here defaults are dropped —
# nv1 sets all IDs explicitly.
#
# Usage:
#   crops.vfio.enable = true;
#   crops.gpu = { vendorId = "10de"; deviceId = "28a0"; audioId = "22be"; };
#
# `crops.vfio.pciIds` is derived from `crops.gpu` by default but can be
# overridden directly for multi-device or non-GPU passthrough setups.
{
  config,
  lib,
  ...
}:
let
  cfg = config.crops.vfio;
  gpu = config.crops.gpu;
in
{
  options.crops.gpu = {
    vendorId = lib.mkOption {
      type = lib.types.str;
      description = "PCI vendor ID of the passthrough GPU (4 hex digits).";
    };
    deviceId = lib.mkOption {
      type = lib.types.str;
      description = "PCI device ID of the GPU function (4 hex digits).";
    };
    audioId = lib.mkOption {
      type = lib.types.str;
      description = "PCI device ID of the GPU's HDMI/DP audio function (4 hex digits).";
    };
  };

  options.crops.vfio = {
    enable = lib.mkEnableOption "VFIO passthrough for CROPS VM";

    pciIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${gpu.vendorId}:${gpu.deviceId}"
        "${gpu.vendorId}:${gpu.audioId}"
      ];
      defaultText = lib.literalExpression ''
        [
          "''${config.crops.gpu.vendorId}:''${config.crops.gpu.deviceId}"
          "''${config.crops.gpu.vendorId}:''${config.crops.gpu.audioId}"
        ]
      '';
      example = [
        "10de:28a0"
        "10de:22be"
      ];
      description = ''
        PCI vendor:device IDs to claim with vfio-pci at boot.
        Find yours with: lspci -nn | grep -i nvidia
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
    ];

    boot.initrd.kernelModules = [
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
    ];

    boot.extraModprobeConfig = ''
      options vfio-pci ids=${lib.concatStringsSep "," cfg.pciIds}
      softdep nvidia pre: vfio-pci
      softdep amdgpu pre: vfio-pci
      softdep nouveau pre: vfio-pci
    '';
  };
}
