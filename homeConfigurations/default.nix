{ self, inputs, ... }:
let
  hmConfig =
    pkgs: module:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      extraSpecialArgs = {
        inherit inputs;
      };

      modules = [
        module
        {
          # FIXME: how to handle this properly?
          home.homeDirectory = "/home/zimbatm";
          home.stateVersion = "22.11";
          home.username = "zimbatm";
        }
      ];
    };
in
{
  flake.homeModules.desktop = ./desktop;
  flake.homeModules.sway = ./sway;
  flake.homeModules.terminal = ./terminal;

  # This is the flake that contains the home-manager configuration
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      # Run `nix run hm switch`
      #
      # TODO: set the home.homeDirectory and home.username dynamically
      packages.home = pkgs.writeShellScriptBin "home" ''
        set -euo pipefail

        export PATH=${
          pkgs.lib.makeBinPath [
            pkgs.git
            pkgs.coreutils
            pkgs.nix
            pkgs.jq
            pkgs.unixtools.hostname
          ]
        }
        declare -A profiles=(["x1"]="nixos" ["no1"]="nixos")
        profile="terminal"
        if [[ -n ''${profiles[$(hostname)]:-} ]]; then
          profile=''${profiles[$(hostname)]}
        fi
        if [[ $profile == nixos ]]; then
          echo "aborting: deployed by NixOS" >&2
          exit 1
        fi
        if [[ "''${1:-}" == profile ]]; then
          echo $profile
          exit 0
        fi
        set -x
        ${
          inputs.home-manager.packages.${pkgs.system}.home-manager
        }/bin/home-manager --flake "${self}#$profile" "$@"
      '';

      # Stuff those in legacyPackages to make home-manager happy
      legacyPackages.homeConfigurations.desktop = hmConfig pkgs ./desktop;
      legacyPackages.homeConfigurations.sway = hmConfig pkgs ./sway;
      legacyPackages.homeConfigurations.terminal = hmConfig pkgs ./terminal;

      # Add all the home configurations to the checks
      checks = lib.mapAttrs' (name: value: {
        name = "home-${name}";
        value = value.activation-script;
      }) self.legacyPackages.${system}.homeConfigurations;
    };
}
