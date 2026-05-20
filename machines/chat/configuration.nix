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
    inputs.self.nixosModules.hardening
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.disko.nixosModules.disko
    inputs.subportal.nixosModules.subportal
    ./disko.nix
  ];

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

  services.weechat = {
    enable = true;
    headless = true;
    package = weechat;
  };

  # Same wrapped weechat in PATH so `sudo -u weechat weechat …` works for
  # interactive setup (stopping the service + running the TUI).
  environment.systemPackages = [ weechat ];

  # subportal server-side: provides xdg-open / notify-send drop-ins that
  # forward to enrolled desktops (nv1) over iroh p2p. Enroll once with:
  #   ssh root@chat subportal ticket | subportal-desktop enroll
  programs.subportal.enable = true;
  programs.subportal.agent.enable = true;
  # subportal-agent is a systemd USER service. On a headless server the user
  # manager only runs at login unless we enable lingering — pin it for root
  # so the agent stays up across SSH disconnects and reboots.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/root 0644 root root - -"
  ];

  # zimbatm can read/edit the weechat state dir for first-time relay setup
  # (`sudo systemctl stop weechat && weechat-headless --dir /var/lib/weechat`
  # to attach via a one-shot session, then `/relay add ...; /save; /quit`).
  users.users.zimbatm.extraGroups = [
    "wheel"
    "weechat"
  ];

  users.users.zimbatm.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
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
    PrivateDevices = true;
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
    UMask = "0077";
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
    CapabilityBoundingSet = "";
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
