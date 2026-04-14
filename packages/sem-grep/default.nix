{ pkgs, ... }:
let
  # Subset of transcribe-npu's closure (openvino+numpy+transformers) — no new
  # python deps land on nv1. sqlite3 is stdlib.
  py = pkgs.python3.withPackages (ps: [
    ps.openvino
    ps.numpy
    ps.transformers
  ]);
in
pkgs.writeShellApplication {
  name = "sem-grep";
  runtimeInputs = [
    py
    pkgs.git
    pkgs.coreutils
  ];
  text = ''
    # Semantic grep over the assise repos via a tiny embedding model resident
    # on the Meteor Lake NPU. Index: git-tracked text in ~/src/{home,kin,iets,
    # maille,meta} → chunked → sqlite+blob at $XDG_STATE_HOME/sem-grep. Query:
    # brute-force cosine over the blobs (no faiss; corpus is ~2k files). Reuses
    # transcribe-npu's OpenVINO closure so the Arc iGPU stays free for ask-local.
    #
    #   sem-grep "<query>"       → ranked file:line hits (top 10)
    #   sem-grep -n 20 "<query>" → top N
    #   sem-grep index           → (re)build; incremental on git blob-sha
    #   sem-grep hist "<query>"  → ranked shell-history commands (hist-sem alias)
    #
    # Model: bge-small-en-v1.5 OpenVINO IR (~130 MB, 384-dim) under XDG_DATA_HOME.
    MODEL="''${SEM_GREP_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/openvino/bge-small-en-v1.5}"
    DEVICE="''${SEM_GREP_DEVICE:-NPU}"
    STATE="''${SEM_GREP_STATE:-''${XDG_STATE_HOME:-$HOME/.local/state}/sem-grep}"
    REPOS="''${SEM_GREP_REPOS:-$HOME/src/home:$HOME/src/kin:$HOME/src/iets:$HOME/src/maille:$HOME/src/meta}"

    if [[ ! -f "$MODEL/openvino_model.xml" ]]; then
      echo "sem-grep: model not found: $MODEL" >&2
      echo "  fetch: mkdir -p \"$MODEL\" && \\" >&2
      echo "    huggingface-cli download OpenVINO/bge-small-en-v1.5-fp16-ov --local-dir \"$MODEL\"" >&2
      exit 1
    fi

    export SEM_GREP_MODEL="$MODEL" SEM_GREP_DEVICE="$DEVICE" \
           SEM_GREP_STATE="$STATE" SEM_GREP_REPOS="$REPOS"
    exec python3 ${./sem-grep.py} "$@"
  '';
}
