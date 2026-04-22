# adopt: ask-local --agent trace-retrieval — does sub-4B learn from itself?

## What

Give `ask-local --agent` a memory: after each run, append
`{goal, tool_calls, final, ok}` to
`$XDG_STATE_HOME/ask-local/runs.jsonl` and embed `goal` into a new
sem-grep `runs` table (same NPU bge-small path as `hist`/`log`).
Before each run, retrieve top-2 similar past traces and prepend them
as few-shot examples ahead of the ReAct prompt. Flag-gated
(`--mem` / `ASK_LOCAL_MEM=1`) so the cold path stays benchable.

## Why (seed → our angle)

Seed: **letta-code** ("memory-first coding agent that learns and
evolves across sessions") and **hermes-agent** ("creates skills from
experience") — both new in llm-agents.nix since last scout — plus the
MemGPT line all do experience-replay, but cloud-side with 70B+ models
where in-context learning is strong.

Our angle: nobody publishes whether trace-retrieval helps a *3.8B* on
iGPU. We have the exact rig to settle it cheaply: bench-agent.jsonl
(20 cases), the bge-small embedder already resident on NPU, and the
GBNF-forced tool-call format that makes traces uniformly shaped. If it
works, the local agent compounds without growing the model; if it
doesn't, that's a clean routing signal.

## Falsifies

Sub-4B-benefits-from-own-trace. Protocol: run `bench-agent.jsonl` 3×
with `--mem` off (cold baseline, take median pass@1), then 3× with
`--mem` on after a warm-up pass has populated `runs`. Pass bar: warm
pass@1 ≥ cold + 3/20 *and* no latency regression past +150ms p50
(retrieval is one sqlite SELECT + 2 short prepends; lookup-decode
should eat the prepend tokens).

Decides: (a) whether `--mem` defaults on; (b) llm-router rule — if
sub-4B *doesn't* benefit, memory-shaped goals route to cloud
regardless of complexity gate; if it *does*, local handles repeat
intents and cloud sees only novel ones.

## How much

~0.4r. `cmd_index_runs` / `cmd_runs` in sem-grep mirror
`cmd_index_log` / `cmd_log` (same dedupe+embed+upsert shape, ~40L).
ask-local: ~25L in the `--agent` branch (write-after, retrieve-before,
flag plumbing). Bench: extend `bench.sh` with a `--mem` axis;
`bench-agent.jsonl` already exists (20 cases).

## Blockers

None. Zero new inputs; reuses NPU bge-small, sqlite, llama-lookup
cache. Runs entirely on nv1's Arc+NPU — measurement appended to
`ops-deploy-nv1` post-deploy like the other ask-local benches.
