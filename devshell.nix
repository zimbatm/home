{ pkgs, ... }:
pkgs.mkShell {
  packages = [
    pkgs.nixos-anywhere
    pkgs.sbctl
    pkgs.sops
    pkgs.ssh-to-age
  ];
}
