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

  # MTA-STS policy host (RFC 8461). The policy declares mail.zimbatm.com as
  # the MX; receivers fetch this and remember it for max_age.
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

  # Snappymail webmail at mail.ztm.io (internal-facing — ztm.io domain).
  # Talks to Stalwart over localhost IMAP/SMTP. Nixpkgs has the package but
  # no module, so wire php-fpm + nginx manually. The package hard-codes
  # APP_DATA_FOLDER_PATH=/var/lib/snappymail/ in include.php — keep it there.
  users.users.snappymail = {
    isSystemUser = true;
    group = "snappymail";
  };
  users.groups.snappymail = { };
  systemd.tmpfiles.rules = [
    "d /var/lib/snappymail 0750 snappymail snappymail -"
  ];

  services.phpfpm.pools.snappymail = {
    user = "snappymail";
    group = "snappymail";
    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "pm" = "dynamic";
      "pm.max_children" = 10;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
      "php_admin_value[error_log]" = "stderr";
      "php_admin_flag[log_errors]" = true;
      "catch_workers_output" = true;
      # Capture a stack trace any time a request blocks > 200ms — surfaces
      # where the time actually goes (bcrypt, IMAP, etc.).
      "request_slowlog_timeout" = "200ms";
      "slowlog" = "/var/log/phpfpm-snappymail-slow.log";
    };
    phpEnv.PATH = lib.makeBinPath [ pkgs.coreutils ];
    # Big perf win: opcache caches compiled PHP across requests. Without it
    # every page recompiles ~50 MB of source. Realpath cache helps Snappymail's
    # filesystem-heavy include patterns.
    phpOptions = ''
      opcache.enable=1
      opcache.enable_cli=1
      opcache.memory_consumption=128
      opcache.interned_strings_buffer=16
      opcache.max_accelerated_files=10000
      opcache.revalidate_freq=2
      opcache.fast_shutdown=1
      realpath_cache_size=4096K
      realpath_cache_ttl=600
    '';
  };

  services.nginx.commonHttpConfig = ''
    log_format snappymail_timing '$remote_addr "$request" '
                                 'status=$status size=$body_bytes_sent '
                                 'request_time=$request_time upstream_time=$upstream_response_time '
                                 'ua="$http_user_agent"';
  '';

  services.nginx.virtualHosts."mail.ztm.io" = {
    enableACME = true;
    forceSSL = true;
    root = "${pkgs.snappymail}";
    extraConfig = ''
      access_log syslog:server=unix:/dev/log snappymail_timing;
    '';
    locations."/" = {
      index = "index.php";
      tryFiles = "$uri $uri/ /index.php$is_args$args";
    };
    locations."~ \\.php$".extraConfig = ''
      include ${pkgs.nginx}/conf/fastcgi_params;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      fastcgi_param PATH_INFO $fastcgi_path_info;
      fastcgi_pass unix:${config.services.phpfpm.pools.snappymail.socket};
    '';
    locations."~ ^/(data|.git)".extraConfig = ''
      deny all;
    '';
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
    # restic runs as root but Stalwart's /var/lib/stalwart/db is mode 0700
    # owned by the stalwart user. Without CAP_DAC_READ_SEARCH the root
    # process can't traverse it (DAC mode check still applies); restic
    # then logs "permission denied" and saves an empty snapshot.
    CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
    AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
    UMask = "0077";
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
