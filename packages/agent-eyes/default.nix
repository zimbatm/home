{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "peek";
  runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.coreutils ];
  text = ''
    # Capture the Wayland screen (or a region via --region) to a temp PNG and
    # print its path so the agent can Read the image. No daemon, no state.
    out=$(mktemp --suffix=.png -p "''${XDG_RUNTIME_DIR:-/tmp}")
    if [[ "''${1:-}" == "--region" ]]; then
      grim -g "$(slurp)" "$out"
    else
      grim "$out"
    fi
    echo "$out"
  '';
}
