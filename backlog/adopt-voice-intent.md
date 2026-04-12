# adopt: voice-intent — route transcribe-npu output to action, not just text

## What

A `--intent` mode for `ptt-dictate` (or a thin `voice-intent` shim
between `transcribe-npu` and `ydotool`): after transcription, pass the
utterance through `ask-local` with a llama.cpp **GBNF grammar** that
constrains output to either `{"type": "<intent>", "arg": "..."}` for a
known intent or `{"type": "text"}`. Dispatch table lives in
`$XDG_CONFIG_HOME/voice-intent/intents.toml`:

    [screenshot]   exec = "peek"
    [ask]          exec = "ask-local {arg} | say-back"
    [context]      exec = "now-context --clip"
    [type]         fallthrough = true   # → ydotool type (current path)

So "take a screenshot" → `peek`; "ask what's eight cubed" →
ask-local→say-back; anything unmatched types as today.

## Why (seed → our angle)

**Seed:** Rhasspy/Home-Assistant voice stacks ship a separate NLU
intent-matcher (snips-nlu, fuzzy slot-fill); Mic92's `mics-skills`
exposes local CLIs *to the agent* via SKILL.md. Both add a component.

**Our angle:** we already have the classifier (ask-local, Phi-3 on Arc)
and the action inventory (the skill CLIs: peek, gsnap, now-context,
ask-local, say-back). GBNF-constrained decoding means Phi-3 *cannot*
emit an invalid intent — no NLU model, no training, no new closure.
This turns the existing voice loop (wake-listen → transcribe-npu →
ydotool) from "hands-free typing" into "hands-free shell", composed
entirely from pieces already on nv1.

## Falsifies

- **Grammar-constrained latency**: is Arc-side Phi-3 with a ~10-rule
  GBNF fast enough (<300ms p95) that the classify hop feels instant
  after speech? Log per-utterance timings to
  `$XDG_STATE_HOME/voice-intent/decisions.jsonl` (mirrors llm-router).
  If >300ms, constrained decoding on a 4B model is too slow for
  interactive voice and we'd need a dedicated tiny classifier.
- **Inventory sufficiency**: after a week, what fraction of utterances
  hit a non-`text` intent? If <10%, the skill-CLI inventory isn't
  rich enough to be worth voice-dispatching yet — file the gap.

## How much

~0.4r. Extend `packages/ptt-dictate` with the intent branch (one GBNF
file generated from intents.toml at activation; one `llama-cli
--grammar` call; one `case` dispatch). Zero new packages, zero new
inputs. Ship a 4-intent default table mapping to existing CLIs.

## Blockers

None for pkg. Latency + hit-rate measurement gated on `ops-deploy-nv1`.
