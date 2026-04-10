# tried: adopt-nix-skills

## Outcome
Abandoned pre-merge (2026-04-10). Scope violation — denylist hit.

## Why abandoned
Branch touched `.claude/commands/grind.md`, which is on the grind
edit denylist. The backlog item prescribes editing the grind launch
step there (to link the nix-skills subset into `.claude/commands/`),
so any agent attempt trips the same guard. Worktree + branch
`grind/adopt-nix-skills` (was 23805be) discarded.

## Re-attempt when
Human applies the `.claude/commands/grind.md` edit directly (out of
grind's allowed scope), or the link step lands somewhere not on the
denylist (e.g. a separate setup script the launch step already
invokes). Until then triage should mark this needs-human, not
re-pick.

## Note
Original `backlog/adopt-nix-skills.md` left in place — the adoption
is still wanted (locked nix-skills input, curated subset), only the
autonomous path that edits grind.md is blocked. The flake-input +
gitignore halves don't trip the denylist on their own but are
pointless without the link step.
