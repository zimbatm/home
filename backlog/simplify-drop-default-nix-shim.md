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
