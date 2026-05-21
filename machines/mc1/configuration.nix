{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # Reuse Numtide's numcraft build: same NeoForge version + mod set the
  # client side already ships (you're whitelisted there, and your PrismLauncher
  # is wired to its mrpack). Importing the file directly from the flake input
  # is enough — numcraft doesn't re-export the derivation as a flake output.
  numcraft = import "${inputs.numcraft}/minecraft.nix" {
    inherit pkgs lib;
  };

  neoforgeServer = numcraft.neoforgeServer;
  serverMods = numcraft.server.modList;

  # ---------------------------------------------------------------------------
  # Worlds. Source-of-truth list — the zip has 16 save dirs, two pairs of
  # case-only dupes (`galaxi`/`GALAXI`, `manor`/`manor(1)`). systemd unit names
  # must be unique and ascii-safe, so we map original dir name -> short name.
  # Ports increment from 25565 (bridge) upward. lazymc wraps everything except
  # the bridge so unused JVMs sleep.
  # ---------------------------------------------------------------------------
  worldDefs = [
    {
      dir = "bridge";
      short = "bridge";
      port = 25565;
      bridge = true;
    }
    {
      dir = "manor";
      short = "manor";
      port = 25566;
    }
    {
      dir = "restaurant";
      short = "restaurant";
      port = 25567;
    }
    {
      dir = "tvgirl";
      short = "tvgirl";
      port = 25568;
    }
    {
      dir = "galaxi";
      short = "galaxi";
      port = 25569;
    }
    {
      dir = "GALAXI";
      short = "galaxi2";
      port = 25570;
    }
    {
      dir = "GAMBLING";
      short = "gambling";
      port = 25571;
    }
    {
      dir = "hero";
      short = "hero";
      port = 25572;
    }
    {
      dir = "LOVE";
      short = "love";
      port = 25573;
    }
    {
      dir = "mind";
      short = "mind";
      port = 25574;
    }
    {
      dir = "death";
      short = "death";
      port = 25575;
    }
    {
      dir = "for";
      short = "for";
      port = 25576;
    }
    {
      dir = "idk";
      short = "idk";
      port = 25577;
    }
    {
      dir = "New";
      short = "new";
      port = 25578;
    }
    {
      dir = "manor(1)";
      short = "manor2";
      port = 25579;
    }
  ];

  publicTcpPorts = map (w: w.port) worldDefs;
  bridge = lib.findFirst (w: w.bridge or false) (throw "no bridge world defined") worldDefs;

  # lazymc listens on the public port and forks the JVM internally bound to
  # this offset port. Keeps the JVM hidden from the firewall.
  internalOffset = 10000;

  # Whitelist — pull from numcraft so the existing crew can join without
  # extra plumbing. Numcraft's TOML has snake_case keys but Minecraft
  # whitelist.json wants {name, uuid}.
  whitelistEntries = lib.mapAttrsToList (name: uuid: { inherit name uuid; }) numcraft.whitelist;
  whitelistJson = builtins.toJSON whitelistEntries;

  # ops.json — give zimbatm op on every world.
  opsJson = builtins.toJSON [
    {
      name = "zimbatm";
      uuid = "8c5dfdf0-ffa0-4379-9e46-873c882d1929";
      level = 4;
      bypassesPlayerLimit = false;
    }
  ];

  # server.properties shared template. Per-world overrides slot in port,
  # level-name, motd. Online-mode stays true: no proxy, each backend
  # authenticates against Mojang directly.
  mkServerProperties =
    w:
    let
      backendPort = if (w.bridge or false) then w.port else w.port + internalOffset;
      bind = if (w.bridge or false) then "0.0.0.0" else "127.0.0.1";
    in
    pkgs.writeText "server-${w.short}.properties" ''
      accepts-transfers=false
      allow-flight=true
      allow-nether=true
      broadcast-console-to-ops=true
      broadcast-rcon-to-ops=true
      difficulty=normal
      enable-command-block=false
      enable-jmx-monitoring=false
      enable-query=false
      enable-rcon=false
      enable-status=true
      enforce-secure-profile=true
      enforce-whitelist=true
      entity-broadcast-range-percentage=100
      force-gamemode=false
      function-permission-level=2
      gamemode=survival
      generate-structures=true
      generator-settings={}
      hardcore=false
      hide-online-players=false
      level-name=${w.dir}
      level-seed=
      level-type=minecraft:normal
      log-ips=true
      max-chained-neighbor-updates=1000000
      max-players=20
      max-tick-time=60000
      max-world-size=29999984
      motd=${w.short} — mc.ztm.io
      network-compression-threshold=256
      online-mode=true
      op-permission-level=4
      pause-when-empty-seconds=60
      player-idle-timeout=15
      prevent-proxy-connections=false
      pvp=true
      query.port=${toString backendPort}
      rate-limit=0
      region-file-compression=deflate
      require-resource-pack=false
      server-ip=${bind}
      server-port=${toString backendPort}
      simulation-distance=8
      spawn-monsters=true
      spawn-protection=0
      sync-chunk-writes=true
      use-native-transport=true
      view-distance=10
      white-list=true
    '';

  # Per-world directory bootstrap. Runs every activation: lays down config
  # files, ensures world/ exists (or warns), wires the shared mods symlink.
  # Does NOT touch world data after first creation — only management files.
  mkWorldDirSetup =
    w:
    let
      worldRoot = "/var/lib/minecraft/worlds/${w.short}";
      props = mkServerProperties w;
    in
    ''
      mkdir -p "${worldRoot}"
      install -m 0644 -o minecraft -g minecraft ${props} "${worldRoot}/server.properties"
      printf '%s\n' "eula=true" > "${worldRoot}/eula.txt"
      printf '%s' '${whitelistJson}' > "${worldRoot}/whitelist.json"
      printf '%s' '${opsJson}' > "${worldRoot}/ops.json"
      chown minecraft:minecraft "${worldRoot}/eula.txt" "${worldRoot}/whitelist.json" "${worldRoot}/ops.json"
      ln -sfn /var/lib/minecraft/mods "${worldRoot}/mods"
      ln -sfn /var/lib/minecraft/libraries "${worldRoot}/libraries" 2>/dev/null || true
      # Save dir lives at worldRoot/${w.dir} (matches level-name). If it's
      # missing on first deploy that's expected — upload from the zip per README.
      if [ ! -d "${worldRoot}/${w.dir}" ]; then
        echo "warn: ${worldRoot}/${w.dir} not present (upload via rsync, see README)" >&2
      fi
    '';

  # Bridge runs the JVM directly. The wrapper from neoforgeServer expects to
  # be run from a world dir (CWD = where server.properties + world/ live).
  bridgeService = {
    description = "Minecraft bridge world (always-on lobby)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "minecraft";
      Group = "minecraft";
      WorkingDirectory = "/var/lib/minecraft/worlds/${bridge.short}";
      ExecStart = "${neoforgeServer}/bin/minecraft-server nogui";
      Restart = "on-failure";
      RestartSec = "10s";
      # Modded JVM + voicechat needs network + reasonable filesystem access.
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
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/minecraft/worlds/${bridge.short}" ];
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };
  };

  # lazymc.toml for a single world. Public port = the player-facing port;
  # the JVM lives on 127.0.0.1:<port+internalOffset>. When the public port
  # gets a real handshake, lazymc spawns the JVM and proxies; when empty
  # for `sleep_after`, it kills the JVM. The `forge` flavour adjusts to
  # NeoForge's handshake quirks.
  mkLazymcToml =
    w:
    pkgs.writeText "lazymc-${w.short}.toml" ''
      [public]
      address = "0.0.0.0:${toString w.port}"
      version = "1.21.8"
      protocol = 772

      [server]
      address = "127.0.0.1:${toString (w.port + internalOffset)}"
      directory = "/var/lib/minecraft/worlds/${w.short}"
      command = "${neoforgeServer}/bin/minecraft-server nogui"
      freeze_process = false
      wake_on_crash = true
      forge = true
      probe_on_start = false

      [time]
      sleep_after = 300
      minimum_online_time = 60

      [motd]
      sleeping = "§8§lmc.ztm.io §r§8— ${w.short} is asleep, join to wake"
      starting = "§6§lmc.ztm.io §r§6— ${w.short} is waking up..."
      from_server = false

      [advanced]
      rewrite_server_properties = false
    '';

  mkLazyService =
    w:
    let
      toml = mkLazymcToml w;
    in
    {
      description = "Minecraft world '${w.short}' via lazymc (on-demand)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "minecraft";
        Group = "minecraft";
        WorkingDirectory = "/var/lib/minecraft/worlds/${w.short}";
        ExecStart = "${pkgs.lazymc}/bin/lazymc -c ${toml} start";
        Restart = "on-failure";
        RestartSec = "10s";
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
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/minecraft/worlds/${w.short}" ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };
    };

  serviceUnits =
    let
      lazies = builtins.filter (w: !(w.bridge or false)) worldDefs;
    in
    {
      "minecraft-${bridge.short}" = bridgeService;
    }
    // lib.listToAttrs (
      map (w: {
        name = "minecraft-${w.short}";
        value = mkLazyService w;
      }) lazies
    );
