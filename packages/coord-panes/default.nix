{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "coord-panes";
  runtimeInputs = [
    pkgs.tmux
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gawk
  ];
  text = ''
    # Spawn sibling Claude sessions in adjacent tmux panes and resolve their
    # peer-bus addresses. tmux is the supervisor; ListPeers/SendMessage is the
    # queue. Falsifies whether workmux's lock/queue layer is load-bearing for a
    # single-user desktop — see backlog/adopt-coord-panes.md.
    #   coord-panes spawn <cwd> [<label>]   → split-window running claude, print "uds:/... <pane_id>"
    #   coord-panes ls                      → label  pane_id  uds-addr  cwd  (prunes dead)
    #   coord-panes kill <label|addr|pane>  → kill-pane, drop map entry

    map="''${XDG_RUNTIME_DIR:-/tmp}/coord-panes/map"
    mkdir -p "''${map%/*}"
    touch "$map"

    usage() {
      cat >&2 <<'EOF'
    coord-panes spawn <cwd> [<label>]       open a pane running claude in <cwd>, print uds-addr + pane_id
    coord-panes ls                          table of live panes (prunes dead entries)
    coord-panes kill <label|addr|pane_id>   close pane and drop mapping
    EOF
      exit 2
    }

    [[ $# -ge 1 ]] || usage
    verb="$1"; shift

    case "$verb" in
      spawn)
        [[ $# -ge 1 ]] || usage
        [[ -n "''${TMUX-}" ]] || { echo "coord-panes: spawn requires running inside tmux" >&2; exit 1; }
        cwd="$1"; label="''${2:-$(basename "$cwd")}"
        ide="$HOME/.claude/ide"
        before=$(ls "$ide"/*.sock 2>/dev/null || true)
        pane=$(tmux split-window -c "$cwd" -P -F '#{pane_id}' -- claude --permission-mode acceptEdits)
        end=$((SECONDS + 10)); addr=""
        while [[ $SECONDS -lt $end ]]; do
          for s in "$ide"/*.sock; do
            [[ -S "$s" ]] || continue
            grep -qxF "$s" <<<"$before" && continue
            addr="uds:$s"; break 2
          done
          sleep 0.25
        done
        [[ -n "$addr" ]] || { echo "coord-panes: no new socket in $ide within 10s" >&2; tmux kill-pane -t "$pane"; exit 1; }
        grep -v "^$label " "$map" > "$map.tmp" 2>/dev/null || true; mv "$map.tmp" "$map"
        printf '%s %s %s\n' "$label" "$pane" "$addr" >> "$map"
        printf '%s %s\n' "$addr" "$pane"
        ;;
      ls)
        live=$(tmux list-panes -a -F '#{pane_id} #{pane_current_path}' 2>/dev/null || true)
        : > "$map.tmp"
        while read -r label pane addr; do
          [[ -n "$label" ]] || continue
          cwd=$(awk -v p="$pane" '$1==p {print $2}' <<<"$live")
          [[ -n "$cwd" && -S "''${addr#uds:}" ]] || continue
          printf '%s\t%s\t%s\t%s\n' "$label" "$pane" "$addr" "$cwd"
          printf '%s %s %s\n' "$label" "$pane" "$addr" >> "$map.tmp"
        done < "$map"
        mv "$map.tmp" "$map"
        ;;
      kill)
        [[ $# -ge 1 ]] || usage
        key="$1"
        line=$(awk -v k="$key" '$1==k||$2==k||$3==k' "$map" | head -1)
        [[ -n "$line" ]] || { echo "coord-panes: no entry matching '$key'" >&2; exit 1; }
        pane=$(awk '{print $2}' <<<"$line")
        tmux kill-pane -t "$pane" 2>/dev/null || true
        grep -vxF "$line" "$map" > "$map.tmp" || true; mv "$map.tmp" "$map"
        ;;
      *)
        usage
        ;;
    esac
  '';
}
