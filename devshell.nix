{ pkgs, perSystem }:
pkgs.mkShell {
  packages = [
    perSystem.blueprint.default
    pkgs.nixos-anywhere
    pkgs.sbctl
    pkgs.sops
    pkgs.ssh-to-age
  ];
}
