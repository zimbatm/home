{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "say-back";
  runtimeInputs = [
    pkgs.piper-tts
    pkgs.pipewire
    pkgs.coreutils
  ];
  text = ''
    # Read text from stdin, synthesise with piper (CPU-only, no Arc/NPU
    # contention), play via pipewire. Closes the ptt-dictate voice loop.
    MODEL="''${SAY_BACK_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/piper/en_US-lessac-medium.onnx}"

    if [[ ! -f "$MODEL" ]]; then
      echo "say-back: model not found: $MODEL" >&2
      echo "  fetch: mkdir -p \"$(dirname "$MODEL")\" && \\" >&2
      echo "    curl -L -o \"$MODEL\" https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx && \\" >&2
      echo "    curl -L -o \"$MODEL.json\" https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json" >&2
      exit 1
    fi

    piper --model "$MODEL" --output-raw 2>/dev/null \
      | pw-play --rate 22050 --channels 1 --format s16 -
  '';
}
