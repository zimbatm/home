{
  description = "zimbatm's machines — kin-managed";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    kin = {
      url = "git+ssh://git@github.com/assise/kin";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.iets.follows = "iets";
      inputs.nix-skills.follows = "nix-skills";
      inputs.maille.inputs.llm-agents.follows = "llm-agents";
    };
    iets = {
      url = "git+ssh://git@github.com/jonasc-ant/iets";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.llm-agents.follows = "llm-agents";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
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
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    nix-skills = {
      url = "git+ssh://git@github.com/assise/nix-skills";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.blueprint.follows = "llm-agents/blueprint";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
          overlays = [ ];
        };
      treefmtFor =
        system:
        inputs.treefmt-nix.lib.evalModule (pkgsFor system) {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        };

      # Explicit — no auto-discovery. ADR-0006: locality over abstraction.
      # Canonical inventory of every modules/ file (entrypoints + internals) — intentionally exhaustive.
      nixosModules = {
        common = ./modules/nixos/common.nix;
        desktop = ./modules/nixos/desktop.nix;
        gnome = ./modules/nixos/gnome.nix;
        gotosocial = ./modules/nixos/gotosocial.nix;
        perlless = ./modules/nixos/perlless.nix;
        pin-nixpkgs = ./modules/nixos/pin-nixpkgs.nix;
        steam = ./modules/nixos/steam.nix;
        ubuntu-light = ./modules/nixos/ubuntu-light.nix;
        zimbatm = ./modules/nixos/zimbatm.nix;
      };
      homeModules = {
        desktop = ./modules/home/desktop;
        terminal = ./modules/home/terminal;
      };
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          call = p: pkgs.callPackage p { inherit inputs system; };
        in
        {
          inherit (kinOut.packages.${system}) devshell agentshell;
          core = call ./packages/core;
          myvim = call ./packages/myvim;
          nvim = call ./packages/nvim;
          gitbutler-cli = call ./packages/gitbutler-cli;
          ptt-dictate = call ./packages/ptt-dictate;
          transcribe-npu = call ./packages/transcribe-npu;
          say-back = call ./packages/say-back;
          agent-eyes = call ./packages/agent-eyes;
          gsnap = call ./packages/gsnap;
          ask-local = call ./packages/ask-local;
          kin-opts = call ./packages/kin-opts;
          infer-queue = call ./packages/infer-queue;
          llm-router = call ./packages/llm-router;
          agent-meter = call ./packages/agent-meter;
          now-context = call ./packages/now-context;
          pty-puppet = call ./packages/pty-puppet;
          inherit (inputs.nix-skills.packages.${system}) nix-skills-commands;
        }
      );

      kinOut = inputs.kin.lib.mkFleet {
        root = ./.;
        config = import ./kin.nix;
        nixpkgsConfig.allowUnfree = true;
        specialArgs = { inherit inputs; };
        devShell.systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        devShell.extraPackages =
          pkgs:
          [
            pkgs.age-plugin-tpm
            pkgs.hcloud
            pkgs.sbctl
            pkgs.ssh-to-age
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            inputs.iets.packages.${pkgs.stdenv.hostPlatform.system}.iets
            inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.formatter
          ];
        devShell.extraAgentPackages = pkgs: [
          (pkgs.callPackage ./packages/agent-eyes { })
          (pkgs.callPackage ./packages/kin-opts { })
          (pkgs.callPackage ./packages/pty-puppet { })
        ];
      };
    in
    {
      inherit nixosModules homeModules packages;
      inherit (kinOut) nixosConfigurations kinManifest devShells;

      formatter = forAllSystems (system: (treefmtFor system).config.build.wrapper);
      checks = forAllSystems (
        system:
        {
          fmt = (treefmtFor system).config.build.check inputs.self;
        }
        // lib.optionalAttrs (system == "x86_64-linux") (
          lib.mapAttrs (_: c: c.config.system.build.toplevel) kinOut.nixosConfigurations
        )
      );
    };
}
