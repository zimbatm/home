{ self, inputs, ... }:
let
  nixosSystem = args:
    inputs.nixpkgs.lib.nixosSystem ({ specialArgs = { inherit inputs; }; } // args);
in
{
  flake.nixosConfigurations = {
    no1 = nixosSystem {
      system = "x86_64-linux";
      modules = [ ./no1 ];
    };
    silent1 = nixosSystem {
      system = "x86_64-linux";
      modules = [ ./silent1 ];
    };
    x1 = nixosSystem {
      system = "x86_64-linux";
      modules = [ ./x1 ];
    };
  };

  # This is the flake that contains the home-manager configuration
  perSystem = { pkgs, lib, system, ... }:
    let
      # Only check the configurations for the current system
      sysConfigs = lib.filterAttrs (_name: value: value.pkgs.system == system) self.nixosConfigurations;
    in
    {
      # Run `nix run .#nixos switch`
      packages.nixos = pkgs.writeShellScriptBin "nixos" ''
        set -euo pipefail
        # Allow running the command as a user
        export SUDO_USER=1
        ${pkgs.nixos-rebuild}/bin/nixos-rebuild --flake ${self} "$@"
      '';

      # Add all the nixos configurations to the checks
      checks = lib.mapAttrs' (name: value: { name = "nixos-toplevel-${name}"; value = value.config.system.build.toplevel; }) sysConfigs;
    };
}
