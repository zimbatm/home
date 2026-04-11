# adopt: llm-router — request-shape proxy in front of Claude + ask-local

## What

A tiny local reverse proxy (`packages/llm-router`, writeShellApplication
or ~100-line Go) listening on `127.0.0.1:8090`, OpenAI-compatible. Routes
each `/v1/chat/completions` by request shape:

- short prompt, no tools, ≤4k ctx → `ask-local --serve` (`:8088`, Arc iGPU)
- everything else → upstream Anthropic/OpenAI

Logs every routing decision (lane, tokens-in, latency) to a jsonl that
`agent-meter` already knows how to scrape. Agents point `*_BASE_URL` at
`:8090` and stop caring which backend answered.

## Why

Surveyed: `cli-proxy-api` (router-for-me/CLIProxyAPI, in llm-agents.nix)
does unified-API proxying so one endpoint fronts many providers. Mic92
ships it as-is. **Our angle:** we already have the local backend
(`ask-local`), the occupancy gauge (`agent-meter`), and the device queue
(`infer-queue`) — what's missing is the *decision layer* that actually
shifts traffic between them. A router that picks lane by request shape is
the smallest piece that turns those three from "installed" into "load-
bearing." We don't want CLIProxyAPI's provider-abstraction; we want a
nv1-specific cost/locality policy.

## How much

~0.5r. `socat`/`caddy` + `jq` request inspection, or a small Go binary.
ask-local's `:8088` is already OpenAI-compat so the local leg is a
straight pass-through. Wire `ANTHROPIC_BASE_URL`/`OPENAI_BASE_URL` env
into `agentshell` so every agent on nv1 hits the router by default.

## Falsifies

"Request-shape routing can move a visible fraction of API spend to the
Arc iGPU without the agent noticing." Measurable: `agent-meter` API-token
delta over a day with router on vs off. If the local lane never fires on
real traffic, or fires and degrades answers, the composition is wrong and
ask-local/infer-queue are display pieces.

## Blockers

None. ask-local + agent-meter already landed; this is glue.
