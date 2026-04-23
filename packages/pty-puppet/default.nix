{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "pty-puppet";
  runtimeInputs = [
    pkgs.tmux
    pkgs.coreutils
    pkgs.gnugrep
  ];
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
    pty-puppet @<name> record <file>                   tee subsequent send/expect into
                                                       <file> as a replayable script
                                                       (spawn header from live cmdline)
    pty-puppet replay <file>                           bash -eo pipefail <file>;
                                                       non-zero on first expect miss
    EOF
      exit 2
    }

    [[ $# -ge 2 ]] || usage

    # replay has no session — handle before @<name> parse
    if [[ "$1" == "replay" ]]; then
      exec bash -eo pipefail "$2"
    fi

    name="''${1#@}"; shift
    verb="$1"; shift

    t() { tmux -L pty-puppet -f /dev/null "$@"; }

    # If `record` is active on this session, tee the call into the script.
    rec=$(t show-option -t "$name" -qv @rec 2>/dev/null || true)
    log() {
      [[ -n "$rec" ]] || return 0
      {
        printf 'pty-puppet @%s %s' "$name" "$1"
        shift
        [[ $# -eq 0 ]] || printf ' %q' "$@"
        printf '\n'
      } >>"$rec"
    }

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
        log send "$@"
        t send-keys -t "$name" -- "$@"
        ;;
      expect)
        [[ $# -ge 1 ]] || usage
        log expect "$@"
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
      record)
        [[ $# -ge 1 ]] || usage
        rec="$1"
        # Spawn header from the live session's command — what `replay` re-runs.
        cmd=$(t display-message -p -t "$name" '#{pane_start_command}') || {
          echo "pty-puppet: session @$name not found" >&2; exit 1
        }
        t set-option -t "$name" @rec "$rec"
        printf '#!/usr/bin/env bash\n' >"$rec"
        # shellcheck disable=SC2016 # literal trap in the emitted script
        printf "trap 'pty-puppet @%s kill 2>/dev/null || true' EXIT\n" "$name" >>"$rec"
        printf 'pty-puppet @%s spawn %s\n' "$name" "$cmd" >>"$rec"
        chmod +x "$rec"
        ;;
      kill)
        log kill
        t kill-session -t "$name"
        ;;
      *)
        usage
        ;;
    esac
  '';
}
