{ inputs, config, lib, pkgs, ... }:
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.hardening
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
    ./disko.nix
  ];

  # Hetzner Cloud cpx22, hel1, UEFI + systemd-boot. Hosts Stalwart
  # (SMTP/IMAP/JMAP/DAV) and the MTA-STS policy vhost.
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "mail";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.useDHCP = lib.mkForce true;
  # Hetzner cloud images may name the NIC either enp1s0 or eth0 depending on
  # how cloud-init applies kernel cmdline. Match both.
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

  # Hetzner Cloud Volume 105754681 (Stalwart state) attaches at cutover.
  # nofail lets boot proceed before the volume is present.
  fileSystems."/var/lib/stalwart" = {
    device = "/dev/disk/by-id/scsi-0HC_Volume_105754681";
    fsType = "ext4";
    options = [
      "x-systemd.device-timeout=30s"
      "nofail"
    ];
  };

  users.users.zimbatm = {
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
    ];
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # --- Stalwart mail server -----------------------------------------------
  #
  # Same shape as on web2. SMTP 25/465/587 + IMAP 143/993 with TLS from the
  # ACME cert for mail.zimbatm.com (group=stalwart). Management/JMAP/DAV on
  # localhost:8485; nginx vhost at mail.zimbatm.com proxies to it.
  age.secrets.stalwart-admin-secret.file = ../../secrets/stalwart-admin-secret.age;
  age.secrets.stalwart-zimbatm-password.file = ../../secrets/stalwart-zimbatm-password.age;
  age.secrets.stalwart-jonas-password.file = ../../secrets/stalwart-jonas-password.age;

  security.acme.certs."mail.zimbatm.com".reloadServices = [ "stalwart.service" ];
  users.users.stalwart.extraGroups = [ "nginx" ];

  services.stalwart = {
    enable = true;
    openFirewall = true;
    stateVersion = "26.05";
    credentials.admin_secret = config.age.secrets.stalwart-admin-secret.path;
    settings = {
      lookup.default.hostname = "mail.zimbatm.com";

      server.listener.smtp = {
        bind = [ "[::]:25" ];
        protocol = "smtp";
      };
      server.listener.submissions = {
        bind = [ "[::]:465" ];
        protocol = "smtp";
        tls.implicit = true;
      };
      server.listener.submission = {
        bind = [ "[::]:587" ];
        protocol = "smtp";
      };
      server.listener.imap = {
        bind = [ "[::]:143" ];
        protocol = "imap";
      };
      server.listener.imaps = {
        bind = [ "[::]:993" ];
        protocol = "imap";
        tls.implicit = true;
      };
      server.listener.management = {
        bind = [ "127.0.0.1:8485" ];
        protocol = "http";
      };

      certificate.default = {
        cert = "%{file:/var/lib/acme/mail.zimbatm.com/fullchain.pem}%";
        private-key = "%{file:/var/lib/acme/mail.zimbatm.com/key.pem}%";
        default = true;
      };

      authentication.fallback-admin = {
        user = "admin";
        secret = "%{file:/run/credentials/stalwart.service/admin_secret}%";
      };
    };
  };

  services.nginx.virtualHosts."mail.zimbatm.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8485";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  # MTA-STS policy host. Moved with the mail stack — all mail-things on one
  # box. The policy declares mail.zimbatm.com as the MX; that target hostname
  # is unchanged, only its A/AAAA records will repoint to this VM.
  services.nginx.virtualHosts."mta-sts.zimbatm.com" = {
    enableACME = true;
    forceSSL = true;
    locations."= /.well-known/mta-sts.txt" = {
      extraConfig = ''
        default_type text/plain;
        return 200 "version: STSv1\nmode: testing\nmx: mail.zimbatm.com\nmax_age: 86400\n";
      '';
    };
  };

  # Offsite backups → rsync.net via restic SFTP. Separate repo from web2's
  # gotosocial backup (different password, different sub-path). The SSH key
  # can be the same rsync.net account key; we use a fresh agenix file scoped
  # to this host's recipient.
  age.secrets.mail-restic-password.file = ../../secrets/mail-restic-password.age;
  age.secrets.mail-restic-ssh-key = {
    file = ../../secrets/mail-restic-ssh-key.age;
    mode = "0400";
  };

  programs.ssh.knownHosts."zh6422.rsync.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtclizeBy1Uo3D86HpgD3LONGVH0CJ0NT+YfZlldAJd";

  services.restic.backups.stalwart = {
    paths = [ "/var/lib/stalwart" ];
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

  systemd.services."restic-backups-stalwart".serviceConfig = {
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
    ReadOnlyPaths = [ "/var/lib/stalwart" ];
    ReadWritePaths = [ "/var/cache/restic-backups-stalwart" ];
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
    CapabilityBoundingSet = "";
    UMask = "0077";
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
