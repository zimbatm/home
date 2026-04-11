# adopt: ask-local — llama.cpp on Intel Arc, same vulkan path as ptt-dictate

## What

`packages/ask-local`: `llama-cpp.override { vulkanSupport = true; }`
plus a thin `ask-local` wrapper that runs a quantized ~3B model
(Phi-3-mini or Gemma-2-2B, Q4_K_M) for one-shot offline prompts.
Mirror ptt-dictate's shape exactly: model lives under
`$XDG_DATA_HOME/llama/`, wrapper prints the `curl` fetch line if
missing. Optional: `ask-local --serve` starts `llama-server` on
localhost for tools wanting an OpenAI-compatible fallback.

## Why

The nv1 memory names "local inference" as an explicit LLM-future axis,
but the RTX 4060 is vfio-bound — host-side inference must use the
Intel Arc iGPU. ptt-dictate already proved whisper-cpp+vulkan works on
that GPU; llama.cpp's vulkan backend matured through 2025 and is the
same code path. Nobody in the surveyed dotfiles runs local LLM on an
*iGPU* — that's our angle: prove (or kill) the idea that Meteor Lake
Arc is enough for a useful always-available small model, no dGPU and
no network needed.

## How much

~0.4r. The override is one line (nixpkgs `llama-cpp` already has
`vulkanSupport ? false`); wrapper is ~25 lines cribbed from
ptt-dictate's structure. Gate: dry-build on nv1; runtime tok/s
measurement is needs-human.

## Falsifies

Whether Meteor Lake Arc sustains ≥15 tok/s on a 3B Q4 model. Below
that, interactive use is dead and the conclusion is "host-side gen-AI
on nv1 needs the NVIDIA back from vfio, or the NPU via OpenVINO
GenAI" — which would feed directly into reconsidering the vfio split.

## Blockers

None for build. `intel-compute-runtime` is already in
`hardware.graphics.extraPackages` on nv1, and vulkan works (ptt-dictate
uses it). Model download + tok/s bench → needs-human post-deploy.
