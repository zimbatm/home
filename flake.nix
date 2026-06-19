{
  description = "zimbatm's local packages and home modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    srvos = {
      url = "github:numtide/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      # Intentionally do NOT follow `nixpkgs`: nixvim tracks unstable (26.11)
      # and breaks when forced onto our 26.05 nixpkgs.
      inputs.systems.follows = "llm-agents/systems";
      inputs.flake-parts.follows = "llm-agents/flake-parts";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    spaces = {
      url = "github:generational-infrastructure/spaces-os";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.llm-agents.follows = "llm-agents";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    subportal = {
      url = "github:zimbatm/subportal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # Numtide arcade1 (numcraft) — NeoForge 1.21.11 server + mod set.
    # mc1 imports its `minecraft.nix` directly to reuse the neoforgeServer
    # derivation, mod list, and whitelist.toml (we're already in it).
    numcraft = {
      url = "github:numtide/numcraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # muvm/libkrun-based microVM runner with desktop integration (GPU,
    # Wayland, PipeWire). Used on nv1 to run NixOS closures as lightweight
    # VMs without giving up host desktop integration.
    munix = {
      url = "git+https://git.clan.lol/clan/munix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Mic92's Rust rewrite of tinc 1.1. Drop-in wire-compatible; exposes
    # nixosModules.tincr (services.tincr.networks.<name>). Used for the
    # private `ztm` mesh between nv1+chat+web2+mail+mc1+agents — keeps
    # internal admin surfaces off the public Internet.
    tincr = {
      url = "github:Mic92/tincr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Clan manages the fleet: `lib.clan` auto-discovers machines/<name>/ and
    # auto-imports their configuration.nix/hardware-configuration.nix/disko.nix,
    # and the `clan` CLI drives deploys + vars (sops) + services. Follow our
    # nixpkgs (nixos-unstable carries the `_class` field clan requires).
    clan-core = {
      url = "git+https://git.clan.lol/clan/clan-core";
      inputs.nixpkgs.follows = "nixpkgs";
      # The servers import `inputs.disko.nixosModules.disko` directly while clan
      # also pulls disko in; two different disko store paths make
      # `_module.args.diskoLib` conflict. Unify on our disko so the module
      # dedupes.
      inputs.disko.follows = "disko";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
      pkgsFor =
        system:
        import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      treefmtFor =
        pkgs:
        inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          settings.formatter.nixfmt = {
            command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
            includes = [ "*.nix" ];
          };
        };
      nixosModules = {
        agent-deploy = ./modules/nixos/agent-deploy.nix;
        bluesky-pds = ./modules/nixos/bluesky-pds.nix;
        common = ./modules/nixos/common.nix;
        desktop = ./modules/nixos/desktop.nix;
        gotosocial = ./modules/nixos/gotosocial.nix;
        hardening = ./modules/nixos/hardening.nix;
        hc-ping = ./modules/nixos/hc-ping.nix;
        noctalia = ./modules/nixos/noctalia.nix;
        pocket-id-clients = ./modules/nixos/pocket-id-clients.nix;
        tinc-ztm = ./modules/nixos/tinc-ztm.nix;
        perlless = ./modules/nixos/perlless.nix;
        steam = ./modules/nixos/steam.nix;
        ubuntu-light = ./modules/nixos/ubuntu-light.nix;
        zero-tailnet = ./modules/nixos/zero-tailnet.nix;
        zimbatm = ./modules/nixos/zimbatm.nix;
      };
      homeModules = {
        desktop = ./modules/home/desktop;
        pi-extensions = ./modules/home/pi-extensions;
        terminal = ./modules/home/terminal;
      };
      # Clan builds all five machines. Each machines/<name>/ directory is
      # auto-discovered and its configuration.nix (+ hardware-configuration.nix
      # / disko.nix) auto-imported, so the per-machine bodies are unchanged from
      # the old hand-written nixosConfigurations. `specialArgs.inputs` keeps the
      # machine modules' `inputs` argument working. `clan` (clan.config) is
      # exposed below; the CLI reads `clanInternals`.
      clan = inputs.clan-core.lib.clan {
        self = inputs.self;
        specialArgs = { inherit inputs; };
        meta.name = "ztm";

        inventory.machines = {
          nv1 = { };
          chat = { };
          web2 = { };
          agents = { };
          mc1 = { };
        };

        # Where `clan machines update <name>` deploys. Servers are reachable on
        # their public Hetzner addresses; web2 has no ztm.io host record so it
        # uses the zimbatm.com apex (WEB2_A). nv1 is the local laptop.
        machines = {
          nv1 = {
            clan.core.networking.targetHost = "root@localhost";
            # Was injected by the old flake module list; nv1 needs unfree.
            nixpkgs.config.allowUnfree = true;
          };
          chat.clan.core.networking.targetHost = "root@chat.ztm.io";
          web2.clan.core.networking.targetHost = "root@zimbatm.com";
          agents.clan.core.networking.targetHost = "root@agents.ztm.io";
          mc1.clan.core.networking.targetHost = "root@mc.ztm.io";
        };
      };
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          call = p: pkgs.callPackage p { inherit inputs system; };
        in
        {
          agent-eyes = call ./packages/agent-eyes;
          ask-local = call ./packages/ask-local;
          core = call ./packages/core;
          gitbutler-cli = call ./packages/gitbutler-cli;
          gsnap = call ./packages/gsnap;
          llm-router = call ./packages/llm-router;
          man-here = call ./packages/man-here;
          myvim = call ./packages/myvim;
          nvim = call ./packages/nvim;
          pty-puppet = call ./packages/pty-puppet;
          rich-ssh-agent = call ./packages/rich-ssh-agent;
          say-back = call ./packages/say-back;
          sel-act = call ./packages/sel-act;
          sem-grep = call ./packages/sem-grep;
          tab-tap = call ./packages/tab-tap;
          web-eyes = call ./packages/web-eyes;
          zimbatm-com = call ./packages/zimbatm-com;
        }
      );
    in
    {
      # Our own reusable modules + packages. NOTE: we deliberately do NOT
      # re-export clan.config.nixosModules here — machines reference
      # `inputs.self.nixosModules.<name>` for these local modules, and clan's
      # generated `clan-machine-*` modules would clobber that set.
      inherit
        nixosModules
        homeModules
        packages
        ;

      # Machine builds + CLI surface come from clan.
      inherit (clan.config) nixosConfigurations clanInternals;
      clan = clan.config;

      # `nix run .#dns-preview` shows the diff between dns/dnsconfig.js and
      # Namecheap's current state. `nix run .#dns-push` applies it. Both
      # expect NAMECHEAP_API_USER and NAMECHEAP_API_KEY in env (.envrc.local).
      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          dnsWrap =
            action:
            pkgs.writeShellApplication {
              name = "dns-${action}";
              runtimeInputs = [ pkgs.dnscontrol ];
              text = ''
                set -eu
                : "''${NAMECHEAP_API_USER:?source .envrc.local first}"
                : "''${NAMECHEAP_API_KEY:?source .envrc.local first}"
                ROOT=$(git rev-parse --show-toplevel)
                cd "$ROOT/dns"
                TMP=$(mktemp -d)
                trap 'rm -rf "$TMP"' EXIT
                cat > "$TMP/creds.json" <<EOF
                {
                  "namecheap": {
                    "TYPE":     "NAMECHEAP",
                    "apikey":   "$NAMECHEAP_API_KEY",
                    "apiuser":  "$NAMECHEAP_API_USER",
                    "username": "$NAMECHEAP_API_USER"
                  }
                }
                EOF
                exec dnscontrol ${action} --config dnsconfig.js --creds "$TMP/creds.json" "$@"
              '';
            };
        in
        {
          dns-preview = {
            type = "app";
            program = "${dnsWrap "preview"}/bin/dns-preview";
          };
          dns-push = {
            type = "app";
            program = "${dnsWrap "push"}/bin/dns-push";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          # agenix wrapped to always operate on secrets/secrets.nix. ryantm
          # agenix resolves its rules from `RULES` (default ./secrets.nix) and
          # writes the .age file at the path you pass, relative to cwd — and our
          # rule keys are bare filenames. So the wrapper cd's into the repo's
          # secrets/ dir first, letting you run `agenix -e <name>.age` with the
          # bare key name from anywhere in the tree. (The bare nixpkgs agenix —
          # and ragenix via `,` — can't find secrets/secrets.nix and die with
          # "Failed to find config root".)
          agenix = pkgs.writeShellApplication {
            name = "agenix";
            runtimeInputs = [ pkgs.git ];
            text = ''
              cd "$(git rev-parse --show-toplevel)/secrets"
              exec ${inputs.agenix.packages.${system}.default}/bin/agenix "$@"
            '';
          };
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              agenix
              pkgs.nixfmt-rfc-style
              # `clan machines update/install`, `clan vars`, `clan backups`, …
              inputs.clan-core.packages.${system}.clan-cli
            ];
          };
        }
      );

      formatter = forAllSystems (
        system: (treefmtFor inputs.nixpkgs.legacyPackages.${system}).config.build.wrapper
      );
      checks = forAllSystems (system: {
        fmt = (treefmtFor inputs.nixpkgs.legacyPackages.${system}).config.build.check inputs.self;
      });
    };
}
