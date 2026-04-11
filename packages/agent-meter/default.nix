{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "agent-meter";
  runtimeInputs = [
    pkgs.jq
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gnused
    pkgs.intel-gpu-tools
    pkgs.pueue
  ];
  text = ''
    # Hybrid spend/occupancy gauge for nv1: Claude API tokens (ccusage-style
    # jsonl scrape) next to local-compute dials (Arc engine busy %, NPU busy %,
    # infer-queue lane depth). Tests whether ask-local/infer-queue actually move
    # the API number. Every probe degrades to '-' on failure — bounded latency,
    # never hangs the prompt.
    #
    #   agent-meter           → aligned table
    #   agent-meter --line    → terse one-liner for starship/PS1

    fmt_k() { awk '{ if ($1>=1000) printf "%.1fk", $1/1000; else printf "%d", $1 }' <<<"''${1:-0}"; }

    api_spend() {
      # Sum usage blocks from claude jsonl transcripts newer than $1 days.
      local days="$1" dirs=()
      [[ -d "$HOME/.claude" ]] && dirs+=("$HOME/.claude")
      [[ -d "''${XDG_CONFIG_HOME:-$HOME/.config}/claude" ]] && dirs+=("''${XDG_CONFIG_HOME:-$HOME/.config}/claude")
      [[ ''${#dirs[@]} -gt 0 ]] || { echo "-"; return; }
      { find "''${dirs[@]}" -name '*.jsonl' -mtime -"$days" -print0 2>/dev/null \
          | xargs -0r cat 2>/dev/null || true; } \
        | jq -rs 'map(select(.type=="assistant").message.usage // empty)
                  | "\(map(.input_tokens//0)|add//0) \(map(.output_tokens//0)|add//0) \(map(.cache_read_input_tokens//0)|add//0)"' \
        2>/dev/null || echo "-"
    }

    arc_busy() {
      # intel_gpu_top -J streams; grab the first complete object regardless of
      # whether the build wraps it in '[' or emits NDJSON.
      { timeout 2 intel_gpu_top -J -s 1000 2>/dev/null || true; } \
        | awk '/^\{/{p=1} p; /^\},?$/{exit}' | sed 's/,$//' \
        | jq -rs 'if length==0 then "-" else
                    .[0].engines // {} | to_entries
                    | map(select(.value.busy > 1) | "\(.key|split("/")[0]):\(.value.busy|floor)%")
                    | if length==0 then "idle" else join(" ") end
                  end' 2>/dev/null \
        || echo "-"
    }

    npu_busy() {
      local sysfs=/sys/class/accel/accel0/device/npu_busy_time_us a b
      [[ -r $sysfs ]] || { echo "-"; return; }
      a=$(<"$sysfs"); sleep 1; b=$(<"$sysfs")
      awk -v a="$a" -v b="$b" 'BEGIN{ printf "%d%%", (b-a)/10000 }'
    }

    queue_depth() {
      pueue status --json 2>/dev/null \
        | jq -r '.tasks | to_entries | group_by(.value.group)
                 | map({g: .[0].value.group,
                        r: (map(select(.value.status|objects|has("Running")))|length),
                        q: (map(select(.value.status|objects|has("Queued")))|length)})
                 | map("\(.g):\(.r)/\(.q)") | if length==0 then "idle" else join(" ") end' \
        2>/dev/null || echo "-"
    }

    today=$(api_spend 1); week=$(api_spend 7)
    arc=$(arc_busy); npu=$(npu_busy); q=$(queue_depth)

    api_line="-"
    if [[ "$today" != "-" ]]; then
      read -r ti to _ <<<"$today"
      api_line="$(fmt_k "$ti")in/$(fmt_k "$to")out today"
      if [[ "$week" != "-" ]]; then
        read -r _ wo wc <<<"$week"
        api_line+=" ($(fmt_k "$wo")out/$(fmt_k "$wc")cr 7d)"
      fi
    fi

    if [[ "''${1:-}" == "--line" ]]; then
      printf 'api %s │ arc %s │ npu %s │ q %s\n' "$api_line" "$arc" "$npu" "$q"
    else
      printf '%-6s %s\n' api   "$api_line"
      printf '%-6s %s\n' arc   "$arc"
      printf '%-6s %s\n' npu   "$npu"
      printf '%-6s %s\n' queue "$q"
    fi
  '';
}
