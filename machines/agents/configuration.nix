{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.hardening
    inputs.self.nixosModules.pocket-id-clients
    inputs.self.nixosModules.tinc-ztm
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
    inputs.subportal.nixosModules.subportal
    inputs.nix-index-database.nixosModules.nix-index
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
    ./disko.nix
  ];

  programs.nix-index-database.comma.enable = true;

  # Hetzner Cloud cpx62 (16 vCPU AMD shared, 32 GB, 640 GB), fsn1.
  # Workstation for long-running Claude Code agent sessions. SSH in, attach
  # to tmux/dtach, run multiple agents in parallel. Not a public service —
  # only port 22 open.
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "agents";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.useDHCP = lib.mkForce true;
  systemd.network.networks."05-eth" = {
    matchConfig.Name = "enp1s0 eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    address = [ "2a01:4f8:c014:7e84::1/64" ];
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
  };

  users.users.zimbatm.extraGroups = [ "wheel" ];

  # zimbatm can build via nix without sudo (trusted by the daemon).
  nix.settings.trusted-users = [ "@wheel" ];

  environment.systemPackages =
    let
      llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    in
    (with pkgs; [
      git
      gh
      jujutsu
      direnv
      nix-direnv
      fish
      htop
      iotop
      tmux
      dtach
      ripgrep
      fd
      jq
      nodejs_22 # for claude-code's npm-distributed wrapper, if used outside the nix path
    ]) ++ [
      llm.claude-code
      llm.happy-coder # `happy` — mobile/web client (app.happy.engineering),
                      # E2E-encrypted, sessions still run locally on agents.
    ];

  # SSH login (or ttyd-spawned bash) auto-attaches to a tmux session
  # named `main`. tmux persists across detach, so a ttyd reconnect (after
  # an oauth2-proxy auth refresh, browser tab close, etc.) reattaches to
  # the same panes instead of starting a fresh bash. Detach: Ctrl-b d.
  # Opt out: `NO_TMUX=1 ssh agents.ztm.io`.
  # DISPLAY=:1 is a fake to make claude-code believe a clipboard is present;
  # /etc/term-paste/xclip is the shim that returns the latest image written
  # by clip-bridge.py instead of talking to a real X server.
  programs.bash.interactiveShellInit = ''
    export DISPLAY=:1
    export PATH=/etc/term-paste:$PATH
    if [[ -z "$TMUX" && ( -n "$SSH_TTY" || -n "$TTYD" ) && $- == *i* && -z "$NO_TMUX" ]]; then
      exec ${pkgs.tmux}/bin/tmux new-session -A -s main
    fi
  '';

  # Install fake-xclip as /etc/term-paste/xclip so it shadows the real one
  # only inside the agents shells that prepend /etc/term-paste to PATH.
  environment.etc."term-paste/xclip" = {
    source = ./fake-xclip;
    mode = "0755";
  };

  # SSH + nginx (LE-terminated web terminal at 443, ACME HTTP-01 on 80).
  # Previously mTLS-gated with our own term CA; now SSO via Pocket ID
  # through oauth2-proxy. No per-device cert provisioning, single login.
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  age.secrets.pocket-id-static-api-key.file = ../../secrets/pocket-id-static-api-key.age;
  age.secrets.oauth2-proxy-agents-cookie.file = ../../secrets/oauth2-proxy-agents-cookie.age;
  # nginx needs to traverse /run/agenix/ (root:keys, 0750) to reach secret files.
  users.users.nginx.extraGroups = [ "keys" ];

  # Register the OIDC client in Pocket ID (mail.zimbatm.com). The reconciler
  # runs locally here, talks to id.zimbatm.com via the API key, and writes
  # /run/pocket-id-clients/agents-ttyd/{id,secret} for oauth2-proxy to read.
  services.pocketIdClients = {
    apiBaseUrl = "https://id.zimbatm.com/api";
    apiKeyFile = config.age.secrets.pocket-id-static-api-key.path;
    clients.agents-ttyd = {
      name = "agents.ztm.io terminal";
      callbackURLs = [ "https://agents.ztm.io/oauth2/callback" ];
      pkceEnabled = true;
    };
  };

  # oauth2-proxy: nginx auth_request → here → Pocket ID OIDC.
  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    oidcIssuerUrl = "https://id.zimbatm.com";
    # client_id is also the slug we used in pocketIdClients; client_secret
    # is the one the reconciler generated and stored at /run/pocket-id-clients/.
    clientID = "agents-ttyd";
    clientSecretFile = "/run/pocket-id-clients/agents-ttyd/secret";
    cookie.secretFile = config.age.secrets.oauth2-proxy-agents-cookie.path;
    cookie.domain = ".ztm.io";  # share session across future *.ztm.io SSO targets
    cookie.refresh = "1h";
    redirectURL = "https://agents.ztm.io/oauth2/callback";
    email.domains = [ "*" ];
    reverseProxy = true;
    setXauthrequest = true;
    extraConfig = {
      "skip-provider-button" = true;   # single-IdP setup, skip the chooser
      "whitelist-domain" = ".ztm.io";
      # Pocket ID's client config has pkceEnabled = true, so the token
      # exchange fails with "Invalid code verifier" unless oauth2-proxy
      # actually sends the PKCE challenge. S256 is the modern method.
      "code-challenge-method" = "S256";
    };
    nginx.domain = "agents.ztm.io";
    nginx.virtualHosts."agents.ztm.io" = { };
  };
  # oauth2-proxy starts before pocket-id-clients has run; depend on it so
  # the client_secret file exists when oauth2-proxy reads it.
  systemd.services.oauth2-proxy = {
    after = [ "pocket-id-clients.service" ];
    requires = [ "pocket-id-clients.service" ];
    serviceConfig.SupplementaryGroups = [ "pocket-id-clients" ];
  };

  # ttyd: PTY-over-WebSocket on loopback; nginx terminates TLS + Pocket ID
  # SSO before proxying. Runs as zimbatm so the shell isn't root. The
  # entrypoint sets TTYD=1 so interactiveShellInit's tmux auto-attach
  # fires (the usual trigger is SSH_TTY, which ttyd doesn't set).
  # Image-paste end-to-end relies on xterm.js's ImageAddon parsing iTerm2
  # OSC 1337 in the browser.
  services.ttyd = {
    enable = true;
    user = "zimbatm";
    interface = "127.0.0.1";
    port = 7681;
    writeable = true;  # (sic — option name has a typo upstream)
    entrypoint = [
      (toString (pkgs.writeShellScript "ttyd-shell" ''
        export TTYD=1
        exec ${pkgs.bash}/bin/bash -l
      ''))
    ];
    clientOptions = {
      fontSize = "16";
      fontFamily = "monospace";
    };
  };

  services.nginx.virtualHosts."agents.ztm.io" = {
    enableACME = true;
    forceSSL = true;
    # services.oauth2-proxy.nginx.virtualHosts attaches `auth_request
    # /oauth2/auth` + the /oauth2/* locations to this vhost. The
    # locations below sit BEHIND that gate; oauth2-proxy lets the
    # request through only after the user has a valid Pocket ID
    # session.
    locations."/" = {
      proxyPass = "http://127.0.0.1:7681";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
        # Inject the clipboard shim into ttyd's served HTML; sub_filter
        # operates on responses so forbid compression for text/html.
        sub_filter_once on;
        sub_filter_types text/html;
        sub_filter '</head>' '<script src="/clip-shim.js" defer></script></head>';
        proxy_set_header Accept-Encoding "";
      '';
    };
    locations."= /clip-shim.js" = {
      alias = "${./clip-shim.js}";
      extraConfig = ''
        types { } default_type application/javascript;
        add_header Cache-Control "no-cache";
      '';
    };
    locations."= /clip" = {
      proxyPass = "http://127.0.0.1:8090/clip";
      extraConfig = ''
        client_max_body_size 25m;
        proxy_request_buffering off;
      '';
    };
  };

  # Sidecar that receives image blobs from the browser and writes them to
  # /tmp/clip-latest.<ext>. The fake-xclip shim on PATH reads from there.
  # No real X server involved — xclip's daemonization is too fragile under
  # systemd to rely on for one-shot clipboard writes.
  systemd.services.clip-bridge = {
    description = "Browser→/tmp image paste bridge for the web terminal";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./clip-bridge.py}";
      Restart = "always";
      User = "zimbatm";
    };
  };

  # subportal: agent-side forwarder for xdg-open / notify-send / file
  # transfer to nv1 over iroh p2p. Enroll once with:
  #   ssh root@agents.ztm.io subportal ticket | subportal-desktop enroll
  programs.subportal.enable = true;
  programs.subportal.agent.enable = true;
  # systemd user manager needs to stick around across SSH disconnects.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/root 0644 root root - -"
  ];
  # Iroh needs AF_NETLINK for netmon (interface watching).
  systemd.user.services.subportal-agent.serviceConfig.RestrictAddressFamilies = [
    "AF_INET"
    "AF_INET6"
    "AF_UNIX"
    "AF_NETLINK"
  ];

  # Offsite backups → rsync.net via restic SFTP. Mirrors the web2 pattern.
  # Targets /home/zimbatm where every long-running Claude Code conversation,
  # tmux scrollback, and scratch git tree lives — a VM-die wipes them
  # otherwise. Excludes cache/build directories that bloat the repo without
  # carrying anything we'd want back.
  age.secrets.agents-restic-password.file = ../../secrets/agents-restic-password.age;
  age.secrets.agents-restic-ssh-key = {
    file = ../../secrets/agents-restic-ssh-key.age;
    mode = "0400";
  };

  programs.ssh.knownHosts."zh6422.rsync.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtclizeBy1Uo3D86HpgD3LONGVH0CJ0NT+YfZlldAJd";

  services.restic.backups.agents = {
    paths = [ "/home/zimbatm" ];
    exclude = [
      "/home/zimbatm/.cache"
      "/home/zimbatm/.local/share/Trash"
      "/home/zimbatm/go/pkg"
      "/home/zimbatm/**/node_modules"
      "/home/zimbatm/**/target"
      "/home/zimbatm/**/.direnv"
    ];
    repository = "sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/agents";
    passwordFile = config.age.secrets.agents-restic-password.path;
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
      "sftp.command='ssh -i ${config.age.secrets.agents-restic-ssh-key.path} -o StrictHostKeyChecking=yes zh6422@zh6422.rsync.net -s sftp'"
    ];
    initialize = true;
  };

  # Restic jail. ProtectHome="read-only" instead of true since /home/zimbatm
  # IS the backup source — `true` would hide it entirely.
  systemd.services."restic-backups-agents".serviceConfig = {
    NoNewPrivileges = true;
    LockPersonality = true;
    PrivateDevices = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = "read-only";
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    ReadWritePaths = [ "/var/cache/restic-backups-agents" ];
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
    CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
    AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
    UMask = "0077";
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
