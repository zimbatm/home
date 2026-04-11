# adopt: `scout` specialist in grind rotation

## What

Add a 4th rotating specialist to `.claude/grind.config.js:specialists`
that surveys external sources (Mic92/dotfiles, nix-community,
recent nixpkgs PRs tagged AI/LLM) and files `backlog/adopt-<slug>.md`
sketches for promising tooling.

## Why

Operationalizes Jonas's "go out there and search for new setups and
make propositions" (2026-04-11) as a continuous thing instead of
one-shot research. Fits the existing specialist pattern.

## How much

~0.2r — one prompt block in `CONFIG.specialists.scout`. Rotation
becomes drift/simplifier/bumper/scout (every 4th round).

## Blockers

Workflow subagents may lack WebSearch/WebFetch tools (they lack REPL
per BASE_SETUP). Scout can use `curl` via Bash for GitHub raw URLs +
the GitHub search API, but general web search needs verification.
If unavailable, scout scope narrows to GitHub-only (still useful —
Mic92/nix-community/awesome-nix are the high-signal sources).

## Falsifies

If scout files <1 actionable adopt-* per 4 rounds after 12 rounds,
it's DRY → retire (token-cost.sh will flag it).
