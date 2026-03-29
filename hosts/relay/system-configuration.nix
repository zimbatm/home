{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  config = {
    nixpkgs.hostPlatform = "x86_64-linux";

    environment.systemPackages = [
      pkgs.ghostty.terminfo
    ];

    nix.settings = {
      experimental-features = lib.mkDefault [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.nixos.org/"
        "https://cache.numtide.com/"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };

    # Enable userborn for user management
    services.userborn.enable = true;

    # User configuration
    users.users.zimbatm = {
      isNormalUser = true;
      description = "zimbatm";
      extraGroups = [ "wheel" ];
    };

    users.groups.wheel.gid = lib.mkForce 900;

    # SSH authorized keys for zimbatm
    environment.etc."ssh/authorized_keys.d/zimbatm".text = ''
      sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo=
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJknrTtm4KUY41ooh/sgtH6tTWAJeZzumI6us59fEWc9
    '';

    # Configure sshd to look up keys from /etc/ssh/authorized_keys.d/
    environment.etc."ssh/sshd_config.d/authorized_keys.conf".text = ''
      StrictModes no
      AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
    '';

    # Allow wheel group to use sudo without password
    environment.etc."sudoers.d/wheel".text = ''
      %wheel ALL=(ALL:ALL) NOPASSWD: ALL
    '';

    # iroh-relay config
    environment.etc."iroh-relay/iroh-relay.toml".text = ''
      enable_relay = true
      enable_quic_addr_discovery = true

      [tls]
      cert_mode = "LetsEncrypt"
      contact = "zimbatm@zimbatm.com"
      hostname = "relay.ztm.io"
      cert_dir = "/var/lib/iroh-relay/certs"
    '';

    # iroh-relay service
    systemd.services.iroh-relay = {
      enable = true;
      description = "iroh relay server";
      wantedBy = [ "system-manager.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${inputs.self.packages.x86_64-linux.iroh-relay}/bin/iroh-relay --config-path /etc/iroh-relay/iroh-relay.toml";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "iroh-relay";
        # Needs to bind to ports 80 and 443
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
        DynamicUser = true;
      };
    };
  };
}
