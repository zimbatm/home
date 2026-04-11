{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "pty-puppet";
  runtimeInputs = [ pkgs.tmux pkgs.coreutils pkgs.gnugrep ];
  text = ''
    # Session-keyed expect/send for agents driving TUIs (nmtui, gdisk, nix repl).
    # Backend = tmux -L pty-puppet (auto-spawns, auto-dies; no extra daemon).

    usage() {
      cat >&2 <<'EOF'
    pty-puppet @<name> spawn <cmd...>                  start a pty session
    pty-puppet @<name> snap                            dump current screen text
    pty-puppet @<name> send <keys...>                  send keys (no auto-Enter)
    pty-puppet @<name> expect <regex> [--timeout SEC]  wait for regex (default 10s)
    pty-puppet @<name> kill                            terminate session
    EOF
      exit 2
    }

    [[ $# -ge 2 ]] || usage
    name="''${1#@}"; shift
    verb="$1"; shift

    t() { tmux -L pty-puppet -f /dev/null "$@"; }

    case "$verb" in
      spawn)
        [[ $# -ge 1 ]] || usage
        t new-session -d -s "$name" -- "$@"
        ;;
      snap)
        t capture-pane -pt "$name"
        ;;
      send)
        [[ $# -ge 1 ]] || usage
        t send-keys -t "$name" -- "$@"
        ;;
      expect)
        [[ $# -ge 1 ]] || usage
        regex="$1"; shift
        timeout=10
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --timeout) timeout="$2"; shift 2 ;;
            *) usage ;;
          esac
        done
        end=$((SECONDS + timeout))
        while :; do
          screen=$(t capture-pane -pt "$name") || {
            echo "pty-puppet: session @$name not found" >&2
            exit 1
          }
          if grep -qE -- "$regex" <<<"$screen"; then
            exit 0
          fi
          if [[ $SECONDS -ge $end ]]; then
            echo "pty-puppet: timeout after ''${timeout}s waiting for: $regex" >&2
            exit 1
          fi
          sleep 0.2
        done
        ;;
      kill)
        t kill-session -t "$name"
        ;;
      *)
        usage
        ;;
    esac
  '';
}
