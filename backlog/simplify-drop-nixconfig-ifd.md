# simplify-drop-nixconfig-ifd

## What

Remove `nixConfig.allow-import-from-derivation = false;` from flake.nix.
Keep the `--no-allow-import-from-derivation` flag in fastCheck (and
`checks.no-ifd` if present) — those are the gate.

## Why

The nixConfig line prompts users for flake-config trust on first
`nix build`/`nix develop` ("do you want to allow configuration setting
allow-import-from-derivation"). Annoying, and the CLI flag in fastCheck
already enforces the invariant. kin-infra's own apply-commit noted
"nixConfig warns untrusted on this runner — the CLI flag is the
enforcer".

## How much

One-line delete from flake.nix `nixConfig` block (or drop the block if
this was the only attr). If `checks.no-ifd` isn't already there, add it
per the original `harness-no-ifd` falsifier so `nix flake check`
still catches regressions.

## Falsifies

`nix develop` / `nix build` no longer prompts; `nix flake check
--no-allow-import-from-derivation` still passes; injected IFD still
fails.
