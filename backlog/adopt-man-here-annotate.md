# adopt: man-here annotate — store-keyed gap notes

## What

Two new arms in man-here's case block:

    man-here annotate <cmd> "<note>"   → append to $XDG_STATE_HOME/man-here/<pname>-<major>.notes
    man-here <cmd>                     → if notes file non-empty, emit as first ## section

Key on `pname + major-version` (parsed from the store path man-here
already resolves at :40-44), not full storehash — survives patch bumps
from bumper rounds, invalidates on real API churn. Plus one
instrumented log line: every read appends `{ts, cmd, had_notes}` to
`$XDG_STATE_HOME/man-here/reads.jsonl`.

## Why (seed → our angle)

Seed: **context-hub** (andrewyng/context-hub, `chub` — init in
llm-agents.nix 2026-04-22, 4 days old). Cloud-backed curated doc hub
for agents; the one local primitive is `chub annotate <id> <note>` —
agent-discovered gaps persist and prepend on next fetch.

Our angle: don't want chub (fetches from a curated GitHub repo;
man-here already gives version-exact docs from /nix/store, which is
strictly more authoritative for what's *actually installed*). But
`annotate` is the missing closing of the loop. Right now when grind
discovers "the `--json` flag in `man-here kin` is documented but
panics on this build" it either files backlog/ (heavyweight, wrong
granularity) or loses it at end-of-round. A pname-keyed notes file is
the right weight: cheaper than backlog, survives the round boundary,
scoped to the exact tool version.

## Falsifies

Do agents self-annotate without being told, or is it write-only? The
reads.jsonl instrument answers it: after 10 grind rounds, compute
`reads-with-notes / total-reads`.

Pass bar: ≥0.10 → annotate stays, add a one-line hint to the man-here
SKILL.md ("if you discover a gap, `man-here annotate`"). Ratio <0.05 →
agents don't close the loop unprompted; drop the verb, chub's bet
(that annotate is self-sustaining) is wrong for sub-agent loops.
Secondary: count notes files orphaned by bumper churn (pname-major key
exists but no matching store path) — if >50% orphaned after 10 rounds,
re-key on pname-only.

Decides: whether grind's per-round amnesia is a tooling gap (fixable
with cheap state) or a design property (subagents *should* be
stateless, push everything to backlog/).

## How much

~0.2r. ~25L into man-here's existing case block (one `annotate)` arm,
one `hdr "notes (local)"` section before the existing `## package`
header, one `>> reads.jsonl` line). Zero new inputs. SKILL.md edit is
human-gated per adopt-nix-skills precedent — leave it out, file
separately if the bench passes.
