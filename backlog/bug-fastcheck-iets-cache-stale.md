# bug: fastCheck iets legs defeated by warm ~/.cache/iets

## What

`.claude/grind.config.js` fastCheck legs 2 (warm iets eval) and 3
(cold-store iets eval) can return stale outPaths when `~/.cache/iets`
is warm from a prior round. Observed in bumper r4 @ 22bbd1c:

- Pre-round cache warm. Phase-1 internal bump → iets eval nv1 returned
  `49msj2c9` (≠ nix-eval `4pc9a44c`). Phase-2 home-manager bump → iets
  still `49msj2c9` (≠ nix-eval `zi5as60q`). `rm -rf ~/.cache/iets` →
  iets matches nix-eval on both states.
- `49msj2c9` matches neither origin/main (`n5smybmw`) nor either
  post-bump state — likely a prior-round intermediate.

Leg 1 (`nix flake check`) caught nothing wrong because nothing WAS
wrong — the bumps eval fine. But leg-2 parity and **leg-3 cold-store
IFD gate are silently no-ops** when the cache short-circuits the eval:
a cached outPath means no import-from-derivation runs against the cold
store, so the IFD escape the leg exists to catch (bug-kin-deploy-ifd-
recurs / IETS-0022/0025 maille fileset.toSource) goes undetected.

The config comment at L45 ("iets disk-cache keyed on inputs so a lock
change is cache-cold too") doesn't hold in practice.

## Why

False-green on the one leg designed to catch cold-store IFD before it
breaks `kin deploy`. 3× escapes already by 2026-04 per the L42 comment;
this would let a 4th through.

## How much

Minimal fix in grind.config.js — prefix legs 2+3 with cache bypass.
Either `rm -rf ~/.cache/iets &&` before each iets call, or set
`IETS_ATTRS_NO_CACHE=1` env if iets supports it (unconfirmed — `--help`
shows no such flag; `IETS_TYPES_NO_CACHE` exists for types.db only).
~+2 lines. Re-run cold-store leg after fix to confirm it actually
imports cold (should take ~40s not <1s).

Root cause is in iets — cross-filed
`../iets/backlog/bug-attrcache-stale-flake-shim.md`. Local fix is a
workaround until that lands + is bumped.

## Blockers

None. grind.config.js edit, not flake.lock — route to implementer not
bumper. Non-spine.
