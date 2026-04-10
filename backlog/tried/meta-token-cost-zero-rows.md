# tried: meta-token-cost-zero-rows

## Outcome
Abandoned pre-merge (2026-04-10). Scope violation — denylist hit.

## Why abandoned
Merge gate flagged `.claude/commands/grind.md` as changed vs main.
That file is on the grind denylist: the grind harness is not permitted
to modify its own definition from inside a round.

Branch commits (ac57b26, a49dc10) only touched `backlog/` per
three-dot diff; the grind.md delta is main@369f627 (hosts/→machines/
rename) advancing past the branch point, not an edit on the branch.
Denylist check uses two-dot diff so it fired anyway.

The backlog item itself already states `.claude/workflows/` is
denylisted → needs-human; the diagnosis it asks for would land in
`backlog/needs-human/` regardless, which a human then applies.

Worktree `/root/src/home-grind/meta-token-cost-zero-rows` and branch
`grind/meta-token-cost-zero-rows` force-removed; no diff salvaged.

## Re-attempt when
Either: rebase onto current main first so the two-dot denylist check
doesn't false-positive on 369f627's grind.md change; or a human reads
`.claude/workflows/token-cost.sh` directly and fixes the
session_dir/wf_filter wiring out-of-band (the item's "Blockers" section
already routes it that way).

## Note
`backlog/meta-token-cost-zero-rows.md` left in place (matches
origin/main) so triage can re-route to needs-human/ or a human can
pick it up directly.
