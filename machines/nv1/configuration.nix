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
    inputs.distro.nixosModules.distro
    # NovaCustom V5xTNC: Intel Meteor Lake-H + NVIDIA RTX 4060 Max-Q
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.self.nixosModules.desktop
    inputs.self.nixosModules.steam
    inputs.self.nixosModules.zero-tailnet
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

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.greetd.settings.default_session.user = "zimbatm";

  # Meteor Lake NPU (Intel AI Boost) — exploration: OpenVINO Whisper offload off the iGPU.
  # nixos module wires intel-npu-driver.firmware (intel/vpu/vpu_37xx_v1.bin) + libze_intel_npu.so
  # into /run/opengl-driver, plus level-zero loader & npu validation tools in PATH.
  # Kernel 6.18 ships ivpu (CONFIG_DRM_ACCEL_IVPU=m); load explicitly for first-boot enumeration.
  # Verify post-deploy: `ls /dev/accel/` and `vpu-umd-test` / openvino Core().available_devices.
  hardware.cpu.intel.npu.enable = true;
  boot.kernelModules = [ "ivpu" ];

  # Keep the declared workstation account aligned with the live desktop setup
  # so userborn doesn't try to rewrite the active user's primary group and
  # strip desktop/Docker access during switch.
  users.users.zimbatm.extraGroups = [
    "wheel"
    "audio"
    "video"
    "networkmanager"
    "docker"
    "input"
    "tss"
  ];

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

    pkgs.perf
    pkgs.pam_u2f # provides pamu2fcfg for enrolling the YubiKey
  ];

  networking.hostName = "nv1";

  # Debugging tools (and perf above)
  programs.bcc.enable = true;
  programs.sysdig.enable = true;

  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.trusted-users = [ "zimbatm" ];

  nix.settings.system-features = lib.mkForce [
    "kvm"
    "uid-range"
    "recursive-nix"
  ];

  # services.opencrow-local declares a NixOS container; the base
  # container unit is only generated when this is enabled.
  boot.enableContainers = true;

  # sudo/login/unlock via YubiKey touch (FIDO2). Enroll: pamu2fcfg > ~/.config/Yubico/u2f_keys
  security.pam.u2f = {
    enable = true;
    settings.cue = true;
  };

  # Richer sudo approval: ask the user's SSH agent to sign a challenge first.
  # The home-manager rich-ssh-agent proxy shows caller argv/cwd/process-tree
  # context before forwarding to the Yubi-backed key for the hardware touch.
  security.pam.rssh = {
    enable = true;
    settings.auth_key_file = "/etc/security/pam_rssh_authorized_keys.d/$ruser";
  };
  environment.etc."security/pam_rssh_authorized_keys.d/zimbatm" = {
    mode = "0444";
    text = ''
      sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1
    '';
  };
  security.pam.services.sudo.rssh = true;
  # Do not fall back to blind pam_u2f for sudo. If the contextual SSH-agent
  # path is unavailable, use the normal password path instead.
  security.pam.services.sudo.u2fAuth = false;
  security.pam.services.gdm-password.u2fAuth = true;
  security.pam.services.login.u2fAuth = true;
  security.pam.services.polkit-1.u2fAuth = true;

  time.timeZone = "Europe/Zurich";

  # Configure the home-manager profile
  home-manager.users.zimbatm = {
    imports = [ inputs.self.homeModules.desktop ];
    config.home.stateVersion = "22.11";
  };

  system.stateVersion = "26.05";

  # Auto-tune power management settings
  powerManagement.powertop.enable = true;
}
