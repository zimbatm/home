{
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
  hardware.graphics.extraPackages = with pkgs; [ intel-compute-runtime intel-media-driver ];

  # Meteor Lake NPU (Intel AI Boost) — exploration: OpenVINO Whisper offload off the iGPU.
  # nixos module wires intel-npu-driver.firmware (intel/vpu/vpu_37xx_v1.bin) + libze_intel_npu.so
  # into /run/opengl-driver, plus level-zero loader & npu validation tools in PATH.
  # Kernel 6.18 ships ivpu (CONFIG_DRM_ACCEL_IVPU=m); load explicitly for first-boot enumeration.
  # Verify post-deploy: `ls /dev/accel/` and `vpu-umd-test` / openvino Core().available_devices.
  hardware.cpu.intel.npu.enable = true;
  boot.kernelModules = [ "ivpu" ];

  # uinput access for ptt-dictate (ydotool type)
  programs.ydotool.enable = true;

  # Claim NVIDIA GPU + audio for vfio-pci at boot, before nvidia driver loads.
  boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
  boot.initrd.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1" ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=10de:28a0,10de:22be
    softdep nvidia pre: vfio-pci
  '';

  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 8;

  environment.systemPackages = [
    # For debugging and troubleshooting Secure Boot.
    pkgs.sbctl

    # NPU exploration — OpenVINO runtime (built with ENABLE_INTEL_NPU) + python bindings.
    pkgs.openvino
    (pkgs.python3.withPackages (p: [ p.openvino ]))

    pkgs.perf
    pkgs.pam_u2f  # provides pamu2fcfg for enrolling the YubiKey
  ];

  # Debugging tools
  programs.bcc.enable = true;
  programs.sysdig.enable = true;

  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.trusted-users = [ "zimbatm" ];

  # sudo/login/unlock via YubiKey touch (FIDO2). Enroll: pamu2fcfg > ~/.config/Yubico/u2f_keys
  security.pam.u2f = { enable = true; settings.cue = true; };
  security.pam.services.sudo.u2fAuth = true;
  security.pam.services.gdm-password.u2fAuth = true;
  security.pam.services.login.u2fAuth = true;
  security.pam.services.polkit-1.u2fAuth = true;

  time.timeZone = "Europe/Zurich";

  # Configure the home-manager profile
  home-manager.users.zimbatm = {
    imports = [ inputs.self.homeModules.desktop ];
    config.home.stateVersion = "22.11";
    # infer-queue: device-tagged background inference (arc/npu/cpu lanes, nv1-only hardware).
    config.home.packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.infer-queue ];
    config.services.pueue.enable = true;
  };

  # Auto-tune power management settings
  powerManagement.powertop.enable = true;
}
