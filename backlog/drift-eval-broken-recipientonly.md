# Eval broken on all hosts: `users.*.recipientOnly` not in pinned kin

## What

`nix eval .#nixosConfigurations.<host>.config.system.build.toplevel`
fails identically for nv1/relay1/web2 at origin/main (fedacd7):

```
error: The option `users.zimbatm-yk.recipientOnly' does not exist.
       Did you mean `users.zimbatm-yk.admin', `users.zimbatm-yk.profile'
       or `users.zimbatm-yk.groups'?
```

Gate (all 3 hosts eval+dry-build) is RED. No deploy possible.

## Why

home@1e2cd8d (2026-04-08 20:12) added `recipientOnly = true` to
`users.zimbatm-yk` in kin.nix. The commit message reads "on=[] kept for
compat with current kin pin" — but `recipientOnly` itself is the
incompat: the pinned kin (ba1f278, locked 2026-04-08) predates the
option entirely. kin gained it in a0b42b3 (`spec:
users.<n>.recipientOnly`), with a follow-up 5d387b8 that defaults
`on = []` when recipientOnly is set.

So kin.nix drifted ahead of the locked kin schema. Not a kin
regression — home jumped the pin.

## How much

Bump kin past a0b42b3 (prefer past 5d387b8 so the redundant `on = []`
in kin.nix can also drop). One-line `nix flake update kin`, then
re-gate all 3 hosts.

Alternative if the kin bump is blocked for other reasons: revert the
`recipientOnly = true;` token from kin.nix (keep `on = []`) until the
bump lands. Strictly worse — re-opens the foot-gun 1e2cd8d closed.

## Blockers

None. Bumper round can take it (kin is priority-2 after nixpkgs, and
this is a forced bump regardless of age).

## Falsifies

After bump: `nix eval
.#nixosConfigurations.relay1.config.system.build.toplevel.drvPath`
succeeds. If it still fails on `recipientOnly`, the bump didn't reach
a0b42b3 — check `nix flake metadata --json | jq
.locks.nodes.kin.locked.rev` and `git -C ../kin merge-base --is-ancestor
a0b42b3 <rev>`.

---

## Drift-check status (2026-04-09)

Per-host deployed-vs-declared: **cannot check** — fleet still
unreachable from grind container (nv1 mesh-unroutable, relay1/web2
publickey-denied). Re-verified 2026-04-09; unchanged from
ops-grind-fleet-access.md. Not filing drift-{nv1,relay1,web2}.md
duplicates.

flake.lock staleness: **all 9 direct inputs ≤5 days old** (oldest:
nixvim 2026-04-04). No bump-* filed.
