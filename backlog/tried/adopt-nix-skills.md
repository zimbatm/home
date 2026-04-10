# tried: adopt-nix-skills

## Outcome
Abandoned pre-merge (2026-04-10). Scope violation — denylist hit.

## Why abandoned
Branch edited `.claude/commands/grind.md`. That file is on the grind
denylist: the grind harness is not permitted to modify its own
definition from inside a round. The backlog item's "What" explicitly
calls for patching the grind.md launch step, so the task as written
cannot be executed by /grind.

Worktree `/root/src/home-grind/adopt-nix-skills` and branch
`grind/adopt-nix-skills` force-removed; no diff salvaged.

## Re-attempt when
A human applies the `.claude/commands/grind.md` change out-of-band
(grind-base or direct commit), then re-files a reduced backlog item
covering only the in-scope parts: add `inputs.nix-skills` to
flake.nix + gitignore `.claude/commands/nix-*.md`. Those are
grind-safe.

## Note
`backlog/adopt-nix-skills.md` left in place (matches origin/main) so
the reduced re-file can reuse it after the human edits land.
