{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "say-back";
  runtimeInputs = [
    pkgs.piper-tts
    pkgs.pipewire
    pkgs.coreutils
    pkgs.curl
  ];
  text = ''
    # Read text from stdin, synthesise with piper (CPU-only, no Arc/NPU
    # contention), play via pipewire. Closes the ptt-dictate voice loop.
    # shellcheck source=/dev/null
    . ${../lib/fetch-model.sh}
    MODEL="''${SAY_BACK_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/piper/en_US-lessac-medium.onnx}"
    base=https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium
    fetch_model "$MODEL"      "$base/en_US-lessac-medium.onnx"
    fetch_model "$MODEL.json" "$base/en_US-lessac-medium.onnx.json"

    piper --model "$MODEL" --output-raw 2>/dev/null \
      | pw-play --rate 22050 --channels 1 --format s16 -
  '';
}
