{
  perSystem = { config, pkgs, ... }: {
    devshells.default.packages = [
      config.treefmt.build.wrapper
      pkgs.nixos-anywhere
      pkgs.sbctl
      pkgs.sops
      pkgs.ssh-to-age
    ];
  };
}
