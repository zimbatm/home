{ self, ... }:
{
  perSystem = { system, lib, ... }:
    let
      # Only check the configurations for the current system
      sysConfigs = lib.filterAttrs (name: value: value.pkgs.system == system) self.nixosConfigurations;
    in
    {
      # Add all the nixos configurations to the checks
      checks = lib.mapAttrs' (name: value: { name = "nixos-toplevel-${name}"; value = value.config.system.build.toplevel; }) sysConfigs;
    };
}

