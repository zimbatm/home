{
  pkgs,
  perSystem,
  inputs,
}:
let
  nixos-rebuild = pkgs.writeShellApplication {
    name = "nixos-rebuild";
    text = ''
      set -euo pipefail
      exec ${pkgs.nixos-rebuild-ng}/bin/nixos-rebuild --flake "$PRJ_ROOT" --sudo "$@"
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
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.formatter
  ];

  shellHook = ''
    export PRJ_ROOT=$PWD
  '';
}
