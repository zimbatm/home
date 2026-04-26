# simplify: drop default.nix flake-shim

## What

`default.nix` is a 20-line bootstrap shim (read flake.lock → fetchTarball
kin → `import (kinSrc + "/lib/flake-shim.nix") ./.`) that exists only so
`.envrc` can `iets build -E '(import ./default.nix)...'` without
`builtins.getFlake`.

`iets-compat iets-flake build` now does the lock-resolve in Rust
(dispatches `"iets-flake"` → `iets_flake::run`; `--print-read-paths=N`
supported). The Nix-level shim is dead indirection. Proven on collection
@50297a3e (`.envrc` iets-compat arm green).

## Change

1. `.envrc:9-11`: rewrite the iets arm from
   ```sh
   if has iets \
      && out=$(iets build --print-read-paths=3 \
                 -E '(import ./default.nix).packages.${builtins.currentSystem}.devshell' \
   ```
   to
   ```sh
   if has iets-compat \
      && sys=$(iets-compat nix eval --raw --impure --expr builtins.currentSystem) \
      && out=$(iets-compat iets-flake build ".#packages.$sys.devshell" --print-read-paths=3 \
   ```
   (keep the `2>/dev/null` / nix-fallback structure as-is; collection's
   `.envrc` is the reference shape).
2. `git rm default.nix`
3. Drop `default.nix` from any `watch_file` line.

## Gate

`direnv reload` in a shell with `iets-compat` on PATH → devshell loads,
read-paths watch list non-empty. Then same with only cppnix on PATH →
nix fallback arm still fires. `nix eval .#nixosConfigurations --apply
builtins.attrNames` unchanged.

Net −20L. Once home + kin-infra + fleet all land, kin's
`lib/flake-shim.nix` (142L + 4 coverage tests + 2 fixtures) deletes —
no remaining fetchTarball consumers.

## Blocker — second consumer found

kin-infra tried this @2f4c9454 and broke `kin gen --check`:
`../kin/cli/kin/evaluator.py:254` `Iets.eval_attr` does
`import {root}/default.nix` — `.envrc` is NOT the only consumer. home's
grind runs `kin deploy` (grind.config.js:73) so `git rm default.nix`
will fail the same way.

**Partial-land option** (what kin-infra kept @46eafa0e): do step 1+3
only — migrate `.envrc` to `iets-compat iets-flake build`, keep
`default.nix` with a consumer comment. Then `git rm default.nix` after
`../kin/backlog/feat-evaluator-iets-flake-entrypoint.md` lands and a
kin bump past it is pinned here. kin-infra/default.nix has the
reference comment shape.
