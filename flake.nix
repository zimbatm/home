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
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "llm-agents/systems";
      inputs.flake-parts.follows = "llm-agents/flake-parts";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    distro = {
      url = "github:generational-infrastructure/distro";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.llm-agents.follows = "llm-agents";
    };
    voxtype = {
      follows = "distro/voxtype";
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
    # Provides the zimbatm-com static site package (ViewBuilder over data/).
    # Pulled in for the web2 nginx vhost; we don't take any other kit outputs.
    kit = {
      url = "github:zimbatm/kit";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.subportal.follows = "subportal";
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
        common = ./modules/nixos/common.nix;
        desktop = ./modules/nixos/desktop.nix;
        gnome = ./modules/nixos/gnome.nix;
        gotosocial = ./modules/nixos/gotosocial.nix;
        hardening = ./modules/nixos/hardening.nix;
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
      nixosConfigurations = {
        nv1 = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./machines/nv1/configuration.nix
            {
              nixpkgs.config.allowUnfree = true;
            }
          ];
        };
        chat = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./machines/chat/configuration.nix
            inputs.agenix.nixosModules.default
          ];
        };
        web2 = lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./machines/web2/configuration.nix
          ];
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
          ask-cuda = call ./packages/ask-cuda;
          ask-local = call ./packages/ask-local;
          core = call ./packages/core;
          gitbutler-cli = call ./packages/gitbutler-cli;
          gsnap = call ./packages/gsnap;
          infer-queue = call ./packages/infer-queue;
          lith = call ./packages/lith;
          live-caption-log = call ./packages/live-caption-log;
          llm-router = call ./packages/llm-router;
          man-here = call ./packages/man-here;
          myvim = call ./packages/myvim;
          nvim = call ./packages/nvim;
          ptt-dictate = call ./packages/ptt-dictate;
          pty-puppet = call ./packages/pty-puppet;
          rich-ssh-agent = call ./packages/rich-ssh-agent;
          say-back = call ./packages/say-back;
          sel-act = call ./packages/sel-act;
          sem-grep = call ./packages/sem-grep;
          shell-squeeze = call ./packages/shell-squeeze;
          tab-tap = call ./packages/tab-tap;
          transcribe-cpu = call ./packages/transcribe-cpu;
          transcribe-npu = call ./packages/transcribe-npu;
          wake-listen = call ./packages/wake-listen;
          web-eyes = call ./packages/web-eyes;
        }
      );
    in
    {
      inherit nixosModules homeModules nixosConfigurations packages;

      formatter = forAllSystems (
        system: (treefmtFor inputs.nixpkgs.legacyPackages.${system}).config.build.wrapper
      );
      checks = forAllSystems (
        system: {
          fmt = (treefmtFor inputs.nixpkgs.legacyPackages.${system}).config.build.check inputs.self;
        }
      );
    };
}
