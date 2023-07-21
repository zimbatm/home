{
  perSystem = { config, pkgs, ... }: {
    devshells.default.packages = [
      config.treefmt.build.wrapper
      # inputs'.nixos-anywhere.packages.default
      pkgs.sops
      pkgs.ssh-to-age
    ];
  };
}
