# adopt: wake-listen — NPU-resident VAD gate in front of ptt-dictate

## What

`packages/wake-listen`: a tiny always-on user service that runs Silero
VAD (an ~1 MB ONNX model) on the Meteor Lake NPU via the OpenVINO stack
`transcribe-npu` already pulls. It reads a low-rate pipewire monitor
stream, and on speech-onset spawns the existing `ptt-dictate` capture
path (or `transcribe-npu` directly). Optional second stage: match the
first ~1 s transcript against a fixed phrase ("ok laptop") before
committing — cheap wake-word without a separate wake-word model.

Wire as `systemd --user` unit (nv1 home/desktop only), `--oneshot` mode
for testing. State: `$XDG_RUNTIME_DIR/wake-listen/active` flag so
`ptt-dictate` and `wake-listen` don't double-fire.

## Why

External seed: `handy` showed up in llm-agents.nix and openWakeWord /
Silero are the standard always-on front-ends people bolt onto whisper.
They all target generic CPU/GPU. **Our angle:** nv1 has the MTL NPU
sitting idle except when `transcribe-npu` runs — VAD is the textbook
ambient-coprocessor workload (continuous, tiny, latency-tolerant). Put
the cheap gate on the NPU, keep Arc free for `ask-local`, keep CPU
asleep. The voice loop (`ptt-dictate` ↔ `say-back`) stops needing
Super+d; composes with `now-context`/clip for hands-free "explain this".

## How much

~0.5r. Reuses `transcribe-npu`'s python env (openvino + numpy +
soundfile); Silero VAD ONNX is a `curl` fetch hint like the other
models. New code is ~60 LoC python (pw-record → 30 ms frames → OV
infer → debounced trigger) + ~15 LoC systemd unit. No new flake inputs.

## Falsifies

Can the NPU sustain always-on VAD at negligible power? Measure via
`agent-meter` NPU-busy % and `powertop` package-W delta with the unit
running vs masked over a 10-min idle window. If NPU-busy stays >20 % or
package draw rises >0.5 W, the "ambient coprocessor" premise is wrong
for this silicon and we fall back to push-to-talk.

## Blockers

`hardware.cpu.intel.npu.enable` is declared but un-deployed — gated on
`backlog/needs-human/ops-deploy-nv1.md`. Implementer can land the
package + unit (eval/dry-build gate) without the NPU live; the
falsification step waits for deploy.
