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

  # The neoforge-21.8.49 installer's --fat-offline output bytes drifted since
  # numcraft pinned its hash (NeoForged re-published or a transitive lib
  # rolled). Override the src hash to the value Nix actually produces today.
  # Drop this block once numcraft.nix lands a refreshed hash upstream.
  neoforgeServer = numcraft.neoforgeServer.overrideAttrs (old: {
    src = pkgs.fetchurl {
      url = "https://maven.neoforged.net/releases/net/neoforged/neoforge/21.8.49/neoforge-21.8.49-installer.jar";
      hash = "sha256-NmQaxGabKZ+/RiYTdlUJnqi+3Rp2RJNrXtAnrFoUVic=";
      downloadToTemp = true;
      nativeBuildInputs = [
        pkgs.jdk
        pkgs.perl5Packages.strip-nondeterminism
      ];
      postFetch = ''
        java -jar $downloadedFile --fat-offline --fat $out
        strip-nondeterminism -t zip $out
      '';
    };
  });

  serverMods = numcraft.server.modList;

  # lazymc 0.2.11 (latest as of 2024-03) predates Minecraft 1.21's "Transfer"
  # handshake intent (next_state=3). When a client gets /transfer'd to a
  # lazymc-fronted backend, lazymc rejects with "unknown protcol state (3)".
  # Single-line patch: treat state 3 the same as state 2 (Login). The
  # original handshake bytes are forwarded verbatim to the upstream JVM,
  # so NeoForge still sees the Transfer intent and handles re-auth.
  lazymc = pkgs.lazymc.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/proto/client.rs \
        --replace-fail '2 => Some(Self::Login),' '2 | 3 => Some(Self::Login),'
    '';
  });

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
      dir = "manor(1)";
      short = "manor-1";
      port = 25567;
    }
    {
      dir = "restaurant";
      short = "restaurant";
      port = 25568;
    }
    {
      dir = "tvgirl";
      short = "tvgirl";
      port = 25569;
    }
    {
      dir = "GALAXI";
      short = "galaxi";
      port = 25570;
    }
    {
      dir = "galaxi (1)";
      short = "galaxi-1";
      port = 25571;
    }
    {
      dir = "GAMBLING";
      short = "gambling";
      port = 25572;
    }
    {
      dir = "hero";
      short = "hero";
      port = 25573;
    }
    {
      dir = "LOVE IN BOTTLE";
      short = "love-in-bottle";
      port = 25574;
    }
    {
      dir = "mind electric";
      short = "mind-electric";
      port = 25575;
    }
    {
      dir = "death";
      short = "death";
      port = 25576;
    }
    {
      dir = "for mother";
      short = "for-mother";
      port = 25577;
    }
    {
      dir = "idk";
      short = "idk";
      port = 25578;
    }
    {
      dir = "New World";
      short = "new-world";
      port = 25579;
    }
    {
      dir = "New World (1)";
      short = "new-world-1";
      port = 25580;
    }
    {
      dir = "New World (2)";
      short = "new-world-2";
      port = 25581;
    }
    {
      dir = "New World (3)";
      short = "new-world-3";
      port = 25582;
    }
    {
      dir = "New World (4)";
      short = "new-world-4";
      port = 25583;
    }
    {
      dir = "New World (5)";
      short = "new-world-5";
      port = 25584;
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
  # authenticates against Mojang directly. Bridge gets superflat + RCON
  # (localhost-only, password generated at activation) so the portal room
  # can be laid out remotely via mcrcon.
  bridgeRconPort = 25599;
  mkServerProperties =
    w:
    let
      isBridge = w.bridge or false;
      backendPort = if isBridge then w.port else w.port + internalOffset;
      bind = if isBridge then "0.0.0.0" else "127.0.0.1";
      levelType = if isBridge then "minecraft:flat" else "minecraft:normal";
      # Superflat: bedrock + dirt + grass. features=false suppresses villages,
      # trees, etc. so the lobby stays clean. The actual placement is wherever
      # the layers happen to stack — surface ends up at y=-61 by default.
      generatorSettings =
        if isBridge then
          ''{"layers":[{"block":"minecraft:bedrock","height":1},{"block":"minecraft:dirt","height":2},{"block":"minecraft:grass_block","height":1}],"biome":"minecraft:plains","features":false}''
        else
          "{}";
      rconLines =
        if isBridge then
          ''
            enable-rcon=true
            rcon.port=${toString bridgeRconPort}
            rcon.password=PLACEHOLDER_RCON_PASSWORD
          ''
        else
          "enable-rcon=false\n";
      # Bridge: peaceful kills all hostile mobs + prevents respawn (lobby
      # world; no need for slimes wandering the portal room). Other worlds
      # keep normal difficulty so survival gameplay still works.
      difficulty = if isBridge then "peaceful" else "normal";
      spawnMonsters = if isBridge then "false" else "true";
      # Bridge: function-permission-level=4 so command blocks driving the
      # portal /transfer commands have op-equivalent permission. /transfer
      # is gated at level 3, default function level (2) silently rejects it.
      functionPermLevel = if isBridge then 4 else 2;
    in
    pkgs.writeText "server-${w.short}.properties" ''
      accepts-transfers=true
      allow-flight=true
      allow-nether=true
      broadcast-console-to-ops=true
      broadcast-rcon-to-ops=true
      difficulty=${difficulty}
      enable-command-block=true
      enable-jmx-monitoring=false
      enable-query=false
      ${rconLines}      enable-status=true
      enforce-secure-profile=true
      enforce-whitelist=true
      entity-broadcast-range-percentage=100
      force-gamemode=false
      function-permission-level=${toString functionPermLevel}
      gamemode=survival
      generate-structures=true
      generator-settings=${generatorSettings}
      hardcore=false
      hide-online-players=false
      level-name=${w.dir}
      level-seed=
      level-type=${levelType}
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
      spawn-monsters=${spawnMonsters}
      spawn-protection=0
      sync-chunk-writes=true
      use-native-transport=true
      view-distance=10
      white-list=true
    '';

  # Per-world directory bootstrap. Runs every activation: ensures the dir
  # exists and is owned by minecraft, plus the immutable bits (mods/libs
  # symlinks, eula). Service-managed files (server.properties, whitelist,
  # ops) are rewritten by ExecStartPre on every restart so the JVM can't
  # drift them away from what Nix declares.
  mkWorldDirSetup =
    w:
    let
      worldRoot = "/var/lib/minecraft/worlds/${w.short}";
    in
    ''
      mkdir -p "${worldRoot}"
      chown minecraft:minecraft "${worldRoot}"
      chmod 0750 "${worldRoot}"
      printf '%s\n' "eula=true" > "${worldRoot}/eula.txt"
      chown minecraft:minecraft "${worldRoot}/eula.txt"
      ln -sfn /var/lib/minecraft/mods "${worldRoot}/mods"
      ln -sfn /var/lib/minecraft/libraries "${worldRoot}/libraries"
    '';

  # Each world gets its own UDP voicechat port (default 24454 collides
  # across worlds — bridge holds it, every lazymc backend's JVM crashes
  # on startup trying to bind the same port). Offset 1111 below TCP keeps
  # the numbers neighborly: bridge=24454, manor=24455, ..., last=24473.
  voicechatPortFor = w: w.port - 1111;

  # Idempotent server-state refresh, run as ExecStartPre. Overwrites
  # server.properties (NeoForge likes to normalize this on shutdown),
  # whitelist.json, ops.json. Runs as the minecraft user; only writes
  # files inside the world dir which the user owns. For bridge, also
  # substitutes the RCON password placeholder with the per-host generated
  # value from /var/lib/minecraft/bridge-rcon-password.
  mkPreStart =
    w:
    let
      props = mkServerProperties w;
      isBridge = w.bridge or false;
      rconSubst =
        if isBridge then
          ''
            if [ -r /var/lib/minecraft/bridge-rcon-password ]; then
              pw=$(cat /var/lib/minecraft/bridge-rcon-password)
              sed -i "s|^rcon.password=.*|rcon.password=$pw|" server.properties
            fi
          ''
        else
          "";
      vcPort = toString (voicechatPortFor w);
    in
    pkgs.writeShellScript "minecraft-${w.short}-prestart" ''
      cd /var/lib/minecraft/worlds/${w.short}
      cp -f ${props} server.properties
      chmod 0644 server.properties
      ${rconSubst}
      cat > whitelist.json <<'EOF'
${whitelistJson}
EOF
      cat > ops.json <<'EOF'
${opsJson}
EOF
      chmod 0644 whitelist.json ops.json
      # Per-world voicechat port — bridge holds the default 24454, every
      # other backend would crash on bind without a unique port here.
      mkdir -p config/voicechat
      if [ -f config/voicechat/voicechat-server.properties ]; then
        sed -i "s/^port=.*/port=${vcPort}/" config/voicechat/voicechat-server.properties
      else
        printf 'port=%s\nbind_address=\n' "${vcPort}" > config/voicechat/voicechat-server.properties
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
      ExecStartPre = mkPreStart bridge;
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
        ExecStartPre = mkPreStart w;
        ExecStart = "${lazymc}/bin/lazymc -c ${toml} start";
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

  # Hetzner Cloud cpx42, fsn1, UEFI. Personal modded Minecraft hosting,
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
    address = [ "2a01:4f8:c013:cb17::1/64" ];
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
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

  # rsync: world uploads. mcrcon: local control of the bridge JVM (place
  # command blocks, set spawn, etc.) without needing in-game ops chat.
  environment.systemPackages = [
    pkgs.rsync
    pkgs.mcrcon
  ];

  # Minecraft user + state dir.
  users.groups.minecraft = { };
  users.users.minecraft = {
    isSystemUser = true;
    group = "minecraft";
    home = "/var/lib/minecraft";
    createHome = true;
  };

  # Firewall: each world its own TCP port + matching UDP port for voicechat
  # (each world's JVM binds its own UDP port; see voicechatPortFor).
  networking.firewall.allowedTCPPorts = publicTcpPorts;
  networking.firewall.allowedUDPPorts = map voicechatPortFor worldDefs;

  # Populate /var/lib/minecraft/{mods,libraries} from the neoforgeServer
  # derivation, plus per-world bootstrap. Idempotent — safe to re-run on
  # every nixos-rebuild.
  systemd.tmpfiles.rules = [
    "d /var/lib/minecraft 0750 minecraft minecraft - -"
    "d /var/lib/minecraft/worlds 0750 minecraft minecraft - -"
  ];

  system.activationScripts.minecraft-setup = {
    text = ''
      # RCON password for the bridge — generated once per host, persisted
      # across rebuilds. ExecStartPre substitutes it into server.properties.
      if [ ! -s /var/lib/minecraft/bridge-rcon-password ]; then
        head -c 24 /dev/urandom | base64 > /var/lib/minecraft/bridge-rcon-password
        chmod 0640 /var/lib/minecraft/bridge-rcon-password
        chown minecraft:minecraft /var/lib/minecraft/bridge-rcon-password
      fi

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
    # The per-world chown reference the minecraft user — must run after
    # `users` populates /etc/passwd. Without this, the initrd activation
    # runs before user creation and chown fails for every world.
    deps = [ "users" "groups" ];
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
