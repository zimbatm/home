{ inputs, pkgs, ... }:
{
  users.users.zimbatm = {
    uid = 1000;
    description = "Jonas Chevalier";

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

    hashedPassword = "$y$j9T$qdF93ja3M6SK9Nwdh2jrD/$CVdHhL0iloYp6rj3kiDEYvxNd6sKzY2rXZiK0CBjWM.";

    packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.myvim ];

    shell = "/run/current-system/sw/bin/bash";

    # Allow to SSH from any host to any host
    openssh.authorizedKeys.keyFiles = [ ../../authorized_keys ];
  };
}
