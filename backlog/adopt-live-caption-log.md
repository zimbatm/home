# adopt: live-caption-log — system audio → rolling NPU transcript → sem-grep index

## What

A `packages/live-caption-log` that taps the PipeWire monitor source,
chunks audio into ~8s windows, feeds each through `transcribe-npu`
(via `infer-queue add --lane npu`), and appends `{ts, text, source}`
lines to `$XDG_STATE_HOME/live-caption/YYYY-MM-DD.jsonl`. A nightly
hook adds yesterday's log to the `sem-grep` corpus. Optional
`--overlay` flag pipes the latest line to a tiny `notify-send -t 0`
replace-id toast for on-screen captions.

No new model, no new python deps — `pw-record` + the existing
`transcribe-npu` closure (openvino whisper-base IR) + `infer-queue`.

## Why (seed → our angle)

**Seed:** nixpkgs `livecaptions` (abb128, GTK4 + april-asr +
onnxruntime) does realtime desktop captioning. Mic92 has nothing in
this lane. macOS/ChromeOS ship it OS-level.

**Our angle:** `livecaptions` is display-only and CPU-bound
(onnxruntime, april-asr model). We already run whisper-base on the
**NPU** (`transcribe-npu`) and have a device-lane queue
(`infer-queue --lane npu`) and an embedding index (`sem-grep`). Skip
the GTK app; treat captions as a **log stream** that lands in the same
searchable corpus as ~/src. "What did the standup say about the iets
regression" becomes a `/sem-grep` query against local audio history —
no cloud, no recording kept, just text. The overlay is the side dish,
the jsonl is the point.

## Falsifies

- **NPU realtime headroom**: `transcribe-npu` is batch (wav→stdout).
  Can the NPU lane sustain 8s chunks at <8s wall-clock while
  `sem-grep`/`ask-local` contend for the same `infer-queue --lane npu`
  slot? Measure: `agent-meter` NPU-busy % during a 30-min video. If it
  saturates, the 1-slot lane model in `infer-queue` is wrong (needs
  priority, not FIFO) — file that against infer-queue, not here.
- **whisper-base recall quality**: after a week of logs, do `sem-grep`
  queries over caption jsonl return useful hits, or is base-model WER
  too high for embedding search to recover? If useless, the answer is
  whisper-small IR on Arc (not NPU) — different trade.
- **vs upstream livecaptions**: install `pkgs.livecaptions` alongside
  for a day. If april-asr-on-CPU latency/accuracy beats our NPU path,
  the NPU offload thesis is weaker than assumed.

## How much

~0.4r. `pw-record --target <monitor>` → tmpfile → `infer-queue add` →
append-jsonl is ~60 lines of shell. sem-grep already reads jsonl-ish
text; corpus hook is one `find` + reindex. Overlay is optional polish.

## Blockers

- `transcribe-npu` currently exits after one wav; needs to accept
  stdin chunks or be cheap enough to exec per-chunk (model load cost
  on NPU — measure first, may need a `--serve` mode).
- ops-*: needs a human to confirm capturing the monitor source is
  acceptable (it records *all* desktop audio to text — privacy stance
  should be explicit even though it never leaves disk).
