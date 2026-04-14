# bug: wake-listen + transcribe-npu expect runtime-fetched models — ship as FODs

## What

`wake-listen.service` crash-looping at **restart counter 721** on nv1
(2026-04-14 23:14):
```
wake-listen: model not found: /home/zimbatm/.local/share/openvino/silero_vad.onnx
  fetch: ... curl -L -o ... https://github.com/snakers4/silero-vad/raw/v5.1/src/silero_vad/data/silero_vad.onnx
```

Both `packages/wake-listen/default.nix:25-37` and
`packages/transcribe-npu/default.nix:24-31` expect the user to manually
fetch OpenVINO models to `~/.local/share/openvino/` and exit 1 with a
"here's the curl/hf-cli command" message otherwise. For a systemd
service that means infinite restart-loop until someone reads the
journal.

## Fix

Ship models as fixed-output derivations so they're in the closure:

```nix
# packages/wake-listen/default.nix
let
  silero-vad = pkgs.fetchurl {
    url = "https://github.com/snakers4/silero-vad/raw/v5.1/src/silero_vad/data/silero_vad.onnx";
    hash = "sha256-…";  # nix-prefetch-url
  };
in
  …
  MODEL="''${WAKE_LISTEN_MODEL:-${silero-vad}}"
```

For transcribe-npu's whisper-base.en (multi-file HF repo), use
`pkgs.fetchFromHuggingFace` or a `fetchzip` of the resolve URL; pin the
revision. ~150 MB — acceptable for an nv1-only closure that already
carries CUDA llama.

Until both land, also add `ConditionPathExists=` on the model path to
the systemd units so they go `inactive (dead)` instead of restart-looping
when the model is absent.

## How much

~0.3r. silero_vad is one fetchurl + one line. whisper-base.en needs the
right fetcher + hash. ConditionPathExists is 1 line × 2 units.

## Blockers

None. The hashes need network to prefetch once.
