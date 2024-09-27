{ pkgs, perSystem }:
let
  nixos-rebuild = pkgs.writeShellApplication {
    name = "nixos-rebuild";
    runtimeInputs = [ pkgs.nixos-rebuild ];
    text = ''
      set -euo pipefail
      export SUDO_USER=1
      exec nixos-rebuild --flake "$PRJ_ROOT" "$@"
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
