# ops-gen-stale — `kin gen --check` red on main (10 generators)

## What
`nix run ../kin# -- gen --check` exits 1: identity/ca/_shared,
identity/machine/{nv1,relay1,web2}, and 6 others report
`stale: (script/inputs changed)`. Reproduces at a49dc10 and 369f627
identically — pre-dates the hosts→machines rename. Also reproduces with
pinned kin d28f09fd, so not ../kin checkout drift.

## Why
gen/manifest.lock is stale vs current generator inputs. Likely the
fbe5687/aa336d3 kin bumps changed generator scripts without a
corresponding `kin gen` run here.

## How much
`kin gen` (CLAUDE.md lists as safe) then review the gen/ diff. Touches
identity/ca + per-machine certs — confirm no key rotation implied
before committing. If certs change, deploy is needed; if only
manifest.lock hashes change, commit-only.

## Blockers
Human review of gen/ diff (identity material).
