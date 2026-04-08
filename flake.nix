{
  description = "zimbatm's machines — kin-managed";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    kin = { url = "git+ssh://git@github.com/assise/kin"; inputs.nixpkgs.follows = "nixpkgs"; };
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    srvos = { url = "github:numtide/srvos"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    lanzaboote = { url = "github:nix-community/lanzaboote"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixvim.url = "github:nix-community/nixvim";
    llm-agents = { url = "github:numtide/llm-agents.nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    treefmt-nix = { url = "github:numtide/treefmt-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = inputs:
    let
      lib = inputs.nixpkgs.lib;
      forAllSystems = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
      pkgsFor = system: import inputs.nixpkgs { inherit system; config.allowUnfree = true; overlays = [ ]; };

      # Explicit — no auto-discovery. ADR-0006: locality over abstraction.
      nixosModules = {
        common = ./modules/nixos/common.nix;
        desktop = ./modules/nixos/desktop.nix;
        gnome = ./modules/nixos/gnome.nix;
        gotosocial = ./modules/nixos/gotosocial.nix;
        nix-remote-builders = ./modules/nixos/nix-remote-builders.nix;
        perlless = ./modules/nixos/perlless.nix;
        pinned-nix-registry = ./modules/nixos/pinned-nix-registry.nix;
        server = ./modules/nixos/server.nix;
        steam = ./modules/nixos/steam.nix;
        ubuntu-light = ./modules/nixos/ubuntu-light.nix;
        zimbatm = ./modules/nixos/zimbatm.nix;
      };
      homeModules = {
        desktop = ./modules/home/desktop;
        terminal = ./modules/home/terminal;
      };
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; call = p: pkgs.callPackage p { inherit inputs system; }; in {
          core = call ./packages/core;
          myvim = call ./packages/myvim;
          nvim = call ./packages/nvim;
          alpacasay = call ./packages/alpacasay;
          svg-term = call ./packages/svg-term;
        });

      kinOut = inputs.kin.lib.mkFleet {
        root = ./.;
        config = import ./kin.nix;
        nixpkgsConfig.allowUnfree = true;
        specialArgs = { inherit inputs; flake = inputs.self; };
      };
    in
    {
      inherit nixosModules homeModules packages;
      inherit (kinOut) nixosConfigurations kinManifest kinStatus;

      devShells = forAllSystems (system: {
        default = import ./devshell.nix { pkgs = pkgsFor system; inherit inputs; };
      });
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);
    };
}
