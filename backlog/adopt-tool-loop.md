# adopt-tool-loop — ask-local --agent: Phi-3 drives our own CLIs

## what

`ask-local --agent "<goal>"` — bounded ReAct loop where the **local** model
is the driver and the tool inventory is our own `packages/`. No new model,
no new deps: wrap the existing llama-cpp + `--grammar` path in a ~80 LoC
python harness that forces `{"tool":"<name>","args":"<str>"}|{"final":"<str>"}`
via GBNF, execs the named CLI, feeds stdout back as an observation, caps at
N turns (default 4).

Tool inventory = the CLIs we already built for Claude to call:
`now-context`, `sem-grep`, `kin-opts`, `man-here`, `peek --ask`,
`infer-queue status`. Declared in a single `tools.json` (name + one-line
description + argv template) under `packages/ask-local/`.

## why (seed → our angle)

**Seed:** llama.cpp b4600+ ships native tool-calling chat templates
(Hermes-2-Pro / Functionary); aider/crush/opencode/Mic92's `pi` all bolt a
tool loop onto a *cloud* model. Every reference implementation assumes the
driver is GPT-4-class.

**Our angle:** we've spent ~8 scout rounds building agent-facing CLIs
*for Claude*. Flip the consumer: can the 3.8B model already resident on the
Arc iGPU pick from a 6-tool inventory? llm-router's premise is "route small
to local" — but we've only tested local on *generation*, never on
*orchestration*. This is the cheapest possible test: zero new closure,
reuses `ask-local --grammar --fast` (lookup-decode landed in 9efd401 makes
the per-turn latency tolerable).

## falsifies

Whether a sub-4B model on consumer iGPU can drive a tool loop *at all*.

- **If yes** (≥70% correct tool-choice on the bench): local-first widens —
  wake-listen → ptt-dictate → `ask-local --agent` becomes a fully-offline
  voice assistant over the assise repos, and llm-router gains a third tier
  (local-agent between local-gen and remote).
- **If no**: that's the data point — llm-router's local/remote split needs a
  *complexity* gate (tool-use → always remote), not a *size* gate. File the
  boundary in docs/ and stop pretending ask-local is more than a text filter.

Measure: 20 canned goals in `packages/ask-local/bench-agent.jsonl` (same
shape as sem-grep's 20q bench from rerank-pass). Per-goal: expected first
tool + expected final-answer substring. Score tool-choice accuracy +
median turns + median wall-clock. Run via infer-queue arc lane so
agent-meter captures the GPU cost.

## how-much

~0.4r. `packages/ask-local/agent.py` (~80 LoC: grammar string, loop,
subprocess, turn cap) + `tools.json` + `bench-agent.jsonl` + `--agent` flag
in the existing wrapper. Zero new flake inputs; llama-cpp + python3 already
in closure. Bench run gated on ops-deploy-nv1 (needs the Arc).

## blockers

None for landing the code. Bench numbers gated on ops-deploy-nv1.
