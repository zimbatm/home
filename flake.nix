{
  description = "zimbatm's dotfiles";

  inputs = {
    devshell.inputs.flake-utils.follows = "flake-utils";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devshell.url = "github:numtide/devshell";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.inputs.systems.follows = "systems";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    lanzaboote.inputs.flake-parts.follows = "flake-parts";
    lanzaboote.inputs.flake-utils.follows = "flake-utils";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote/v0.3.0";
    mkdocs-numtide.inputs.nixpkgs.follows = "nixpkgs";
    mkdocs-numtide.url = "github:numtide/mkdocs-numtide";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.follows = "srvos/nixpkgs"; # use the version of nixpkgs that has been tested with SrvOS
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows = "";
    sops-nix.url = "github:Mic92/sops-nix";
    srvos.url = "github:numtide/srvos";
    systems.url = "github:nix-systems/x86_64-linux";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs @ { flake-parts, systems, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      imports = [
        ./devshell.nix
        ./docs
        ./homeConfigurations
        ./nixosConfigurations
        ./nixosModules
        ./packages
        inputs.devshell.flakeModule
        inputs.treefmt-nix.flakeModule
      ];
      perSystem.treefmt.imports = [ ./treefmt.nix ];
    };
}
