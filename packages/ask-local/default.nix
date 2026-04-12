{ pkgs, ... }:
let
  llama = pkgs.llama-cpp.override { vulkanSupport = true; };
in
pkgs.writeShellApplication {
  name = "ask-local";
  runtimeInputs = [
    llama
    pkgs.coreutils
  ];
  text = ''
    # One-shot offline LLM on the Intel Arc iGPU (vulkan). Mirrors ptt-dictate:
    # model lives under XDG_DATA_HOME, wrapper prints the fetch line if missing.
    #   ask-local "<prompt>"   → llama-cli, prints completion to stdout
    #   ask-local --serve      → llama-server on 127.0.0.1:8088 (OpenAI-compat)
    MODEL="''${ASK_LOCAL_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/llama/Phi-3-mini-4k-instruct-Q4_K_M.gguf}"

    if [[ ! -f "$MODEL" ]]; then
      echo "ask-local: model not found: $MODEL" >&2
      echo "  fetch: mkdir -p \"$(dirname "$MODEL")\" && \\" >&2
      echo "    curl -L -o \"$MODEL\" https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf" >&2
      exit 1
    fi

    if [[ "''${1:-}" == "--serve" ]]; then
      exec llama-server -m "$MODEL" -ngl 99 --host 127.0.0.1 --port 8088
    fi

    exec llama-cli -m "$MODEL" -ngl 99 -p "$*" --no-display-prompt 2>/dev/null
  '';
}
