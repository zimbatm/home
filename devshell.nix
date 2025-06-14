{ pkgs, perSystem }:
let
  nixos-rebuild = pkgs.writeShellApplication {
    name = "nixos-rebuild";
    runtimeInputs = [ pkgs.nixos-rebuild-ng ];
    text = ''
      set -euo pipefail
      exec nixos-rebuild-ng --flake "$PRJ_ROOT" --sudo "$@"
    '';
  };
in
pkgs.mkShellNoCC {
  packages = [
    nixos-rebuild
    pkgs.nixos-anywhere
    pkgs.sbctl
    pkgs.sops
    pkgs.ssh-to-age
  ];

  shellHook = ''
    export PRJ_ROOT=$PWD
  '';
}
