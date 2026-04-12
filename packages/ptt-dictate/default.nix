{ pkgs, ... }:
let
  whisper = pkgs.whisper-cpp.override { vulkanSupport = true; };
  transcribe-npu = pkgs.callPackage ../transcribe-npu { };
in
pkgs.writeShellApplication {
  name = "ptt-dictate";
  runtimeInputs = [ whisper transcribe-npu pkgs.pipewire pkgs.ydotool pkgs.coreutils ];
  text = ''
    # Toggle push-to-talk: first call starts recording, second call stops
    # and types the transcription via ydotool. Bind to a single hotkey.
    STATE="''${XDG_RUNTIME_DIR:-/tmp}/ptt-dictate"
    MODEL="''${PTT_DICTATE_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/whisper/ggml-base.en.bin}"
    mkdir -p "$STATE"

    if [[ -f "$STATE/pid" ]] && kill -0 "$(cat "$STATE/pid")" 2>/dev/null; then
      kill "$(cat "$STATE/pid")"
      exit 0
    fi

    if [[ ! -f "$MODEL" ]]; then
      echo "ptt-dictate: model not found: $MODEL" >&2
      echo "  fetch: mkdir -p \"$(dirname "$MODEL")\" && \\" >&2
      echo "    curl -L -o \"$MODEL\" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" >&2
      exit 1
    fi

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
    [[ -n "$TEXT" ]] && ydotool type -- "$TEXT"
  '';
}
