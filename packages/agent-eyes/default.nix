{ pkgs, ... }:
let
  peek = pkgs.writeShellApplication {
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
  };

  poke = pkgs.writeShellApplication {
    name = "poke";
    runtimeInputs = [ pkgs.ydotool ];
    text = ''
      # Inject Wayland input via ydotool — act-side counterpart to peek.
      # Requires programs.ydotool.enable (uinput socket + group). No daemon, no state.
      #
      #   poke key 29:1 42:1 20:1 20:0 42:0 29:0   # ctrl+shift+t — raw keycodes,
      #                                            # see /usr/include/linux/input-event-codes.h
      #   poke type "nix flake check"
      #   poke click 840 612

      usage() {
        echo "usage: poke key <keycode:1|0>...   # raw, see input-event-codes.h" >&2
        echo "       poke type <text...>" >&2
        echo "       poke click <x> <y>" >&2
        exit 1
      }

      cmd="''${1:-}"; [[ $# -gt 0 ]] && shift
      case "$cmd" in
        key)
          [[ $# -gt 0 ]] || usage
          exec ydotool key "$@"
          ;;
        type)
          [[ $# -gt 0 ]] || usage
          exec ydotool type -- "$*"
          ;;
        click)
          [[ $# -eq 2 ]] || usage
          ydotool mousemove --absolute -x "$1" -y "$2"
          exec ydotool click 0xC0
          ;;
        *) usage ;;
      esac
    '';
  };
in
pkgs.symlinkJoin {
  name = "agent-eyes";
  paths = [ peek poke ];
}
