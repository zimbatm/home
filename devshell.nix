{
  pkgs,
  perSystem,
  inputs,
}:
pkgs.mkShellNoCC {
  packages = [
    inputs.kin.packages.${pkgs.stdenv.hostPlatform.system}.kin
    pkgs.age
    pkgs.hcloud
    pkgs.sbctl
    pkgs.sops
    pkgs.ssh-to-age
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.formatter
  ];

  shellHook = ''
    export PRJ_ROOT=$PWD
    export KIN_IDENTITY="''${KIN_IDENTITY:-$PRJ_ROOT/keys/users/$(whoami).key}"
  '';
}
