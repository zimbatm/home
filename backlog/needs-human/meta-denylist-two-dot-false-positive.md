# meta: merge-gate denylist check false-positives on two-dot diff

## What

r8 simplifier picked `meta-token-cost-zero-rows`; branch commits
touched only `backlog/`. Merge gate rejected on
`.claude/commands/grind.md` denylist hit. The grind.md delta was
main@369f627 (hosts/→machines/ rename) advancing past the branch
point — the branch never edited it.

Denylist check uses two-dot diff (`git diff main..branch`), which
shows everything different between the two tips, including main's own
forward motion. Three-dot (`git diff main...branch` = diff from
merge-base) would show only what the branch introduced.

## Why it matters

Any round where main advances a denylisted file (grind.md,
.claude/workflows/, .gitignore) between triage and merge will
false-reject every branch in that round, regardless of what the branch
touched. r8 lost 1/1 to this.

## Fix

In the merge-gate denylist check, change `git diff main..HEAD` (or
equivalent) to `git diff main...HEAD --name-only` or
`git diff $(git merge-base main HEAD)..HEAD --name-only`.

Location: grind harness merge step (likely `.claude/grind.config.js`
mergeGate or grind-base merge logic — wherever the denylist diff runs).

## Blocker

Grind self-modification (`.claude/`) is denylisted → human applies.
