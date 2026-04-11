# adopt: agent-meter — hybrid spend/occupancy view (ccusage, our way)

## What

Mic92 runs `ccusage` + `ccstatusline` (numtide/llm-agents.nix) to
surface Claude API token spend in the prompt. nv1's stack is hybrid —
API *and* local (ask-local on Arc, OpenVINO on NPU, infer-queue lanes).
Build `agent-meter`: one CLI/statusline segment that shows, side by
side:

- API spend: parse `~/.config/claude/**/*.jsonl` like ccusage does
  (input/output/cache tokens, today + rolling)
- Arc occupancy: `intel_gpu_top -J -s 1000` one-shot, engine busy %
- NPU occupancy: `/sys/class/accel/accel0/device/npu_busy_time_us`
  delta (ivpu exports this)
- infer-queue depth: `pueue status --json` per-lane queued/running

Output: terse one-liner for statusline (`agent-meter --line`) and a
table for interactive (`agent-meter`). writeShellApplication + jq.

## Why

The whole nv1-as-LLM-testbed bet is that local inference offloads real
work from the API. Can't tell if it's working without seeing both dials
on one gauge. ccusage answers half the question; we need the local half
next to it.

## How much

~0.5r. ~80-line shell + jq; intel_gpu_top and pueue already in closure
via infer-queue/desktop. NPU sysfs read is trivial. Statusline wiring
is a one-line starship/PS1 custom segment.

## Falsifies

Whether ask-local/ptt-dictate/infer-queue actually move API-spend
numbers under daily-driver load, or whether local inference is just
heat. First week of side-by-side data settles it.

## Source

Mic92/dotfiles `ai.nix`: `aiTools.ccusage` + `aiTools.ccstatusline`.
Their idea (surface agent cost), extended to nv1's hybrid compute lanes.
