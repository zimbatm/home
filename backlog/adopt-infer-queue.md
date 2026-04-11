# adopt: device-tagged local-inference job queue (nv1)

## What

Mic92 wraps `pi` so it auto-starts `pueued`, giving agent background
tasks a real queue instead of fire-and-forget. Our angle on the same
problem, fitted to nv1's hardware: an `infer-queue` CLI — pueue groups
pinned to nv1's compute lanes (`arc` iGPU, `npu` Meteor Lake, `cpu`),
one slot each, so an agent can submit local-inference work and poll
without blocking the conversation:

```sh
infer-queue add --lane arc  -- whisper-cpp -m ggml-small ~/rec/meet.wav
infer-queue add --lane npu  -- openvino-whisper ~/rec/*.wav   # batch
infer-queue status                                            # → pueue status
infer-queue log <id>
```

Plus `~/.claude/skills/infer-queue/SKILL.md`: "for any local inference
>5s, submit here and poll; don't block."

## Why

nv1 is the LLM-future testbed; RTX 4060 is vfio-bound so host-side
compute is Arc + NPU. `ptt-dictate` proved single-shot whisper works;
the next rung is *batch/background* inference an agent can dispatch.
Without a queue, two whisper jobs fight over the iGPU and both crawl —
the lane=1-slot constraint is the actual win, pueue is just plumbing.

## How much

~0.5r. `packages/infer-queue/default.nix` (writeShellApplication over
`pueue`; ships a `pueue.yml` with groups `arc:1 npu:1 cpu:4`), systemd
user unit for `pueued`, SKILL.md, add to nv1 home.packages. One new
runtime dep (`pkgs.pueue`), no new flake inputs.

## Falsifies

- Can an agent on nv1 usefully offload to local compute without
  blocking? (Submit a 60s whisper batch mid-conversation, keep working,
  collect result — does the round complete?)
- Is the NPU lane worth having, or does everything end up on `arc`?
  Feeds the existing `machines/nv1` OpenVINO-NPU exploration comment.

## Blockers

None for `arc`/`cpu` lanes. `npu` lane is speculative until the
OpenVINO-whisper exploration lands something runnable — ship with the
group defined but document it as "no consumers yet".
