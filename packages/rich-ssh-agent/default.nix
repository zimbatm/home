{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "rich-ssh-agent";
  runtimeInputs = [
    pkgs.libnotify
    pkgs.zenity
  ];
  text = ''
    exec ${pkgs.python3}/bin/python3 ${./rich-ssh-agent.py} "$@"
  '';
}
