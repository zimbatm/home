{ pkgs, perSystem, ... }:
pkgs.mkShell {
  packages = [
    perSystem.blueprint.bp
    pkgs.nixos-anywhere
    pkgs.sbctl
    pkgs.sops
    pkgs.ssh-to-age
  ];
}
