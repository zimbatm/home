# adopt: live dictation via whisper.cpp on Intel Arc (Vulkan)

## What

Push-to-talk dictation on nv1: `whisper-cpp` (nixpkgs 1.8.4) built with
Vulkan backend, running on the Intel Arc iGPU. Wrap with a hotkey +
`ydotool` script (or [jacopone/whisper-dictation] — NixOS-native GTK4
overlay). Model: `base.en` (~140MB, fast) or `small` (~460MB, better).

## Why

Jonas's first concrete ask for the LLM-future testbed. whisper.cpp 1.8.3+
on Intel iGPU via Vulkan is ~12× CPU (Phoronix, Core Ultra 155H — same
gen as nv1's Meteor Lake-H), so 3-4× realtime — fine for live PTT
without touching the vfio-bound RTX 4060.

## How much

~0.5r. Pieces:
- `hardware.graphics.extraPackages = [ intel-compute-runtime mesa ]`
  (Arc Vulkan compute)
- `(whisper-cpp.override { vulkanSupport = true; })` in home.packages
- Either package `jacopone/whisper-dictation` or write a ~30-line
  wrapper: hotkey → record → whisper-cli → `ydotool type`
- Model fetch (declarative via `fetchurl` or imperative first-run)

## Blockers

None. `whisper-cpp` and `ydotool` are in nixpkgs. Need to verify
`vulkanSupport = true` is the actual override attr name.

## Falsifies

If Arc Vulkan whisper-cpp can't sustain realtime on `base.en`, the
"iGPU is enough" claim is wrong and `research-openvino-npu-whisper`
or RTX unbind moves up.

[jacopone/whisper-dictation]: https://github.com/jacopone/whisper-dictation
