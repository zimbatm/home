# ops: point agentshell at llm-router (:8090)

## What

Set `OPENAI_BASE_URL=http://127.0.0.1:8090/v1` (and/or
`ANTHROPIC_BASE_URL`) in the nv1 agent environment so claude-code /
codex / crush hit `llm-router` by default. Either via the SessionStart
hook that writes `.claude/profile`, or via `kin` agentshell env.

## Why

`packages/llm-router` is landed and on PATH but inert until something
points at it. Flipping every live agent to a brand-new proxy is a
behaviour change on a daily-driver — Jonas should run `llm-router` +
`ask-local --serve` manually first and watch
`~/.local/state/llm-router/decisions.jsonl` for a session before making
it the default.

## How much

One env line. Needs a human at nv1 to verify the local lane doesn't
degrade answers, then commit the wiring.

## Blockers

Human-gated (deploy + behaviour change on nv1).
