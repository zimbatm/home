{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "core";
  runtimeInputs = [ pkgs.openssh ];
  text = ''
    if [[ $# -eq 0 ]]; then
      exec ssh -t 167.235.134.147 "TERM=xterm-256color tmux new-session -A -s main"
    else
      exec ssh 167.235.134.147 "$@"
    fi
  '';
}
