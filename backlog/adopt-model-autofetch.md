# adopt-model-autofetch

## what

Replace the "model not found → print curl hint → exit 1" pattern with a shared
`fetch-or-die` helper that auto-fetches on first run (with progress), then
execs. Keep the hint as the fallback when fetch fails (offline / 404).

Affected (the 7 simplifier flagged as "model-not-found hint 8×/7"):
- `packages/ask-local` — Phi-3-mini Q4_K_M (~2.4GB)
- `packages/say-back` — piper en_US-lessac-medium (~60MB, 2 files)
- `packages/ptt-dictate` — whisper.cpp ggml-base.en (~140MB)
- `packages/agent-eyes` — moondream2 text+mmproj (~3GB, 2 files)
- (`wake-listen`, `transcribe-npu` already FOD'd in 94cf5c6 — skip)
- audit `packages/` for any others

## why

User hit the hint on first `ask-local` run post-deploy and asked for it.
Hints are friction; the URL+dest are fully known, so just do the fetch.

## how-much

One shared helper in `packages/lib/fetch-model.sh` (or a nix `writeShellApplication`
exported from `packages/default.nix`):
```sh
fetch_model() {  # dest url [url2 dest2 ...]
  local dest="$1" url="$2"
  [ -f "$dest" ] && return 0
  mkdir -p "$(dirname "$dest")"
  echo "$(basename "$0"): fetching $(basename "$dest") (~first run)..." >&2
  curl -fL --progress-bar -o "$dest.part" "$url" && mv "$dest.part" "$dest" || {
    rm -f "$dest.part"
    echo "$(basename "$0"): fetch failed; manual: curl -L -o '$dest' '$url'" >&2
    return 1
  }
}
```
Each package's wrapper sources it and calls `fetch_model "$MODEL" "$URL"` instead
of the echo block. Keep the `ASK_LOCAL_MODEL` / `*_MODEL` env override.

Also: `mkdir -p` the holding dir unconditionally in each wrapper (cheap, makes
the printed hint copy-pasteable even when autofetch is bypassed).

## blockers

None. nv1-only closure change (all 4 are home-manager packages).
Gate: all 3 hosts eval+dry-build; nv1 is the only one that references these.

## not-in-scope

- Converting these to FODs (2–4GB store paths; deliberate non-FOD per
  wake-listen precedent split: small+system→FOD, large+user→XDG fetch)
- Checksum verification (HF URLs are content-addressed by repo+filename;
  can add `--fail` + size check if paranoid, file separately)
