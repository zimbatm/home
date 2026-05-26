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

  users.users.zimbatm.extraGroups = [ "wheel" ];

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
  age.secrets.pocket-id-encryption-key.file = ../../secrets/pocket-id-encryption-key.age;
  age.secrets.pocket-id-static-api-key.file = ../../secrets/pocket-id-static-api-key.age;
  age.secrets.oauth2-proxy-stalwart-cookie.file = ../../secrets/oauth2-proxy-stalwart-cookie.age;
  # nginx needs to traverse /run/agenix/ (root:keys, 0750) to reach secret files.
  users.users.nginx.extraGroups = [ "keys" ];

  security.acme.certs."mail.zimbatm.com".reloadServices = [ "stalwart.service" ];
  security.acme.certs."mail.chevalier.sh".reloadServices = [ "stalwart.service" ];
  users.users.stalwart.extraGroups = [ "nginx" ];

  services.stalwart = {
    enable = true;
    openFirewall = true;
    stateVersion = "26.05";
    credentials.admin_secret = config.age.secrets.stalwart-admin-secret.path;
    settings = {
      # Tell Stalwart which TOML key patterns are authoritative from this
      # local config file vs DB-managed. Without this, every boot logs a
      # "Database key defined in local configuration" warning for things
      # like webadmin.*, resolver.*, lookup.default.hostname,
      # spam-filter.resource — all of which the nixpkgs stalwart module
      # writes into the TOML.
      # The first block is Stalwart's stock defaults (mirrored from
      # oddlama/nix-config); the second block is our additions.
      config.local-keys = [
        "store.*"
        "directory.*"
        "tracer.*"
        "server.*"
        "!server.blocked-ip.*"
        "!server.allowed-ip.*"
        "authentication.fallback-admin.*"
        "cluster.*"
        "storage.data"
        "storage.blob"
        "storage.lookup"
        "storage.fts"
        "storage.directory"
        # nixpkgs module-managed keys we'd otherwise get warned about:
        "lookup.default.hostname"
        "certificate.*"
        "resolver.*"
        "spam-filter.resource"
        "webadmin.path"
        "webadmin.resource"
      ];

      lookup.default.hostname = "mail.zimbatm.com";

      # Attachments / message bodies as files under /var/lib/stalwart/blobs
      # instead of inside RocksDB. Smaller restic snapshots, less RocksDB
      # compaction churn. Greenfield from this point — the DB was wiped
      # and re-imapsynced from Google Workspace so we never had blobs
      # in RocksDB to migrate out of (Stalwart 0.15.5's --export/--import
      # doesn't reroute by backend; see
      # [[reference_stalwart_blob_fs_migration]]).
      store.fs = {
        type = "fs";
        path = "/var/lib/stalwart/blobs";
      };
      storage.blob = "fs";

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
      # SNI-matched cert for clients connecting via mail.chevalier.sh
      # (autoconfig steers Thunderbird / iOS here). Stalwart picks this
      # based on the ServerName/SNI without restarting SMTP/IMAP sockets.
      certificate."mail.chevalier.sh" = {
        cert = "%{file:/var/lib/acme/mail.chevalier.sh/fullchain.pem}%";
        private-key = "%{file:/var/lib/acme/mail.chevalier.sh/key.pem}%";
      };

      authentication.fallback-admin = {
        user = "admin";
        secret = "%{file:/run/credentials/stalwart.service/admin_secret}%";
      };

    };
  };

  # Pocket ID SSO gate on the Stalwart admin vhost. The oauth2-proxy
  # nginx helper (configured further down) attaches `auth_request
  # /oauth2/auth` to this vhost — the `/` location below sits behind
  # that gate. Stalwart's own admin password remains the inner
  # credential.
  #
  # Protocol endpoints (DAV / JMAP / .well-known) bypass the SSO gate:
  # those clients (Thunderbird, vdirsyncer, iOS Mail, etc.) speak HTTP
  # Basic Auth with the user's mail password — they don't follow OAuth
  # redirects. Stalwart enforces auth on these endpoints itself.
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
        client_max_body_size 100m;
      '';
    };
    locations."/dav/" = {
      proxyPass = "http://127.0.0.1:8485";
      extraConfig = ''
        auth_request off;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 100m;
      '';
    };
    locations."/jmap" = {
      proxyPass = "http://127.0.0.1:8485";
      extraConfig = ''
        auth_request off;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 100m;
      '';
    };
    locations."/.well-known/" = {
      proxyPass = "http://127.0.0.1:8485";
      extraConfig = ''
        auth_request off;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  # Declare the OIDC client in Pocket ID. The reconciler runs on this
  # host, hits the local Pocket ID API, and writes
  # /run/pocket-id-clients/stalwart-admin/{id,secret} for oauth2-proxy.
  services.pocketIdClients.clients.stalwart-admin = {
    name = "Stalwart admin (mail.zimbatm.com)";
    callbackURLs = [ "https://mail.zimbatm.com/oauth2/callback" ];
    pkceEnabled = true;
  };

  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    oidcIssuerUrl = "https://id.zimbatm.com";
    clientID = "stalwart-admin";
    clientSecretFile = "/run/pocket-id-clients/stalwart-admin/secret";
    cookie.secretFile = config.age.secrets.oauth2-proxy-stalwart-cookie.path;
    cookie.domain = ".zimbatm.com";
    cookie.refresh = "1h";
    redirectURL = "https://mail.zimbatm.com/oauth2/callback";
    email.domains = [ "*" ];
    reverseProxy = true;
    setXauthrequest = true;
    extraConfig = {
      "skip-provider-button" = true;       # single IdP, skip chooser
      "whitelist-domain" = ".zimbatm.com";
      "code-challenge-method" = "S256";    # matches pkceEnabled=true above
    };
    nginx.domain = "mail.zimbatm.com";
    nginx.virtualHosts."mail.zimbatm.com" = { };
  };
  # oauth2-proxy reads /run/pocket-id-clients/<id>/secret at startup; the
  # reconciler must have run first.
  systemd.services.oauth2-proxy = {
    after = [ "pocket-id-clients.service" ];
    requires = [ "pocket-id-clients.service" ];
    serviceConfig.SupplementaryGroups = [ "pocket-id-clients" ];
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

  # chevalier.sh infrastructure (task #72). MX is still on Fastmail; these
  # vhosts give us Stalwart-side webmail, autoconfig, and a primed MTA-STS
  # endpoint that we can switch from "testing" to "enforce" at MX cutover.

  services.nginx.virtualHosts."mail.chevalier.sh" = {
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

  services.nginx.virtualHosts."mta-sts.chevalier.sh" = {
    enableACME = true;
    forceSSL = true;
    locations."= /.well-known/mta-sts.txt" = {
      extraConfig = ''
        default_type text/plain;
        # `testing` so receivers don't enforce yet — flip to `enforce`
        # along with the MX cutover.
        return 200 "version: STSv1\nmode: testing\nmx: mail.chevalier.sh\nmax_age: 86400\n";
      '';
    };
  };

  # Thunderbird / Apple Mail / SeaMonkey autoconfig (RFC ISPDB-ish).
  services.nginx.virtualHosts."autoconfig.chevalier.sh" = {
    enableACME = true;
    forceSSL = true;
    locations."= /mail/config-v1.1.xml" = {
      extraConfig = ''
        default_type application/xml;
        return 200 '<?xml version="1.0" encoding="UTF-8"?>
<clientConfig version="1.1">
  <emailProvider id="chevalier.sh">
    <domain>chevalier.sh</domain>
    <displayName>chevalier.sh</displayName>
    <displayShortName>chevalier.sh</displayShortName>
    <incomingServer type="imap">
      <hostname>mail.chevalier.sh</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>mail.chevalier.sh</hostname>
      <port>465</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
  </emailProvider>
</clientConfig>';
      '';
    };
  };

  # Outlook / iOS autodiscover. POST-only in real Exchange; we return the
  # same XML for GET too so clients that probe both methods work.
  services.nginx.virtualHosts."autodiscover.chevalier.sh" = {
    enableACME = true;
    forceSSL = true;
    locations."= /autodiscover/autodiscover.xml" = {
      extraConfig = ''
        default_type application/xml;
        return 200 '<?xml version="1.0" encoding="utf-8"?>
<Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/responseschema/2006">
  <Response xmlns="http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a">
    <Account>
      <AccountType>email</AccountType>
      <Action>settings</Action>
      <Protocol>
        <Type>IMAP</Type>
        <Server>mail.chevalier.sh</Server>
        <Port>993</Port>
        <SSL>on</SSL>
      </Protocol>
      <Protocol>
        <Type>SMTP</Type>
        <Server>mail.chevalier.sh</Server>
        <Port>465</Port>
        <SSL>on</SSL>
      </Protocol>
    </Account>
  </Response>
</Autodiscover>';
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
    # Upstreams (notably Pocket ID) emit enough proxy headers to trip
    # the default hash; raise the bucket sizes.
    proxy_headers_hash_max_size 1024;
    proxy_headers_hash_bucket_size 128;
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

  # ─── Pocket ID — passkey OIDC IdP at id.zimbatm.com ─────────────────────
  # SSO root for everything internal. Stalwart stays as the mail/identity
  # *store*; Pocket ID issues the tokens that OAuth2-proxy-fronted services
  # accept. First-run flow: hit id.zimbatm.com, create the first admin
  # account (passkey-only), then register OAuth clients per protected app.
  services.pocket-id = {
    enable = true;
    credentials = {
      ENCRYPTION_KEY = config.age.secrets.pocket-id-encryption-key.path;
      # STATIC_API_KEY creates a "Static API User" admin Pocket ID can
      # authenticate as without a passkey — used by the declarative
      # client reconciler. Header: `X-API-Key: <value>`.
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

  # Reconcile OIDC clients into Pocket ID via its API. Individual
  # clients are declared next to the services they front (search for
  # `services.pocketIdClients.clients.<id>` in this file).
  services.pocketIdClients = {
    apiBaseUrl = "https://id.zimbatm.com/api";
    apiKeyFile = config.age.secrets.pocket-id-static-api-key.path;
  };

  services.nginx.virtualHosts."id.zimbatm.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      # Use `localhost` (hostname) not `127.0.0.1` (IP literal). nginx
      # treats them differently for connection pooling / HTTP version
      # negotiation; the IP literal path triggered a 400 from
      # pocket-id-via-nginx that working configs (linyinfeng, kurnevsky)
      # don't hit when proxying to localhost.
      proxyPass = "http://localhost:1411";
      extraConfig = ''
        # Buffer bumps per pocket-id upstream docs — its response
        # headers (long CSP) overflow nginx's default 4k buffer.
        proxy_buffer_size 256k;
        proxy_buffers 4 512k;
        proxy_busy_buffers_size 512k;
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
  age.secrets.hc-ping-stalwart.file = ../../secrets/hc-ping-stalwart.age;
  services.hcPing.units."restic-backups-stalwart".secret = config.age.secrets.hc-ping-stalwart.path;

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