in
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.hardening
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
    ./disko.nix
  ];

  # Hetzner Cloud cx42, fsn1, UEFI. Personal modded Minecraft hosting,
  # NeoForge 1.21.8 — same mod set as Numtide's arcade1 (numcraft pinned as
  # a flake input). One always-on "bridge" world + 14 on-demand worlds
  # behind lazymc, all sharing the same JVM/mods/whitelist. Public surface:
  # one TCP port per world + UDP 24454 for the voicechat mod.
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "mc1";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.useDHCP = lib.mkForce true;
  # Match both eth0 (newer images, net.ifnames=0) and enp1s0 (older).
  systemd.network.networks."05-eth" = {
    matchConfig.Name = "enp1s0 eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    # IPv6 /64 from Hetzner: filled in post-provisioning. Until then,
    # comment-only — DHCPv4 is enough to reach the box.
    # address = [ "2a01:4f8:xxxx:xxxx::1/64" ];
    # routes = [ { Gateway = "fe80::1"; GatewayOnLink = true; } ];
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

  # Minecraft user + state dir.
  users.groups.minecraft = { };
  users.users.minecraft = {
    isSystemUser = true;
    group = "minecraft";
    home = "/var/lib/minecraft";
    createHome = true;
  };

  # Firewall: each world its own TCP port. UDP 24454 for the voicechat mod
  # (shared across all worlds — only one is ever active per player).
  networking.firewall.allowedTCPPorts = publicTcpPorts;
  networking.firewall.allowedUDPPorts = [ 24454 ];

  # Populate /var/lib/minecraft/{mods,libraries} from the neoforgeServer
  # derivation, plus per-world bootstrap. Idempotent — safe to re-run on
  # every nixos-rebuild.
  systemd.tmpfiles.rules = [
    "d /var/lib/minecraft 0750 minecraft minecraft - -"
    "d /var/lib/minecraft/worlds 0750 minecraft minecraft - -"
  ];

  system.activationScripts.minecraft-setup = {
    text = ''
      # Shared mods + libraries dirs. Wipe + relink each activation so we
      # pick up nixpkgs/numcraft bumps without orphaned mod versions.
      rm -rf /var/lib/minecraft/mods /var/lib/minecraft/libraries
      mkdir -p /var/lib/minecraft/mods
      ${lib.concatMapStringsSep "\n" (
        mod: "ln -sfn ${mod} /var/lib/minecraft/mods/$(basename ${mod})"
      ) serverMods}
      ln -sfn ${neoforgeServer}/lib /var/lib/minecraft/libraries
      chown -h minecraft:minecraft /var/lib/minecraft/mods /var/lib/minecraft/libraries

      # Per-world scaffolding.
      ${lib.concatMapStrings mkWorldDirSetup worldDefs}
    '';
    deps = [ ];
  };

  systemd.services = lib.mkMerge [
    serviceUnits
    {
      # Sandbox the restic-backups unit created by services.restic.backups.minecraft.
      "restic-backups-minecraft".serviceConfig = {
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
        ReadOnlyPaths = [ "/var/lib/minecraft/worlds" ];
        ReadWritePaths = [ "/var/cache/restic-backups-minecraft" ];
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
    }
  ];

  # Offsite backups → rsync.net via restic SFTP. Same shape as mail/chat.
  # Backs up all worlds (the bulk of state); the JVM/mods are re-derivable
  # from Nix. preStart shovels each running JVM into save-all/save-off via
  # rcon would be nicer, but with on-demand lazymc + 14 worlds, we accept
  # a crash-consistent snapshot — lazymc's sleeping JVMs aren't touching
  # disk anyway.
  age.secrets.mc1-restic-password.file = ../../secrets/mc1-restic-password.age;
  age.secrets.mc1-restic-ssh-key = {
    file = ../../secrets/mc1-restic-ssh-key.age;
    mode = "0400";
  };

  programs.ssh.knownHosts."zh6422.rsync.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtclizeBy1Uo3D86HpgD3LONGVH0CJ0NT+YfZlldAJd";

  services.restic.backups.minecraft = {
    paths = [ "/var/lib/minecraft/worlds" ];
    repository = "sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/mc1";
    passwordFile = config.age.secrets.mc1-restic-password.path;
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
      "sftp.command='ssh -i ${config.age.secrets.mc1-restic-ssh-key.path} -o StrictHostKeyChecking=yes zh6422@zh6422.rsync.net -s sftp'"
    ];
    initialize = true;
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
