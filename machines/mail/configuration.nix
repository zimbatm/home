{ inputs, config, lib, pkgs, ... }:
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.hardening
    inputs.self.nixosModules.hc-ping
    inputs.self.nixosModules.pocket-id-clients
    inputs.self.nixosModules.tinc-ztm
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
    ./disko.nix
  ];

  # Hetzner Cloud cpx22, hel1, UEFI + systemd-boot. Used to host Stalwart;
  # mail moved back to Fastmail on 2026-05-26 and this VM now exists only
  # for Pocket ID at id.zimbatm.com (passkey OIDC IdP for agents.ztm.io
  # and any future SSO targets).
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "mail";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.useDHCP = lib.mkForce true;
  systemd.network.networks."05-eth" = {
    matchConfig.Name = "enp1s0 eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    address = [ "2a01:4f9:c015:5dc::1/64" ];
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
  };

  users.users.zimbatm.extraGroups = [ "wheel" ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # ─── Pocket ID — passkey OIDC IdP at id.zimbatm.com ─────────────────────
  age.secrets.pocket-id-encryption-key.file = ../../secrets/pocket-id-encryption-key.age;
  age.secrets.pocket-id-static-api-key.file = ../../secrets/pocket-id-static-api-key.age;

  services.pocket-id = {
    enable = true;
    credentials = {
      ENCRYPTION_KEY = config.age.secrets.pocket-id-encryption-key.path;
      STATIC_API_KEY = config.age.secrets.pocket-id-static-api-key.path;
    };
    settings = {
      APP_URL = "https://id.zimbatm.com";
      TRUST_PROXY = true;
      # `::` is Go's dual-stack listen — accepts both 127.0.0.1 and ::1.
      # glibc's getaddrinfo returns IPv6 first for "localhost", so nginx's
      # upstream lookup intermittently picked ::1 and got ECONNREFUSED when
      # we bound only 127.0.0.1. Port 1411 is firewalled, so this is still
      # loopback-only in practice.
      HOST = "::";
      PORT = 1411;
      ANALYTICS_DISABLED = true;
    };
  };

  # Reconcile OIDC clients into Pocket ID via its API. Individual clients
  # are declared next to the services they front (agents/configuration.nix).
  services.pocketIdClients = {
    apiBaseUrl = "https://id.zimbatm.com/api";
    apiKeyFile = config.age.secrets.pocket-id-static-api-key.path;
  };

  services.nginx.virtualHosts."id.zimbatm.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      # `localhost` (hostname) not `127.0.0.1` (IP literal). nginx treats
      # them differently for connection pooling / HTTP version negotiation;
      # the IP literal path triggered 400s from pocket-id.
      proxyPass = "http://localhost:1411";
      extraConfig = ''
        # Pocket ID's response headers (long CSP) overflow nginx's default
        # 4k buffer — bump per upstream docs.
        proxy_buffer_size 256k;
        proxy_buffers 4 512k;
        proxy_busy_buffers_size 512k;
      '';
    };
  };

  # ─── Backups: Pocket ID DB → rsync.net via restic SFTP ──────────────────
  age.secrets.mail-restic-password.file = ../../secrets/mail-restic-password.age;
  age.secrets.mail-restic-ssh-key = {
    file = ../../secrets/mail-restic-ssh-key.age;
    mode = "0400";
  };

  programs.ssh.knownHosts."zh6422.rsync.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtclizeBy1Uo3D86HpgD3LONGVH0CJ0NT+YfZlldAJd";

  services.restic.backups.pocket-id = {
    paths = [ "/var/lib/pocket-id" ];
    repository = "sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/mail";
    passwordFile = config.age.secrets.mail-restic-password.path;
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
    extraOptions = [
      "sftp.command='ssh -i ${config.age.secrets.mail-restic-ssh-key.path} -o StrictHostKeyChecking=yes zh6422@zh6422.rsync.net -s sftp'"
    ];
    initialize = true;
  };

  systemd.services."restic-backups-pocket-id".serviceConfig = {
    NoNewPrivileges = true;
    LockPersonality = true;
    PrivateDevices = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    ReadOnlyPaths = [ "/var/lib/pocket-id" ];
    ReadWritePaths = [ "/var/cache/restic-backups-pocket-id" ];
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
    ];
    UMask = "0077";
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
