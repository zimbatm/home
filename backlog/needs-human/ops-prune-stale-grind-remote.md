# ops: prune stale remote grind/add-claude-deployer

## What

```sh
git push origin --delete grind/add-claude-deployer
```

Remote branch at 86674b3 ("kin.nix: add users.claude deployer"). Work
landed independently as 4fca942 on main. 86674b3 is NOT an ancestor of
main (redone, not merged) — eyeball `git diff 86674b3 4fca942 -- kin.nix`
before deleting to confirm nothing was dropped.

Local branch already pruned r7.

## Why

Carried in META commit messages r4→r10 (7 rounds). Filing so it stops
being a commit-message-only note and shows up in the needs-human queue.

## Why needs-human

Remote-write + unmerged SHA. META won't push --delete on a non-ancestor.

## How much

~30s.
