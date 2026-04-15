# adopt: lookup-decode — prompt-lookup speculative decoding for ask-local

## What

`ask-local --fast` (and on by default for `--grammar`): pass llama.cpp's
prompt-lookup decoding flags (`--lookup-cache-dynamic`, draft n-gram
from prompt+prior output — no second model file). Same Phi-3-mini Q4 on
Arc vulkan; the only change is flag plumbing in the writeShellApplication.

## Why (seed → our angle)

**Seed:** llama.cpp upstream ships three draft modes (draft-model,
self-spec, prompt-lookup). Published 2–3× speedups are all CUDA
big-GPU. llm-agents.nix users (crush, opencode, etc.) hit cloud APIs
so don't care; local-inference dotfiles mostly leave it off.

**Our angle:** ask-local's hottest path is `ptt-dictate --intent` —
GBNF-constrained JSON classification where the output entropy is near
zero (grammar forces `{"intent":"<enum>","arg":"..."}`). Prompt-lookup
acceptance rate should be very high under a grammar because the next
tokens are largely determined. Nobody benchmarks **lookup-decode ×
constrained-grammar on an iGPU vulkan backend** — that's the
Meteor-Lake-specific question, and it decides whether the voice-intent
round-trip drops from "noticeable pause" to "instant."

## Falsifies

1. **Grammar boosts draft acceptance** — measure tok/s on Arc vulkan
   for the intent GBNF with lookup on/off vs free-form prompt with
   lookup on/off. Hypothesis: grammar+lookup ≫ grammar alone ≫
   free+lookup. If grammar+lookup ≈ grammar alone, the iGPU is
   compute-bound not bandwidth-bound and the whole draft premise is
   dead on this hardware.
2. **sel-act / voice-intent wall-clock** — end-to-end Super+d → typed
   output, before/after. <300 ms target from adopt-voice-intent stands.

## How much

~0.2r. Flag plumbing in `packages/ask-local/default.nix` + a 4-case
bench script under `packages/ask-local/bench.sh`. Zero new models,
zero new deps, no flake.lock touch.

## Blockers

Verify the nixpkgs `llama-cpp` build exposes the lookup flags (they're
in `examples/lookup` upstream — may need `-DLLAMA_BUILD_EXAMPLES=ON`
or already on via `llama-cli`). If absent: override is one line.
Measurement gated on ops-deploy-nv1.
