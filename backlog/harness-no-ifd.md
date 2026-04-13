# harness-no-ifd

## What

Set `nixConfig.allow-import-from-derivation = false;` in flake.nix and
add `--no-allow-import-from-derivation` to the fast-check.

## Why

IFD forces a build during evaluation — eval blocks on the store, becomes
machine-dependent (different stores → different eval results), and
defeats lazy/pure eval. None of the assise siblings currently use it
(probed 2026-04 with `--no-allow-import-from-derivation`); the flag
makes accidental regressions loud at the gate instead of silently slow.

## How much

- flake.nix: add `nixConfig.allow-import-from-derivation = false;`
  (alongside any existing `nixConfig` attrs).
- grind.config.js fastCheck: where it's `nix flake check` or `nix eval`,
  append `--no-allow-import-from-derivation`. Where it's cargo-only,
  add a `checks.noifd` output that evals `.#packages.${system}` with
  the flag (or wait for `harness-fmt-and-checks` to land and fold it
  into that).

## Falsifies

`nix flake check --no-allow-import-from-derivation` passes. Adding a
deliberate IFD (`import (pkgs.runCommand "x" {} "echo {} > $out")`)
fails with "cannot build … during evaluation".
