# tried: bug-gitignore-grind-scratch-root

## Outcome
Abandoned pre-merge (2026-04-10). Scope violation — denylist hit.

## Why abandoned
Branch touched `.gitignore`, which is on the grind edit denylist.
The fix described in the backlog item is *itself* a one-line
`.gitignore` edit (`.claude/workflows/_grind-*.js` → `/_grind-*.js`),
so any agent attempt trips the same guard. Worktree + branch
`grind/bug-gitignore-grind-scratch-root` (was 88e0b75) discarded.

## Re-attempt when
Human applies the `.gitignore` change directly (out of grind's
allowed scope), or the denylist grows an exception for
root-anchored ignore-pattern fixes. Until then triage should mark
this needs-human, not re-pick.

## Note
Original `backlog/bug-gitignore-grind-scratch-root.md` left in place
— the bug is real (tree-guard still trips on `_grind-script.js` at
repo root), only the autonomous fix path is blocked.
