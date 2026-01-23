{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "core";
  runtimeInputs = [ pkgs.openssh ];
  text = ''
    exec ssh 167.235.134.147 "$@"
  '';
}
