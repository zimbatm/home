{ config, lib, ... }:
{
  # crops-demo input removed 2026-04 (repo recreated-private, deploy key 404).
  # Option kept so existing `home.crops.enable = false` doesn't error; enabling
  # throws until access is restored or the packages are re-sourced.
  options.home.crops.enable = lib.mkEnableOption "crops-demo userland CLIs";

  config = lib.mkIf config.home.crops.enable {
    home.packages = throw ''
      home.crops.enable: crops-demo flake input was removed (repo recreated
      private upstream). Re-add the input or source the packages elsewhere.
    '';
  };
}
