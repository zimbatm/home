# bump: flake.lock follows-dedupe (22→30 nodes after d90e847)

## What

bumper @ d90e847 bumped kin/iets/nix-skills/llm-agents; lock grew 22→30
nodes with +8 dup transitives: `blueprint_3 bun2nix_2 flake-parts_3
import-tree_2 llm-agents_2 systems_4 treefmt-nix_2 treefmt-nix_3`.
bumper flagged "follows-dedupe is simplifier territory".

Prior state (7d7d12c, 3rd clean sweep): 22 nodes, dups
`blueprint_2 flake-parts_2 systems_2/3`.

## Why

+36% lock nodes is closure bloat + eval cost. Several are deduppable via
`inputs.<x>.inputs.<y>.follows` in flake.nix without behavior change.

## How much

Inspect `nix flake metadata --json | jq .locks.nodes` for the dup
chains; add `follows` for the ones where home's pinned version
satisfies the consumer (nixpkgs/systems/flake-parts are usually safe;
blueprint/treefmt-nix check version compat first). Re-lock, gate
eval+dry-build all 3 hosts.

Candidates by safety:
- `systems_4` → follows root systems (trivial)
- `flake-parts_3` → follows root or _2 (check kin/iets compat)
- `llm-agents_2` → home already has llm-agents direct; whoever pulls
  _2 should follow root
- `treefmt-nix_2/_3` → home has no root treefmt-nix yet (see
  backlog/bump-add-treefmt-nix-input.md); dedupe between transitives
  only, or land that first and follow root
- `blueprint_3 bun2nix_2 import-tree_2` → check who pulls them

## Blockers

None. `bump-*` prefix grants the flake.lock-write exemption at merge.

## Falsifies

`jq '.nodes|length' flake.lock` < 30 after; all 3 hosts eval+dry-build.
