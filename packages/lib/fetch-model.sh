# shellcheck shell=bash
# Shared first-run model autofetch helpers. Sourced by the user-scoped (non-FOD,
# XDG_DATA_HOME) model wrappers — large weights stay out of the nix store but
# land automatically on first invocation instead of printing a curl hint and
# dying. Small/system models go the FOD route instead (see wake-listen).

# fetch_model DEST URL
#   If DEST is missing, curl URL → DEST atomically (.part + mv) with a progress
#   bar. On failure, clean up and print the manual curl line as a copy-pasteable
#   fallback (offline / 404), then return 1 so `set -e` callers exit.
fetch_model() {
  local dest="$1" url="$2"
  if [[ -f "$dest" ]]; then return 0; fi
  mkdir -p "$(dirname "$dest")"
  echo "$(basename "$0"): fetching $(basename "$dest") (first run)..." >&2
  if curl -fL --progress-bar -o "$dest.part" "$url" && mv "$dest.part" "$dest"; then
    return 0
  fi
  rm -f "$dest.part"
  echo "$(basename "$0"): fetch failed; manual: curl -L -o '$dest' '$url'" >&2
  return 1
}

# fetch_hf_repo DEST REPO
#   Multi-file variant for HF model repos (OpenVINO IR etc.) via huggingface-cli.
#   Presence gate is "$DEST/openvino_model.xml" — the only multi-file consumers
#   today are OV IR; generalise the sentinel if that changes.
fetch_hf_repo() {
  local dest="$1" repo="$2"
  if [[ -f "$dest/openvino_model.xml" ]]; then return 0; fi
  mkdir -p "$dest"
  echo "$(basename "$0"): fetching $repo (first run)..." >&2
  if huggingface-cli download "$repo" --local-dir "$dest" >&2; then
    return 0
  fi
  echo "$(basename "$0"): fetch failed; manual: huggingface-cli download '$repo' --local-dir '$dest'" >&2
  return 1
}
