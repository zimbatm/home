{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  # weechat-matrix (poljar/weechat-matrix 0.3.0 in nixpkgs) still depends on
  # `future`, which is marked unsupported for python>=3.13. Pin the entire
  # weechat stack to python3.12 so the scripts build and load.
  py = pkgs.python312Packages;

  weechatUnwrapped = pkgs.weechat-unwrapped.override {
    python3Packages = py;
  };

  weechatScripts = pkgs.weechatScripts.override {
    python3Packages = py;
  };

  wrapWeechat = pkgs.wrapWeechat.override {
    python3Packages = py;
  };

  weechat = wrapWeechat weechatUnwrapped {
    configure =
      { availablePlugins, ... }:
      {
        plugins = [
          availablePlugins.python
          availablePlugins.perl
        ];
        scripts = with weechatScripts; [
          wee-slack
          weechat-matrix
        ];
      };
  };
in
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.agent-deploy
    inputs.self.nixosModules.hardening
    inputs.self.nixosModules.hc-ping
    inputs.self.nixosModules.tinc-ztm
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.disko.nixosModules.disko
    inputs.subportal.nixosModules.subportal
    # agenix: previously injected by the flake's per-machine module list; now
    # that clan auto-imports only this file, import it here directly.
    inputs.agenix.nixosModules.default
    ./disko.nix
  ];

  # Migrated agenix -> clan vars. The existing healthchecks.io ping URL is
  # imported (not regenerated) via `clan vars generate chat`; deployed by
  # sops-nix to /run/secrets/vars/hc-ping-weechat/url.
  clan.core.vars.generators.hc-ping-weechat = {
    files.url.secret = true;
    prompts.url = {
      description = "healthchecks.io ping URL for restic-backups-weechat (chat)";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''cat "$prompts"/url > "$out"/url'';
  };
  services.hcPing.units."restic-backups-weechat".secret =
    config.clan.core.vars.generators.hc-ping-weechat.files.url.path;

  # Hetzner Cloud cx23 (Intel x86, 2c/4GB/40GB, BIOS), fsn1.
  # Long-running weechat-headless under systemd; clients (Lith, Glowing Bear,
  # Weechat-Android, another weechat) connect via the relay protocol.
  nixpkgs.hostPlatform = "x86_64-linux";
  # matrix-nio[olm] -> olm-3.2.16; olm is deprecated (replaced by vodozemac)
  # and marked insecure in nixpkgs. Standard signoff for personal use.
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  networking.hostName = "chat";

  # srvos hetzner-cloud sets boot.loader.grub.devices via mkDefault but leaves
  # the master enable off, so the bootloader never gets installed. Flip it.
  boot.loader.grub.enable = true;

  # srvos hetzner-cloud disables DHCP, expecting cloud-init to write static
  # config from a metadata source. That only works if the datasource is
  # reachable, which it isn't until *some* network is up. Let networkd just
  # DHCP on the primary interface — Hetzner Cloud's DHCP is fine for this.
  networking.useDHCP = lib.mkForce true;

  # Bind a static IPv6 from Hetzner's assigned /64. Cloud-init's generated
  # network file (10-cloud-init-enp1s0.network) only does DHCPv4, so we add
  # our own file with a lower numeric prefix so networkd picks it first.
  # Hetzner Cloud's IPv6 gateway is always fe80::1 (link-local on-link).
  systemd.network.networks."05-enp1s0" = {
    matchConfig.Name = "enp1s0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    address = [
      "2a01:4f8:c014:94be::1/64"
    ];
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
  };

  # weechat under dtach (not services.weechat / weechat-headless). dtach -N
  # keeps a master process alive 24/7 so the relay stays up for mobile
  # clients (Lith, weechat-android). SSH-in attaches via `dtach -a` from the
  # bash login hook below. Detach with Ctrl-\.
  environment.systemPackages = [
    weechat
    pkgs.dtach
  ];

  systemd.services.weechat = {
    description = "weechat in a dtach session (shared, attach via bash login hook)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # weechat is curses-based even via dtach — without TERM it can't init the
    # ncurses backend and exits status=1 immediately.
    environment.TERM = "xterm-256color";
    serviceConfig = {
      Type = "simple";
      User = "weechat";
      Group = "weechat";
      # 0007 → group-rw on the dtach socket so zimbatm (in weechat group) can attach.
      UMask = "0007";
      WorkingDirectory = "/var/lib/weechat";
      ExecStart = "${pkgs.dtach}/bin/dtach -N /var/lib/weechat/dtach.sock -r winch ${weechat}/bin/weechat --dir /var/lib/weechat";
      # dtach hardcodes 0600 on the socket regardless of umask. Loop a tiny
      # wait + chmod 0660 so zimbatm (in weechat group) can attach.
      ExecStartPost = "${pkgs.bash}/bin/bash -c 'for i in 1 2 3 4 5; do [ -S /var/lib/weechat/dtach.sock ] && exec ${pkgs.coreutils}/bin/chmod 0660 /var/lib/weechat/dtach.sock; sleep 0.2; done; exit 1'";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  users.groups.weechat = { };
  users.users.weechat = {
    isSystemUser = true;
    group = "weechat";
    home = "/var/lib/weechat";
    createHome = true;
  };

  programs.bash.loginShellInit = ''
    # Auto-attach to the shared weechat dtach session. Strict gates so a
    # plain `ssh chat <cmd>` or `ssh -t chat <cmd>` still runs the command
    # instead of being trapped in weechat:
    #   - interactive shell only ($- contains 'i')
    #   - SSH-launched ($SSH_TTY set)
    #   - user is zimbatm
    #   - re-entry guard via $WEECHAT_INSIDE
    #   - socket exists (service up). If down, drop to bash, don't kill SSH.
    if [[ $- == *i* ]] \
       && [ -n "''${SSH_TTY:-}" ] \
       && [ "$LOGNAME" = "zimbatm" ] \
       && [ -z "''${WEECHAT_INSIDE:-}" ] \
       && [ -S /var/lib/weechat/dtach.sock ]; then
      export WEECHAT_INSIDE=1
      exec ${pkgs.dtach}/bin/dtach -a /var/lib/weechat/dtach.sock
    fi
  '';

  # subportal server-side: provides xdg-open / notify-send drop-ins that
  # forward to enrolled desktops (nv1) over iroh p2p. Enroll once with:
  #   ssh root@chat subportal ticket | subportal-desktop enroll
  programs.subportal.enable = true;
  programs.subportal.agent.enable = true;
  # subportal-agent is a systemd USER service. On a headless server the user
  # manager only runs at login unless we enable lingering — pin it for root
  # so the agent stays up across SSH disconnects and reboots.
  systemd.tmpfiles.rules = [
    # subportal-agent linger (see programs.subportal block above).
    "f /var/lib/systemd/linger/root 0644 root root - -"
    # weechat state dir — needs to exist with the right ownership before the
    # dtach service starts. UMask in the unit picks up from here.
    "d /var/lib/weechat 0750 weechat weechat -"
  ];

  # zimbatm can read/edit the weechat state dir for first-time relay setup
  # (`sudo systemctl stop weechat && weechat-headless --dir /var/lib/weechat`
  # to attach via a one-shot session, then `/relay add ...; /save; /quit`).
  users.users.zimbatm.extraGroups = [
    "wheel"
    "weechat"
  ];

  # ACME on 80 (HTTP-01), TLS relay on 9443. Port 9001 (plain TCP relay)
  # used to be open; closed once 9443 came up — no point shipping passwords
  # in cleartext when we have a valid cert.
  networking.firewall.allowedTCPPorts = [
    80
    9443
  ];

  # Let's Encrypt cert for the weechat relay. HTTP-01 standalone challenge —
  # no nginx needed for this single-purpose box. The post-renewal hook builds
  # the combined PEM weechat wants (`relay.network.ssl_cert_key` is a single
  # file with cert+key concatenated).
  security.acme.certs."chat.ztm.io" = {
    listenHTTP = ":80";
    group = "weechat";
    postRun = ''
      install -m 0640 -o weechat -g weechat /dev/null /var/lib/weechat/relay.pem
      cat fullchain.pem key.pem > /var/lib/weechat/relay.pem
    '';
    reloadServices = [ "weechat.service" ];
  };

  # Local Matrix homeserver + bridges (synapse + mautrix-signal + mautrix-
  # telegram) were here previously. Removed for now — using @jonas:numtide.com
  # as a remote HS via weechat-matrix. Agenix scaffolding is kept (cheap) so
  # the bridges can come back later without re-bootstrapping.

  # Offsite backups for the weechat state. Same rsync.net pattern as web2.
  # Run `agenix -e secrets/chat-restic-ssh-key.age` to paste the rsync.net
  # ed25519 private key body — until then the daily timer will fail.
  age.secrets.chat-restic-password.file = ../../secrets/chat-restic-password.age;
  age.secrets.chat-restic-ssh-key = {
    file = ../../secrets/chat-restic-ssh-key.age;
    mode = "0400";
  };
  age.secrets.matrix-numtide-password = {
    file = ../../secrets/matrix-numtide-password.age;
    owner = "weechat";
    mode = "0400";
  };
  programs.ssh.knownHosts."zh6422.rsync.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtclizeBy1Uo3D86HpgD3LONGVH0CJ0NT+YfZlldAJd";

  services.restic.backups.weechat = {
    repository = "sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/weechat";
    passwordFile = config.age.secrets.chat-restic-password.path;
    paths = [ "/var/lib/weechat" ];
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
    # 10% of pack data per run → full data verification over ~10 days.
    # Metadata is always checked.
    checkOpts = [ "--read-data-subset=10%" ];
    extraOptions = [
      "sftp.command='ssh -i ${config.age.secrets.chat-restic-ssh-key.path} -o StrictHostKeyChecking=yes zh6422@zh6422.rsync.net -s sftp'"
    ];
    initialize = true;
  };

  # ---------------------------------------------------------------------------
  # Per-service systemd sandbox overrides (nixpkgs modules ship minimal
  # hardening for these). Common Protect* set, with carve-outs noted.
  # ---------------------------------------------------------------------------

  # weechat: parses untrusted IRC/Matrix/Slack input + loads Python plugins.
  # Skip MemoryDenyWriteExecute — Python uses W+X mmaps for the JIT-ish dispatch.
  # SystemCallFilter must allow @setuid: weechat's hook_process forks helper
  # processes and calls setuid(getuid()) — a no-op call that's still in the
  # @privileged group and would crash python plugins (weechat-matrix etc.)
  # if we filtered it out.
  systemd.services.weechat.serviceConfig = {
    NoNewPrivileges = true;
    LockPersonality = true;
    # PrivateDevices intentionally NOT set: dtach uses /dev/ptmx to allocate
    # a pty for weechat; PrivateDevices=true blocks ptmx and dtach exits 1.
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    ReadWritePaths = [ "/var/lib/weechat" ];
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
      "@setuid"
      "~@resources"
    ];
    # UMask comes from the main service block (0007) — needs group-rw on the
    # dtach socket so zimbatm (member of the weechat group) can attach.
  };

  # restic backup: handles untrusted network input from rsync.net's SFTP
  # service. Keeps User=root because it needs to read /var/lib/weechat as
  # root, but everything else gets clamped down.
  systemd.services."restic-backups-weechat".serviceConfig = {
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
    ReadOnlyPaths = [ "/var/lib/weechat" ];
    ReadWritePaths = [ "/var/cache/restic-backups-weechat" ];
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
    # restic runs as root but /var/lib/weechat is mode 0750 owned by
    # weechat:weechat — without CAP_DAC_READ_SEARCH the DAC mode check
    # still applies and restic silently saves Files: 0 new.
    CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
    AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
    UMask = "0077";
  };

  # subportal-agent runs as the lingered root user manager. Iroh's netmon
  # needs AF_NETLINK to track interface changes — without it the agent
  # crashes on startup ("Address family not supported by protocol").
  systemd.user.services.subportal-agent.serviceConfig = {
    NoNewPrivileges = true;
    LockPersonality = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
      "AF_NETLINK"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
