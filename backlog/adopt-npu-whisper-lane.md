# adopt: move whisper to the NPU, free Arc for ask-local

## What

`packages/transcribe-npu` — OpenVINO-genai whisper targeting the Meteor
Lake NPU (`/dev/accel/accel0`). Then teach `ptt-dictate` to prefer it
over whisper-cpp/vulkan when the accel node exists, falling back to the
current Arc path otherwise. Wire it as the first real workload on
`infer-queue`'s `npu` lane.

## Why

nv1 already declares the NPU (`hardware.cpu.intel.npu.enable = true`,
`boot.kernelModules = ["ivpu"]`, `machines/nv1/configuration.nix`
comment literally says "exploration: OpenVINO Whisper offload off the
iGPU") — but nothing runs there. `ptt-dictate` and `ask-local` both
contend for the Arc iGPU; dictating *into* a local-LLM prompt thrashes
the one device. Moving transcription to the NPU makes the
`infer-queue --lane npu` slot real and lets voice+LLM run concurrently.

Our angle: Mic92's ai.nix has no NPU path (he's on AMD); nixpkgs ships
`openvino` 2026.1.0 with the level-zero NPU plugin but no declarative
whisper wiring. We're not importing anyone's module — we're closing the
loop our own config already promised.

## How much

~0.6r. `pkgs.python3Packages.openvino` + `optimum-intel` whisper export
is a ~40-line writer; `ptt-dictate` gains a 5-line device probe. Model
fetch follows the existing XDG_DATA_HOME pattern (print curl line if
missing, same as ask-local/say-back).

## Falsifies

- The NPU enablement in nv1 config is load-bearing, not decorative.
- `infer-queue`'s 3-lane design (arc/npu/cpu) survives a real second
  lane — or the abstraction was premature.
- Dictation latency on NPU ≤ Arc (Intel claims ~2× for whisper-base on
  MTL NPU vs iGPU; measure with `agent-meter`).

## Blockers

Verify post-deploy that `/dev/accel/accel0` actually enumerates
(ops-deploy-nv1 already queued in needs-human/). If `vpu-umd-test`
fails, this whole item is blocked on firmware — file the gap, don't
work around it.
