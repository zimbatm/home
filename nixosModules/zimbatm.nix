{ inputs, pkgs, ... }:
{
  users.users.zimbatm = {
    uid = 1000;

    isNormalUser = true;

    extraGroups = [
      "audio"
      "docker"
      "input"
      "libvirtd"
      "networkmanager"
      "sound"
      "tty"
      "video"
      "wheel"
    ];

    packages = [
      inputs.self.packages.${pkgs.system}.myvim
    ];

    shell = "/run/current-system/sw/bin/bash";

    # Allow to SSH from any host to any host
    openssh.authorizedKeys.keyFiles = [ ../authorized_keys ];
  };
}
