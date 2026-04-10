# tried: simplify-flake-internal-module-exports

## Outcome
Abandoned pre-merge (2026-04-10). Scope violation — denylist hit.

## Why abandoned
Branch edited `flake.lock`. That file is on the grind denylist:
lockfile changes are bumper-only (one input per round, oldest-first),
never a side-effect of a simplifier task. The backlog item is scoped
as "pure flake.nix edit, no eval/build impact" — touching flake.lock
is out of bounds regardless of why it drifted.

Worktree `/root/src/home-grind/simplify-flake-internal-module-exports`
and branch `grind/simplify-flake-internal-module-exports` force-removed;
no diff salvaged.

## Re-attempt when
Next simplifier round. The task itself is sound — drop 5 unused
`nixosModules`/`homeModules` exports from flake.nix (or
comment-and-wontfix per ADR-0006). Re-attempt must confine the diff to
`flake.nix` only; if a `nix` invocation wants to rewrite flake.lock,
pass `--no-update-lock-file` / `--no-write-lock-file` and discard.

## Note
`backlog/simplify-flake-internal-module-exports.md` left in place
(matches origin/main) so the next round can pick it straight back up.
