# adopt: structured CoT grammar for local coding latency

## What

Try the "Structured CoT" inference-time trick from
<https://andthattoo.dev/blog/structured_cot>: constrain only the model's
`<think>` block with a tiny GBNF grammar, while leaving the answer/code channel
permissive.

Candidate shape for a first coding experiment:

```gbnf
root  ::= think answer
think ::= "<think>\n" "GOAL: " line "APPROACH: " line "EDGE: " line "</think>\n\n"
line  ::= [^\n]+ "\n"
answer ::= [\x09\x0A\x0D\x20-\x7E]+
```

Start as an opt-in `ask-cuda` / `llama.cpp` experiment, not a default. The
current `ask-cuda` Qwen3.6 path is the relevant dogfood target; `ask-local`
already has `--grammar` plumbing and can serve as a smaller-control harness.

## Why

Qwen reasoning models can overthink locally, making interactive use feel slow
and wasting tokens/joules. The blog reports large reductions in explicit
thinking tokens on Qwen3.6 coding evals without pass@1 loss in those runs:

- HumanEval+: ~3087 → 138 mean thinking tokens.
- LiveCodeBench public-test slice: ~11553 → 267 mean thinking tokens, with fewer
  empty/malformed-code failures.

This is interesting for home because `nv1` now has a CUDA `ask-cuda` package for
Qwen3.6-35B-A3B, where latency and runaway reasoning are the main UX limits.

## How much

Prototype and measure before adopting:

1. Add an opt-in structured-thinking grammar file and flag/env knob, e.g.
   `ask-cuda --structured-think` or `ASK_CUDA_STRUCTURED_COT=1`.
2. Keep the answer channel permissive; only force the pre-answer scratchpad.
3. Run a small deterministic harness of coding prompts with free-form vs grammar
   modes. Track:
   - wall-clock latency and generated tokens,
   - tokens before/after `</think>`,
   - malformed/empty output rate,
   - whether comments or answer text absorb the displaced reasoning,
   - pass/fail on simple tests where available.
4. If it helps, mirror the option into `ask-local` or document why the smaller
   Phi model cannot use it reliably.

Do not claim a hard reasoning-token budget unless the grammar actually bounds
line length under llama.cpp GBNF; the blog's `line ::= [^\n]+` is shape control,
not a strict token cap.

## Blockers

- `ask-cuda` one-shot mode currently has a separate runaway/non-exit bug in
  `backlog/bug-ask-cuda-oneshot.md`; structured CoT can still be tested through
  `llama-server` or after that is fixed.
- Needs a local benchmark run on `nv1`; no deploy should be run by the agent.
