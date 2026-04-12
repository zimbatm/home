{ pkgs, ... }:
let
  infer-queue = pkgs.callPackage ../infer-queue { };
  transcribe-npu = pkgs.callPackage ../transcribe-npu { };
in
pkgs.writeShellApplication {
  name = "live-caption-log";
  runtimeInputs = [
    infer-queue
    transcribe-npu
    pkgs.pipewire
    pkgs.coreutils
    pkgs.gnused
    pkgs.jq
    pkgs.libnotify
  ];
  text = ''
    # System audio → rolling NPU transcript → jsonl. Taps the PipeWire sink
    # monitor in ~8s chunks, hands each to transcribe-npu via the npu lane of
    # infer-queue (so sem-grep/ask-local contention is observable, not hidden),
    # and appends {ts,text,source} to $XDG_STATE_HOME/live-caption/YYYY-MM-DD.jsonl.
    # The jsonl is the point — a nightly timer (modules/home/desktop/live-caption.nix)
    # folds it into the sem-grep corpus. Overlay is optional polish.
    #
    #   live-caption-log            → loop forever (systemd --user unit)
    #   live-caption-log --overlay  → also toast last line (notify-send -r, -t 0)
    #
    # v1 execs transcribe-npu per chunk. NPU model-load cost is the open
    # question: if an 8s chunk takes ≥8s wall-clock the fix is a transcribe-npu
    # --serve mode; if the 1-slot npu lane starves under contention that's an
    # infer-queue priority bug — file there, not here (backlog Falsifies).
    STATE="''${XDG_STATE_HOME:-$HOME/.local/state}/live-caption"
    RUN="''${XDG_RUNTIME_DIR:-/tmp}/live-caption"
    SOURCE="''${LIVE_CAPTION_SOURCE:-@DEFAULT_AUDIO_SINK@.monitor}"
    CHUNK_S="''${LIVE_CAPTION_CHUNK_S:-8}"
    mkdir -p "$STATE" "$RUN"

    overlay=0
    [[ "''${1:-}" == "--overlay" ]] && overlay=1
    NID=$(( $$ % 100000 + 800000 ))
    TNPU=$(command -v transcribe-npu)
    # shellcheck disable=SC2064
    trap "rm -f '$RUN'/chunk-*.wav '$RUN'/chunk-*.txt" EXIT

    prev=""; prev_ts=""; n=0
    while :; do
      cur="$RUN/chunk-$((n % 2)).wav"
      rm -f "$cur"
      timeout "$CHUNK_S" pw-record --rate 16000 --channels 1 \
        --target "$SOURCE" "$cur" 2>/dev/null &
      rec=$!

      # Drain the previous chunk while the current one records (double-buffer).
      if [[ -n "$prev" && -s "$prev" ]]; then
        out="$prev.txt"; : >"$out"
        job=$(infer-queue add --lane npu -- \
                /bin/sh -c "exec '$TNPU' '$prev' >'$out' 2>/dev/null")
        if [[ $job =~ id\ ([0-9]+) ]]; then
          infer-queue wait "''${BASH_REMATCH[1]}" >/dev/null 2>&1 || true
        else
          "$TNPU" "$prev" >"$out" 2>/dev/null || true  # pueued down → inline
        fi
        text=$(tr -d '\r\n' <"$out" | sed 's/^ *//;s/ *$//')
        if [[ -n "$text" ]]; then
          jq -cn --arg ts "$prev_ts" --arg text "$text" --arg src "$SOURCE" \
            '{ts:$ts, text:$text, source:$src}' \
            >>"$STATE/$(date -u +%F).jsonl"
          if [[ $overlay -eq 1 ]]; then
            notify-send -r "$NID" -t 0 -a live-caption " " "$text" || true
          fi
        fi
      fi

      wait "$rec" || true
      prev="$cur"; prev_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ); n=$((n + 1))
    done
  '';
}
