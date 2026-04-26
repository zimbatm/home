# pi-native grind harness

This extension is the first cut of a dedicated `grind` harness for pi. It deliberately bakes the old `.claude/workflows/grind-base.js` orchestration into TypeScript instead of implementing a generic `Workflow({script})` runtime.

## Commands

- `/grind {"rounds":1}` — start a background grind run.
- `/grind-status` — show active runs in this pi process.
- `/grind-stop` — touch `.grind-stop` and ask active runs to stop after the current step.

The model-callable `grind_start` tool is also registered for non-command use.

## Config

The runner loads the first config found:

1. `.pi/grind.config.js`
2. `.claude/grind.config.js`

The current `.claude/grind.config.js` shape is supported for migration: `export const meta = ...` plus an unexported `const CONFIG = ...`.

## Persistence

Each run writes under:

```text
.pi/grind-runs/<run-id>/
  config.snapshot.json
  events.jsonl
  agent-0001-<label>.jsonl
  agent-0002-<label>.jsonl
```

`events.jsonl` is the durable progress log. The per-agent files contain the child `pi --mode json` stream.

## Current scope

This is grind-specific, not a general workflow engine. The child agents are isolated by spawning `pi --mode json -p --no-session`; their transcripts do not enter the parent conversation. Structured returns are requested as JSON and parsed by the harness.
