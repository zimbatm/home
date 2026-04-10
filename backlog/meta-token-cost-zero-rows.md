# meta: token-cost.sh produces 0 rows across r1-r7

## What

`.claude/workflows/token-cost.sh --by-role` and `--notes` have emitted
empty tables every META round r1-r7, including r7 which had a real merge
(fab80e6). The script reads session JSONL from a `session_dir` and
matches role via `ROLE_RE = r'You are (?:the |an? )?([A-Z][A-Z-]{2,}|Triage|Merge)\b'`
against the first user message — so 0 rows means no sessions are being
found/matched, not that merges lack tags.

## Why

Without per-role cost data the WIDE/DRY flags never fire, so META can't
file `meta-split-<role>` / `meta-retire-<role>` items. The token-cost
step (added bd8e80a) is a no-op until the wiring is fixed.

## Likely causes (pick one)

- `session_dir` arg points at a path the home-grind workflow doesn't
  write to (script was vendored from another repo's layout per bd8e80a
  "generalized ROLE_RE" — but maybe not generalized session path).
- `wf_filter` (argv[2]) doesn't match this workflow's name/slug.
- Subagent sessions aren't persisted as JSONL where the script expects.

## How much

Read `.claude/workflows/token-cost.sh` wrapper (the bash part that
computes `session_dir`/`wf_filter` before the python heredoc) and
compare against where home-grind subagent transcripts actually land.
~15min investigation; fix is likely a path/filter string.

## Blockers

`.claude/workflows/` is on the grind denylist → needs-human to apply.
File the diagnosis here; human edits the script.
