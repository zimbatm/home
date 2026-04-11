{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "now-context";
  runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils ];
  text = ''
    # Stateless probe of local ActivityWatch (127.0.0.1:5600) → compact JSON
    # of current desktop state: AFK, focused window, last-15m app histogram.
    # Read-only over data nv1 already records (modules/home/desktop/activitywatch.nix);
    # feeds proactive agent prompts. Every step degrades to JSON error/null —
    # bounded latency, never hangs.
    #
    #   now-context  → {"afk":false,"focused":{...},"last_15m":[...]}

    aw="http://127.0.0.1:5600/api/0"
    die() { jq -cn --arg e "$1" '{error:$e}'; exit 0; }

    buckets=$(curl -fsS --max-time 2 "$aw/buckets/" 2>/dev/null) \
      || die "aw-server unreachable at :5600"

    # Discover by bucket type — robust to watcher-variant (X11/wayland) naming.
    afk_b=$(jq -r 'to_entries|map(select(.value.type=="afkstatus"))[0].key // empty' <<<"$buckets")
    win_b=$(jq -r 'to_entries|map(select(.value.type=="currentwindow"))[0].key // empty' <<<"$buckets")
    [[ -n "$win_b" ]] || die "no currentwindow bucket (watcher not running?)"

    afk=false
    if [[ -n "$afk_b" ]]; then
      afk=$(curl -fsS --max-time 2 "$aw/buckets/$afk_b/events?limit=1" 2>/dev/null \
        | jq -r 'if (.[0].data.status // "not-afk")=="afk" then "true" else "false" end' \
        2>/dev/null || echo false)
    fi

    # Focused window = latest currentwindow event; .duration is seconds-in-focus
    # (heartbeat-updated at poll_time=1s, so ≤1s stale).
    focused=$(curl -fsS --max-time 2 "$aw/buckets/$win_b/events?limit=1" 2>/dev/null \
      | jq -c '.[0] // null
               | if .==null then null
                 else {app:(.data.app // ""), title:(.data.title // ""),
                       since_s:((.duration // 0)|floor)} end' \
      2>/dev/null || echo null)

    # Last-15m histogram via AW query language: merge by (app,title), sort, top 10.
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    ago=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
    q="events = query_bucket('$win_b'); RETURN = sort_by_duration(merge_events_by_keys(events, ['app','title']));"
    last_15m=$(curl -fsS --max-time 3 -XPOST "$aw/query/" \
        -H 'content-type: application/json' \
        --data "$(jq -cn --arg t "$ago/$now" --arg q "$q" '{timeperiods:[$t],query:[$q]}')" \
        2>/dev/null \
      | jq -c '.[0] // []
               | map({app:(.data.app // ""), title:(.data.title // ""), s:(.duration|floor)})
               | .[0:10]' \
      2>/dev/null || echo '[]')

    jq -cn --argjson afk "$afk" --argjson focused "$focused" --argjson last_15m "$last_15m" \
      '{afk:$afk, focused:$focused, last_15m:$last_15m}'
  '';
}
