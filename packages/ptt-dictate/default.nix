{ pkgs, ... }:
let
  whisper = pkgs.whisper-cpp.override { vulkanSupport = true; };
  transcribe-npu = pkgs.callPackage ../transcribe-npu { };
  ask-local = pkgs.callPackage ../ask-local { };
in
pkgs.writeShellApplication {
  name = "ptt-dictate";
  runtimeInputs = [
    whisper
    transcribe-npu
    ask-local
    pkgs.pipewire
    pkgs.ydotool
    pkgs.coreutils
    pkgs.curl
    pkgs.jq
    pkgs.yq-go
  ];
  text = ''
    # Toggle push-to-talk: first call starts recording, second call stops and
    # types the transcription via ydotool. Bind to a single hotkey.
    #   ptt-dictate            → record/stop, type transcript
    #   ptt-dictate --intent   → record/stop, classify via ask-local --grammar
    #                            against $XDG_CONFIG_HOME/voice-intent/intents.toml,
    #                            dispatch matched intent or fall through to type
    STATE="''${XDG_RUNTIME_DIR:-/tmp}/ptt-dictate"
    MODEL="''${PTT_DICTATE_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/whisper/ggml-base.en.bin}"
    mkdir -p "$STATE"

    intent=0
    [[ "''${1:-}" == "--intent" ]] && intent=1

    if [[ -f "$STATE/pid" ]] && kill -0 "$(cat "$STATE/pid")" 2>/dev/null; then
      kill "$(cat "$STATE/pid")"
      exit 0
    fi

    # shellcheck source=/dev/null
    . ${../lib/fetch-model.sh}
    fetch_model "$MODEL" \
      https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

    REC="$STATE/rec.wav"
    pw-record --rate 16000 --channels 1 "$REC" &
    echo $! > "$STATE/pid"
    wait || true
    rm -f "$STATE/pid"

    # Prefer the Meteor Lake NPU when present — frees the Arc iGPU for
    # ask-local so voice + local-LLM run concurrently. Fall back to the
    # whisper-cpp/vulkan path if the accel node is absent or the NPU run fails.
    if [[ -e /dev/accel/accel0 ]] && TEXT=$(transcribe-npu "$REC" 2>/dev/null); then
      :
    else
      TEXT=$(whisper-cli -m "$MODEL" -f "$REC" --no-timestamps --no-prints 2>/dev/null)
    fi
    TEXT=$(printf %s "$TEXT" | tr -d '\n' | sed 's/^ *//;s/ *$//')
    [[ -n "$TEXT" ]] || exit 0

    if [[ $intent -eq 0 ]]; then
      exec ydotool type -- "$TEXT"
    fi

    # --intent: GBNF-constrained classify → dispatch. Every failure path
    # degrades to the pre-intent behaviour (type the raw utterance).
    CFG="''${XDG_CONFIG_HOME:-$HOME/.config}/voice-intent/intents.toml"
    INTENTS=$(yq -p toml -o json "$CFG" 2>/dev/null) || INTENTS=""
    [[ -n "$INTENTS" ]] || exec ydotool type -- "$TEXT"

    # Grammar: force {"type":"<one-of-intents|text>","arg":"<no-ctrl-no-quote>"}.
    # Regenerated per call so user edits to intents.toml take effect immediately.
    alts=$(jq -r 'keys + ["text"] | unique | map("\"" + . + "\"") | join(" | ")' <<<"$INTENTS")
    GRAMMAR="$STATE/intent.gbnf"
    {
      printf '%s\n' 'root   ::= "{\"type\":\"" intent "\",\"arg\":\"" arg "\"}"'
      printf 'intent ::= %s\n' "$alts"
      printf '%s\n' 'arg    ::= [^"\\\x7f\x00-\x1f]*'
    } >"$GRAMMAR"

    names=$(jq -r 'keys | join(", ")' <<<"$INTENTS")
    t0=$(date +%s%3N)
    OUT=$(ask-local --grammar "$GRAMMAR" \
      "Classify the voice command into one of: $names. Use 'text' if none fit. Put any free-text argument in arg.
    Command: $TEXT
    JSON:" 2>/dev/null | head -c 512) || OUT=""
    t1=$(date +%s%3N)

    INTENT=$(jq -r '.type // "text"' 2>/dev/null <<<"$OUT" || echo text)
    ARG=$(jq -r '.arg // ""' 2>/dev/null <<<"$OUT" || true)

    LOG="''${XDG_STATE_HOME:-$HOME/.local/state}/voice-intent"
    mkdir -p "$LOG"
    jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg u "$TEXT" --arg i "$INTENT" \
      --argjson ms "$((t1 - t0))" '{ts:$ts, utterance:$u, intent:$i, latency_ms:$ms}' \
      >>"$LOG/decisions.jsonl"

    EXEC=$(jq -r --arg i "$INTENT" '.[$i].exec // empty' <<<"$INTENTS")
    if [[ -n "$EXEC" ]]; then
      # Intent targets (peek, say-back, now-context, ...) resolve from the
      # caller's PATH — writeShellApplication prepends runtimeInputs, so the
      # session profile is still visible.
      ARG_Q=$(printf %q "$ARG")
      exec bash -c "''${EXEC//\{arg\}/$ARG_Q}" </dev/null
    fi
    # text, fallthrough=true, or unmapped → type the raw utterance
    exec ydotool type -- "$TEXT"
  '';
}
