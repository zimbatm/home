# meta: token-cost.sh produces 0 rows — DIAGNOSED

## Root cause (verified r8)

`PROJ_SLUG=$(pwd | tr / -)` at .claude/workflows/token-cost.sh:12.

META runs from the grind base worktree `/root/src/home-grind/_base`, so
PROJ_SLUG resolves to `-root-src-home-grind-_base`. Transcripts land
under `~/.claude/projects/-root-src-home/` (the cwd of the parent
`/grind` invocation). The glob matches nothing → SESSION_DIR empty →
0 rows.

Verified: `SESSION_DIR=~/.claude/projects/-root-src-home/<uuid>`
override produces a full table (43 sessions across 6 roles, r1-r8).

## Fix (one line, .claude/workflows/token-cost.sh:12)

```sh
PROJ_SLUG=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)" | tr / -)
```

Derives the slug from the user tree (git common-dir parent) regardless
of which worktree META is sitting in. Same pattern grind already uses
for USER_TREE in BASE_SETUP.

## Secondary finding

20/43 sessions land in role `?` (unmatched). ROLE_RE requires
title-case `Triage|Merge` or all-caps; the home-grind Triage/Merge
prompts likely use a different lead-in. Low priority — the 6 named
roles cover the spend that matters for WIDE/DRY.

## Blocker

`.claude/workflows/` is on the grind denylist → human applies.
