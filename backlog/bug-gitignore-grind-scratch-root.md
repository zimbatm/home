# bug: tree-guard trips on grind's own concat scratch

**Regression** since df45da5 — that commit added
`.claude/workflows/_grind-*.js` to .gitignore, but the assembled
scratch lands at **repo root** as `_grind-script.js` (grind-base.js
`OUT = path.join(REPO, '_grind-script.js')`). `git check-ignore`
exit=1 → tree-guard sees it as uncommitted and aborts the round.

## Fix

.gitignore: replace `.claude/workflows/_grind-*.js` with
`/_grind-*.js` (root-anchored). Verify:
`git check-ignore -v _grind-script.js` → matches.

## How much

~0.05r. One-line .gitignore edit.

## Blockers

None.
