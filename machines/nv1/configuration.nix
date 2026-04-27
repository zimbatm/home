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
    inputs.self.nixosModules.niri
    inputs.self.nixosModules.steam
    inputs.srvos.nixosModules.mixins-systemd-boot
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Hybrid graphics: Intel Arc (Meteor Lake iGPU) drives the display; NVIDIA
  # RTX 4060 Max-Q is the compute dGPU (CUDA / llama.cpp). Apps stay on Intel
  # by default and opt into the dGPU via the `nvidia-offload` wrapper from
  # prime.offload.enableOffloadCmd.
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    intel-compute-runtime
    intel-media-driver
  ];

  # Meteor Lake NPU (Intel AI Boost) — exploration: OpenVINO Whisper offload off the iGPU.
  # nixos module wires intel-npu-driver.firmware (intel/vpu/vpu_37xx_v1.bin) + libze_intel_npu.so
  # into /run/opengl-driver, plus level-zero loader & npu validation tools in PATH.
  # Kernel 6.18 ships ivpu (CONFIG_DRM_ACCEL_IVPU=m); load explicitly for first-boot enumeration.
  # Verify post-deploy: `ls /dev/accel/` and `vpu-umd-test` / openvino Core().available_devices.
  hardware.cpu.intel.npu.enable = true;
  boot.kernelModules = [ "ivpu" ];

  # uinput access for ptt-dictate (ydotool type)
  programs.ydotool.enable = true;

  # NVIDIA RTX 4060 Max-Q (Ada / AD107M) for CUDA compute. Open kernel
  # modules — supported on Ada from the 555 series; production (595.58.03)
  # ships the matching userspace and pairs with cudaPackages_13. Display
  # stays on the Intel Arc iGPU; offload via `nvidia-offload <cmd>`.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.production;
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = false;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 8;

  environment.systemPackages = [
    # For debugging and troubleshooting Secure Boot.
    pkgs.sbctl

    # NPU exploration — OpenVINO runtime (built with ENABLE_INTEL_NPU) + python bindings.
    pkgs.openvino
    (pkgs.python3.withPackages (p: [ p.openvino ]))

    pkgs.perf
    pkgs.pam_u2f # provides pamu2fcfg for enrolling the YubiKey
  ];

  # Debugging tools
  programs.bcc.enable = true;
  programs.sysdig.enable = true;

  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.trusted-users = [ "zimbatm" ];

  # sudo/login/unlock via YubiKey touch (FIDO2). Enroll: pamu2fcfg > ~/.config/Yubico/u2f_keys
  security.pam.u2f = {
    enable = true;
    settings.cue = true;
  };
  security.pam.services.sudo.u2fAuth = true;
  security.pam.services.gdm-password.u2fAuth = true;
  security.pam.services.login.u2fAuth = true;
  security.pam.services.polkit-1.u2fAuth = true;

  time.timeZone = "Europe/Zurich";

  # Configure the home-manager profile
  home-manager.users.zimbatm = {
    imports = [ inputs.self.homeModules.desktop ];
    config.home.stateVersion = "22.11";
    # Policy 2026-04-14: sink-monitor → NPU transcript on; 30d retention; `live-caption off` to pause.
    config.home.live-caption.enable = true;
    # infer-queue: device-tagged background inference (arc/npu/cpu lanes, nv1-only hardware).
    config.home.packages = [
      inputs.iets.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.infer-queue
    ];
    config.services.pueue.enable = true;
  };

  # Auto-tune power management settings
  powerManagement.powertop.enable = true;
}
