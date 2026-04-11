# research: Whisper on Meteor Lake NPU via OpenVINO

## What

OpenVINO (nixpkgs 2026.1.0) supports Whisper on the Meteor Lake NPU
since 2024.5 — lower power than iGPU Vulkan. Investigate whether the
NixOS plumbing (`intel_vpu` firmware, level-zero NPU plugin) works
end-to-end.

## Why

If it works, dictation moves off the iGPU entirely (battery win) and
the NPU otherwise sits idle. But NixOS NPU support is unproven —
this is exploration, not adoption.

## How much

~1r exploration. May dead-end on firmware/driver gaps.

## Blockers

None to start; likely to hit packaging gaps mid-way.

## Falsifies

If `intel_vpu` + level-zero NPU plugin can't enumerate the device
on nv1, file the gap upstream (nixpkgs or `../meta`) and shelve.

## Refs

https://docs.openvino.ai/2025/openvino-workflow-generative/inference-with-genai/inference-with-genai-on-npu.html
