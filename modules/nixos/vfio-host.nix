{ config, lib, ... }:
let
  cfg = config.crops;
  ids = "${cfg.gpu.vendorId}:${cfg.gpu.deviceId},${cfg.gpu.vendorId}:${cfg.gpu.audioId}";
in
{
  # Vendored from crops-demo (repo recreated-private 2026-04, source no longer
  # fetchable). Interface preserved so nv1's config is unchanged: bind the
  # named GPU+audio to vfio-pci before any native driver claims it.
  options.crops = {
    vfio.enable = lib.mkEnableOption "claim crops.gpu for vfio-pci at boot";
    gpu = {
      vendorId = lib.mkOption { type = lib.types.str; };
      deviceId = lib.mkOption { type = lib.types.str; };
      audioId = lib.mkOption { type = lib.types.str; };
    };
  };

  config = lib.mkIf cfg.vfio.enable {
    boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
    boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];
    boot.extraModprobeConfig = ''
      options vfio-pci ids=${ids}
      softdep nvidia pre: vfio-pci
      softdep nouveau pre: vfio-pci
    '';
  };
}
