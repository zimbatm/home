{ inputs, config, lib, pkgs, ... }:
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.gotosocial
    inputs.self.nixosModules.hardening
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
    ./disko.nix
  ];

  # Hetzner Cloud cx23, hel1, BIOS GRUB. Re-provisioned via nixos-anywhere
  # from this config. Public-IP host serving gts.zimbatm.com today; Stalwart
  # for zimbatm.com mail coming next.
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "web2";

  # srvos hardware-hetzner-cloud sets boot.loader.grub.devices via mkDefault
  # but leaves enable off; flip it.
  boot.loader.grub.enable = true;

  # And forces useDHCP=false expecting cloud-init network config — bypass
  # with straight DHCP on the primary interface, then bind the static IPv6.
  networking.useDHCP = lib.mkForce true;
  systemd.network.networks."05-enp1s0" = {
    matchConfig.Name = "enp1s0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    address = [ "2a01:4f9:c014:fac3::1/64" ];
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
  };

  # Hetzner Cloud Volumes attached to web2:
  #   web2-gts   = scsi-0HC_Volume_105754691 → gotosocial state (5.6GB sqlite)
  #   web2-mail  = scsi-0HC_Volume_105754681 → Stalwart (mail)
  # nofail so a missing volume doesn't block boot. Disko intentionally only
  # touches /dev/sda — leaves the volumes alone.
  fileSystems."/var/lib/gotosocial" = {
    device = "/dev/disk/by-id/scsi-0HC_Volume_105754691";
    fsType = "ext4";
    options = [
      "x-systemd.device-timeout=30s"
      "nofail"
    ];
  };
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

  # zimbatm.com static site (built from github:zimbatm/kit, data/views/zimbatm.com).
  # Was hosted on kit's "core" host; moved here so kit becomes purely a content
  # repo and web2 is the public face.
  services.nginx.virtualHosts."zimbatm.com" = {
    root = inputs.kit.packages.x86_64-linux.zimbatm-com;
    enableACME = true;
    forceSSL = true;
    locations."/".tryFiles = "$uri $uri/ =404";
    # Nostr NIP-05 identity verification needs CORS.
    locations."/.well-known/nostr.json".extraConfig = ''
      add_header Access-Control-Allow-Origin "*";
    '';
  };
  services.nginx.virtualHosts."www.zimbatm.com" = {
    enableACME = true;
    forceSSL = true;
    globalRedirect = "zimbatm.com";
  };

  # --- Stalwart mail server -----------------------------------------------
  #
  # Listens directly on 25/465/587 (SMTP) and 143/993 (IMAP) with TLS from
  # the ACME-issued mail.zimbatm.com cert (group=stalwart so the service can
  # read /var/lib/acme/mail.zimbatm.com/{key,fullchain}.pem). Web admin runs
  # on localhost:8080; nginx vhost at mail.zimbatm.com proxies to it.
  #
  # Bootstrap: after first deploy + DNS, visit https://mail.zimbatm.com/admin
  # and log in as user `admin` with the password in
  # /run/credentials/stalwart.service/admin_secret (i.e. the decrypted agenix
  # secret). Create the zimbatm.com domain + your mailbox via the web UI.

  age.secrets.stalwart-admin-secret.file = ../../secrets/stalwart-admin-secret.age;

  # One-shot imapsync migration from Google Workspace → Stalwart.
  # `agenix -e secrets/workspace-zimbatm-app-password.age` to paste the
  # Workspace app password (https://myaccount.google.com/apppasswords).
  # Then on web2:
  #   sudo -E env \
  #     SRC_PW=$(cat /run/agenix/workspace-zimbatm-app-password) \
  #     DST_PW=$(cat /run/agenix/stalwart-zimbatm-password) \
  #     imapsync \
  #       --host1 imap.gmail.com --user1 zimbatm@zimbatm.com --password1 "$SRC_PW" --ssl1 \
  #       --host2 localhost --user2 zimbatm@zimbatm.com --password2 "$DST_PW" --ssl2 \
  #       --sslargs2 SSL_verify_mode=0 \
  #       --automap --addheader
  age.secrets.stalwart-zimbatm-password.file = ../../secrets/stalwart-zimbatm-password.age;
  age.secrets.workspace-zimbatm-app-password.file = ../../secrets/workspace-zimbatm-app-password.age;
  environment.systemPackages = [ pkgs.imapsync ];

  # nginx's enableACME puts the cert in group=nginx (chown acme:nginx). Add
  # stalwart to nginx group so it can read fullchain.pem / key.pem for its
  # own SMTP/IMAP TLS listeners.
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
      # gotosocial owns 8080; pick a different localhost port for the admin/JMAP/DAV listener.
      server.listener.management = {
        bind = [ "127.0.0.1:8485" ];
        protocol = "http";
      };

      # TLS from Let's Encrypt
      certificate.default = {
        cert = "%{file:/var/lib/acme/mail.zimbatm.com/fullchain.pem}%";
        private-key = "%{file:/var/lib/acme/mail.zimbatm.com/key.pem}%";
        default = true;
      };

      # First-login admin. Use the webadmin to create real users + the
      # zimbatm.com domain, then disable this entry (set authentication
      # fallback-admin.enable=false in a future deploy).
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

  # MTA-STS policy host. RFC 8461: receiving MTAs fetch
  # https://mta-sts.zimbatm.com/.well-known/mta-sts.txt and enforce the
  # policy. `mode: testing` initially — receivers log STS-failures without
  # bouncing; upgrade to `enforce` once we've confirmed clean reports.
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

  # Offsite backups → rsync.net via restic SFTP. Same pattern kin-infra used
  # before. SSH key + restic password live in agenix; the SSH key is a
  # placeholder until you run `agenix -e secrets/web2-restic-ssh-key.age`
  # with the rsync.net ed25519 private key body.
  age.secrets.web2-restic-password.file = ../../secrets/web2-restic-password.age;
  age.secrets.web2-restic-ssh-key = {
    file = ../../secrets/web2-restic-ssh-key.age;
    mode = "0400";
  };

  programs.ssh.knownHosts."zh6422.rsync.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtclizeBy1Uo3D86HpgD3LONGVH0CJ0NT+YfZlldAJd";

  services.restic.backups =
    let
      common = service: {
        repository = "sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/${service}";
        passwordFile = config.age.secrets.web2-restic-password.path;
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
          "sftp.command='ssh -i ${config.age.secrets.web2-restic-ssh-key.path} -o StrictHostKeyChecking=yes zh6422@zh6422.rsync.net -s sftp'"
        ];
        initialize = true;
      };
    in
    {
      gotosocial = common "gotosocial" // {
        paths = [ "/var/lib/gotosocial" ];
      };
      stalwart = common "stalwart" // {
        paths = [ "/var/lib/stalwart" ];
      };
    };

  # ---------------------------------------------------------------------------
  # Per-service systemd sandbox overrides. nixpkgs ships these with minimal
  # hardening; the common Protect* / Restrict* set drops the blast radius if
  # any one of these gets popped.
  # ---------------------------------------------------------------------------

  # gotosocial: nixpkgs sets ProtectSystem=full + a couple Protect*. Tighten
  # to ProtectSystem=strict with an explicit ReadWritePath, plus the rest of
  # the standard set.
  systemd.services.gotosocial.serviceConfig = {
    ProtectSystem = lib.mkForce "strict";
    ReadWritePaths = [ "/var/lib/gotosocial" ];
    ProtectClock = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectProc = "invisible";
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

  # restic backup jails. User stays root (needs read on /var/lib/{service}),
  # but everything else clamps. ReadOnlyPaths covers what restic touches.
  systemd.services."restic-backups-gotosocial".serviceConfig = {
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
    ReadOnlyPaths = [ "/var/lib/gotosocial" ];
    ReadWritePaths = [ "/var/cache/restic-backups-gotosocial" ];
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
