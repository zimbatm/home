# adopt: local VLM triage for agent-eyes — route vision like llm-router routes text

## What

Extend `packages/agent-eyes` with `peek --ask "<question>"`: capture →
tiny local vision model → short stdout answer. Backend is the same
`llama-cpp.override { vulkanSupport = true; }` we already ship for
`ask-local`, loading a moondream2 GGUF (~1 GB Q4, llama.cpp has native
mmproj support). No new daemon; reuses the Arc lane via `infer-queue`.

## Why

`peek` and `gsnap` produce PNGs; every semantic read ("is there an
error dialog?", "did the theme apply?", "which pane is focused?") ships
the full image to remote Claude. That's the exact shape `llm-router`
already handles for text: short, no-tools, low-stakes → keep it local.
Extending the same routing premise to pixels is the obvious next rung.

Our angle: Mic92's `screenshot-cli` skill only captures (same as our
`peek` today). We add the local pre-read so the agent can gate "do I
even need to send this upstream?" on-device. Not a copy — it's
`llm-router`'s thesis applied to a second modality.

## How much

~0.5r. `ask-local` already proves the llama.cpp+vulkan+XDG-model
pattern; this is the same wrapper with `--mmproj` and an image arg.
`peek` grows ~10 lines. Optional: teach `llm-router` to accept an
`image_url` and apply the same short-prompt heuristic.

## Falsifies

- llm-router's "short queries stay local" premise generalises beyond
  text — or vision is where it breaks (latency/accuracy floor too low
  on a 1.8 B model for even boolean triage).
- Arc iGPU has headroom for a second resident model alongside
  ask-local's Phi-3, or `infer-queue`'s 1-slot arc lane was the right
  call and they must queue.

## Blockers

None hard. moondream2 GGUF + mmproj are public on HF; llama.cpp ≥ b4520
(nixpkgs-unstable has it) handles the format. If Arc VRAM (shared,
~8 GB cap) can't hold both models, that's a finding — note it and fall
back to cpu lane.
