# adopt: parakeet ASR on the cpu lane — third dictation backend

## What

`packages/transcribe-cpu/`: sherpa-onnx (already in nixpkgs, 1.12.38)
+ parakeet-tdt-0.6b-v3 ONNX as a FOD, mirroring transcribe-npu's
shape. Wire as the consumer for infer-queue's existing-but-empty `cpu`
lane (default.nix:7 already declares `arc|npu|cpu`, nothing submits
ASR to `cpu`). Then `ptt-dictate --backend=auto` picks the lane with
the shallowest queue depth instead of hard-coding vulkan.

## Why (seed → our angle)

Seed: **Handy** (cjpais/Handy, handy.computer — new in llm-agents.nix)
ships Parakeet V3 alongside Whisper as its "CPU-optimized model with
excellent performance". Tauri GUI app, global-hotkey dictation.

Our angle: don't want Handy (Tauri+React, ~heavy, duplicates
ptt-dictate's job). But Parakeet is the piece worth lifting — NVIDIA
NeMo CTC model, faster-than-realtime on a single P-core, no GPU. Our
voice pipeline has two backends and both contend with LLM work:
whisper-cpp+vulkan (ptt-dictate) shares the Arc iGPU with ask-local's
Phi-3 + agent-eyes' moondream2; whisper-openvino (transcribe-npu)
shares the NPU with wake-listen's Silero VAD + sem-grep's bge-small.
The `cpu` lane in infer-queue sits empty. Parakeet via sherpa-onnx
fills it without a new flake input — sherpa-onnx ships pre-converted
parakeet ONNX on HF, fetchable as a FOD exactly like wake-listen
fetches silero_vad.onnx.

## Falsifies

Is dictation latency actually accelerator-bound, or is the contention
imaginary? Bench: `tests/bench-dictate.sh` — 20 fixed utterances × 3
backends (vulkan/npu/cpu) × 2 load states (idle vs `ask-local --agent`
actively serving). Measure p50/p95 wall-to-first-token.

Pass bar: under ask-local load, `transcribe-cpu` p95 beats
`ptt-dictate --vulkan` p95 by ≥200ms. If yes → lane-pressure routing
is the right shape, `--backend=auto` becomes the ptt-dictate default,
and the agent-eyes comment ("falsifies whether the Arc has headroom
for a second resident model") gets its answer: it doesn't, route
around it. If parakeet-cpu loses even at idle → NeMo's CPU claim
doesn't hold on Meteor Lake P-cores, drop the package, the 2-lane
split was correct.

Decides: infer-queue stays advisory (agents pick lanes manually) vs
grows a `--lane=auto` that reads pueue group depth — which is the
shape kin would want if it ever grows a local-inference module.

## How much

~0.4r. Zero new flake inputs (sherpa-onnx in nixpkgs). ~40L
writeShellApplication cloned from transcribe-npu + 1 fetchurl FOD for
the model + ~15L `--backend=auto` arm in ptt-dictate reading
`pueue status --json | jq '.groups'` + bench script under tests/.
