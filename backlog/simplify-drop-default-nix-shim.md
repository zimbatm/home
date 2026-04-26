# simplify: drop default.nix flake-shim

## Status

Partial-landed (mirrors kin-infra @46eafa0e). `.envrc` no longer reads
`default.nix`; the shim stays only for kin's `Iets.eval_attr`.

- [x] `.envrc` iets arm → `iets-compat iets-flake build ".#packages.$sys.devshell"`
      (SC2016 disable dropped; fallback/watch_file/PATH_add unchanged)
- [x] `watch_file` line — `default.nix` was never listed; no-op
- [x] `default.nix` — consumer-tracking comment prepended
- [ ] `git rm default.nix` — **blocked**, see below

## Remaining

`git rm default.nix` once BOTH hold:

1. `../kin/backlog/feat-evaluator-iets-flake-entrypoint.md` lands
   (`../kin/cli/kin/evaluator.py` `Iets.eval_attr` stops doing
   `import {root}/default.nix`)
2. a kin bump past that fix is pinned in `flake.lock` here

Gate for the final drop: `kin gen --check` green with `default.nix`
absent; `nix develop -c iets eval default.nix -A …` step removed from
the grind gate (or retargeted at the flake entrypoint).

Once home + kin-infra + fleet all drop, kin's `lib/flake-shim.nix`
(142L + 4 tests + 2 fixtures) deletes — no fetchTarball consumers left.

## What (context)

`default.nix` is a 20-line bootstrap shim (read flake.lock → fetchTarball
kin → `import (kinSrc + "/lib/flake-shim.nix") ./.`). `iets-compat
iets-flake build` now does the lock-resolve in Rust, so the `.envrc`
consumer is gone (proven collection@50297a3e, kin-infra@46eafa0e, here).
kin-infra@2f4c9454 showed `.envrc` is NOT the only consumer —
`kin gen --check` breaks without it via evaluator.py.
