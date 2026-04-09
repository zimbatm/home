# Re-run `kin gen` to materialize gen/_fleet/ (ula-prefix migration)

## What

`gen/_fleet/_shared/{fleet-id,ula-prefix}` doesn't exist here; both
files still live only at the legacy `gen/identity/ca/_shared/` path.
kin (post-eff8298) reads `gen/_fleet/_shared/ula-prefix` first and
falls back to the legacy path. kin wants to drop the fallback but
can't while a dogfood still depends on it (kin-infra already
migrated; this repo is the last holdout).

Run `kin gen` — the `_fleet` core generator's migration read copies
the existing fleet-id/ula-prefix from `gen/identity/ca/_shared/` via
`$KIN_GEN_ROOT`, so the address plan is preserved (no mesh renumber).
Commit the resulting `gen/_fleet/` + updated `gen/manifest.lock`.

## How much

`kin gen` + commit. Net +2 small files under `gen/_fleet/_shared/`.
Verify: `diff gen/identity/ca/_shared/ula-prefix gen/_fleet/_shared/ula-prefix`
is empty (migration copied, didn't regenerate).

## Blockers

Needs a kin pin that includes the `_fleet` core gen (eff8298). If
`nix flake metadata --json | jq .locks.nodes.kin` predates that, bump
kin first (bumper round, or piggyback on cleanup-drop-kinstatus-reexport
which has the same blocker).

## Falsifies

If `kin gen` produces a *different* ula-prefix than the legacy file,
the `$KIN_GEN_ROOT` migration read in kin's `lib/manifest.nix` is
broken — file `../kin/backlog/bug-fleet-gen-migration-read.md` and do
NOT commit the new gen/ (would renumber the mesh).

Once landed, file `../kin/backlog/cleanup-drop-ula-legacy-fallback.md`
so kin can drop the `gen/identity/ca/_shared/ula-prefix` read in
`lib/default.nix` + `lib/manifest.nix`.
