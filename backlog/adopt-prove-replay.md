# adopt: pty-puppet `prove` — replayable behavioural gate

## What

Two new verbs on `pty-puppet`:

- `pty-puppet @<n> record tests/prove-<slug>.sh` — tee every
  `send`/`expect` issued against session `<n>` into a standalone
  shell script (just the existing pty-puppet calls, plus a `spawn`
  header captured from the live session's cmdline).
- `pty-puppet replay tests/prove-<slug>.sh` — run that script;
  exit non-zero on first `expect` miss.

Emit into a new `tests/` dir (currently absent). An implementer that
changes `packages/<tool>/` records one prove script demonstrating the
change; the grind gate grows an optional `for f in tests/prove-*.sh;
do pty-puppet replay "$f"; done` step *after* eval+dry-build (the
grind.md edit itself is human-gated per denylist — this item ships
the verb + first prove scripts only).

## Why (seed → our angle)

Seed: **showboat** (new in llm-agents.nix since last scout) — "create
executable demo documents showing and proving an agent's work".
Upstream targets human-readable demo docs (markdown + embedded runs).

Our angle: we don't need demo *documents*, we need a third *gate*.
eval+dry-build catches Nix-level breakage; gsnap catches pixel
regressions; nothing catches "ask-local --fast now returns JSON
instead of text" or "sem-grep sig stopped matching Rust". pty-puppet
already has the exact primitives (`spawn`/`send`/`expect`/`snap` at
default.nix:15-18) — `record` is a tee, `replay` is `bash -e`. The
prove scripts are themselves pty-puppet one-liners, so an agent
writing one is the same motion as an agent testing interactively. Zero
new inputs; composes pty-puppet + the agent-eyes snap path for TUI
cases.

## Falsifies

Behavioural-replay catches what eval+dry-build misses. Bench: walk the
last 10 grind merges that touched `packages/` (git log
--diff-filter=M -- 'packages/*/'), hand-write a prove script for each
*at the parent commit*, replay at the merge commit. Count: how many
would have flipped red→green (intended) vs stayed green (gate adds
nothing) vs flipped green→red on an *unrelated* later merge
(regression the existing gates missed).

Pass bar: ≥1 true regression caught across the 10, with ≤2min replay
wall-clock for the full `tests/prove-*.sh` set (gate must stay fast).

Decides: grind gate grows a replay step (file the human-gated grind.md
edit) vs prove scripts are write-only ceremony (drop the verb, keep
pty-puppet interactive-only).

## How much

~0.4r. `record` = wrap `send`/`expect` to also `printf >>$REC`;
`replay` = `bash -e "$1"` with `set -o pipefail`. ~30 lines into the
existing `case "$verb"` block. First two prove scripts
(`tests/prove-ask-local-fast.sh`, `tests/prove-sem-grep-sig.sh`) seed
the bench. The retro-bench over 10 merges is the bulk of the round.
