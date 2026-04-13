# harness: gate must run iets eval, not just nix dry-build

## What

`CONFIG.fastCheck` in `.claude/grind.config.js` runs
`nix build --dry-run` per host. That uses regular nix, which allows IFD.
`kin deploy` uses `iets eval` for remote hosts, which **bans** IFD
(ADR-0011, IETS-0025). Result: grind merges IFD-introducing changes that
pass the gate but break deploy.

Hit on 2026-04-13: `adopt-crops-userland` added `cp.run-crops` →
tng → crane `mkDummySrc` reads `Cargo.toml` at eval time → IETS-0025
on `kin deploy @all`. Gate said green; deploy said no.

## Fix

Extend fastCheck to run iets per host (or `kin eval @all`, whichever
exposes the iets path):
```js
fastCheck: `nix eval .#nixosConfigurations --apply builtins.attrNames && \
  for h in ${HOSTS.join(' ')}; do \
    nix build .#nixosConfigurations.$h.config.system.build.toplevel --dry-run --quiet || exit 1; \
  done && \
  kin eval @all --quiet`  # or: iets eval -A nixosConfigurations
```

`kin` is in agentshell PATH; `iets` is wrapped by it. If `kin eval`
isn't a subcommand, find the iets entrypoint kin uses and call it.

## How much

~0.2r. One-line fastCheck change + verify it catches the run-crops case
(temporarily re-add it, confirm gate fails, revert).

## Blockers

None. agentshell has `kin`.
