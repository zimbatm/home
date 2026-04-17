{ pkgs, ... }:
let
  llama = pkgs.llama-cpp.override { vulkanSupport = true; };

  peek = pkgs.writeShellApplication {
    name = "peek";
    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.coreutils
      pkgs.curl
      llama
    ];
    text = ''
      # Capture the Wayland screen (or a region via --region) to a temp PNG and
      # print its path so the agent can Read the image. No daemon, no state.
      #
      #   peek [--region]                      → print PNG path
      #   peek [--region] --ask "<question>"   → print short VLM answer
      #
      # --ask runs the capture through moondream2 (llama.cpp mtmd, vulkan on the
      # Arc iGPU) and prints a short stdout answer — local triage so the agent
      # can gate "do I need to ship this PNG upstream?" on-device. Mirrors
      # ask-local: same llama-cpp+vulkan build, model under XDG_DATA_HOME/llama,
      # auto-fetched on first run. Runs inline (not via infer-queue) on purpose:
      # falsifies whether the Arc has headroom for a second resident model
      # alongside ask-local's Phi-3, or the 1-slot arc lane was the right call.
      ask="" region=0
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --region) region=1; shift ;;
          --ask)    ask="''${2:?--ask needs a question}"; shift 2 ;;
          *)        echo "peek: unknown arg: $1" >&2; exit 1 ;;
        esac
      done

      out=$(mktemp --suffix=.png -p "''${XDG_RUNTIME_DIR:-/tmp}")
      if [[ $region -eq 1 ]]; then
        grim -g "$(slurp)" "$out"
      else
        grim "$out"
      fi

      if [[ -z "$ask" ]]; then
        echo "$out"
        exit 0
      fi

      # shellcheck source=/dev/null
      . ${../lib/fetch-model.sh}
      d="''${XDG_DATA_HOME:-$HOME/.local/share}/llama"
      MODEL="''${PEEK_ASK_MODEL:-$d/moondream2-text-model-f16.gguf}"
      MMPROJ="''${PEEK_ASK_MMPROJ:-$d/moondream2-mmproj-f16.gguf}"
      base=https://huggingface.co/vikhyatk/moondream2/resolve/main
      fetch_model "$MODEL"  "$base/moondream2-text-model-f16.gguf" || { rm -f "$out"; exit 1; }
      fetch_model "$MMPROJ" "$base/moondream2-mmproj-f16.gguf"     || { rm -f "$out"; exit 1; }

      exec llama-mtmd-cli -m "$MODEL" --mmproj "$MMPROJ" --image "$out" \
        -ngl 99 -n 128 --temp 0 -p "$ask" 2>/dev/null
    '';
  };

  poke = pkgs.writeShellApplication {
    name = "poke";
    runtimeInputs = [ pkgs.ydotool ];
    text = ''
      # Inject Wayland input via ydotool — act-side counterpart to peek.
      # Requires programs.ydotool.enable (uinput socket + group). No daemon, no state.
      #
      #   poke key 29:1 42:1 20:1 20:0 42:0 29:0   # ctrl+shift+t — raw keycodes,
      #                                            # see /usr/include/linux/input-event-codes.h
      #   poke type "nix flake check"
      #   poke click 840 612

      usage() {
        echo "usage: poke key <keycode:1|0>...   # raw, see input-event-codes.h" >&2
        echo "       poke type <text...>" >&2
        echo "       poke click <x> <y>" >&2
        exit 1
      }

      cmd="''${1:-}"; [[ $# -gt 0 ]] && shift
      case "$cmd" in
        key)
          [[ $# -gt 0 ]] || usage
          exec ydotool key "$@"
          ;;
        type)
          [[ $# -gt 0 ]] || usage
          exec ydotool type -- "$*"
          ;;
        click)
          [[ $# -eq 2 ]] || usage
          ydotool mousemove --absolute -x "$1" -y "$2"
          exec ydotool click 0xC0
          ;;
        *) usage ;;
      esac
    '';
  };
in
pkgs.symlinkJoin {
  name = "agent-eyes";
  paths = [
    peek
    poke
  ];
}
