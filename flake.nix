{
  description = "zimbatm's dotfiles";

  inputs = {
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devshell.inputs.systems.follows = "systems";
    devshell.url = "github:numtide/devshell";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    mkdocs-numtide.inputs.nixpkgs.follows = "nixpkgs";
    mkdocs-numtide.url = "github:numtide/mkdocs-numtide";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nixpkgs.follows = "srvos/nixpkgs"; # use the version of nixpkgs that has been tested with SrvOS
    srvos.url = "github:numtide/srvos";
    systems.url = "github:nix-systems/x86_64-linux";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs @ { flake-parts, systems, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      imports = [
        ./devShells
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
