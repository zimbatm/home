{ pkgs, ... }:
let
  # vulkanSupport for the Arc iGPU. LLAMA_BUILD_EXAMPLES gets us llama-lookup
  # (prompt-lookup n-gram speculative decoding); nixpkgs disables examples by
  # default and llama-cli at b8667 gates -lcd/--spec-type to {LOOKUP,SERVER}
  # only, so the one-shot lookup path needs the separate binary.
  llama = (pkgs.llama-cpp.override { vulkanSupport = true; }).overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DLLAMA_BUILD_EXAMPLES=ON" ];
  });
in
pkgs.writeShellApplication {
  name = "ask-local";
  runtimeInputs = [
    llama
    pkgs.coreutils
    pkgs.python3
  ];
  text = ''
    # One-shot offline LLM on the Intel Arc iGPU (vulkan). Mirrors ptt-dictate:
    # model lives under XDG_DATA_HOME, wrapper prints the fetch line if missing.
    #   ask-local "<prompt>"                  → llama-cli, prints completion to stdout
    #   ask-local --grammar <gbnf> "<prompt>" → constrained decoding (used by
    #                                           ptt-dictate --intent for JSON-only output)
    #   ask-local --fast [...] "<prompt>"     → llama-lookup: prompt-lookup n-gram
    #                                           speculative decoding, no draft model.
    #                                           Dynamic n-gram cache persists under
    #                                           XDG_CACHE_HOME so repeated prompt
    #                                           templates (intent classify) compound.
    #                                           NB: llama-lookup echoes the prompt on
    #                                           stdout (--no-display-prompt is gated to
    #                                           CLI/COMPLETION upstream); callers must
    #                                           strip. See bench.sh for the 4-case
    #                                           grammar×lookup tok/s matrix.
    #   ask-local --serve                     → llama-server on 127.0.0.1:8088 (OpenAI-compat),
    #                                           with n-gram lookup decoding always on.
    #   ask-local --agent "<goal>"            → bounded ReAct loop: GBNF-forced JSON tool
    #                                           calls over packages/ CLIs (tools.json),
    #                                           ≤4 turns. See bench-agent.jsonl.
    MODEL="''${ASK_LOCAL_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/llama/Phi-3-mini-4k-instruct-Q4_K_M.gguf}"

    if [[ ! -f "$MODEL" ]]; then
      echo "ask-local: model not found: $MODEL" >&2
      echo "  fetch: mkdir -p \"$(dirname "$MODEL")\" && \\" >&2
      echo "    curl -L -o \"$MODEL\" https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf" >&2
      exit 1
    fi

    CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/ask-local"
    mkdir -p "$CACHE"

    if [[ "''${1:-}" == "--agent" ]]; then
      shift
      export ASK_LOCAL_BIN="$0"
      export ASK_LOCAL_TOOLS="''${ASK_LOCAL_TOOLS:-${./tools.json}}"
      exec python3 ${./agent.py} "$@"
    fi

    if [[ "''${1:-}" == "--serve" ]]; then
      # Server exposes prompt-lookup cleanly (no echo issue); enable unconditionally.
      exec llama-server -m "$MODEL" -ngl 99 --host 127.0.0.1 --port 8088 \
        -lcd "$CACHE/lookup.ngram" --spec-type ngram-cache --draft-max 16
    fi

    fast=''${ASK_LOCAL_LOOKUP:-0}
    extra=()
    while true; do
      case "''${1:-}" in
        --fast) fast=1; shift ;;
        --grammar)
          [[ $# -ge 2 ]] || { echo "ask-local: --grammar needs a file" >&2; exit 2; }
          extra+=(--grammar-file "$2" -n 128); shift 2 ;;
        *) break ;;
      esac
    done

    # --grammar does NOT auto-enable --fast yet: llama-lookup has no
    # --no-display-prompt, so the echoed prompt would break ptt-dictate's jq
    # parse. Flip after bench.sh confirms grammar×lookup ≫ grammar-alone on Arc
    # vulkan AND a strip is in place (or upstream gates the flag to LOOKUP).
    if [[ $fast -eq 1 ]]; then
      exec llama-lookup -m "$MODEL" -ngl 99 "''${extra[@]}" \
        -lcd "$CACHE/lookup.ngram" --draft-max 16 --color off -p "$*" 2>/dev/null
    fi

    exec llama-cli -m "$MODEL" -ngl 99 "''${extra[@]}" -p "$*" --no-display-prompt 2>/dev/null
  '';
}
