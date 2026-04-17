# bump: kin input → ≥a8d56b76 for services.mesh.peerFleets option

## what

`nix flake update kin` to pull pin past a8d56b76 (mesh:
peerFleets.<label>.seeds option + [peer.*] toml emit). Current pin
2785e63 lacks the option definition entirely — verified
`inputs.kin/services/mesh.nix` defines only `on`/`relay`/`port`/
`bindAllow`, and `inputs.kin/services/maille-caps.nix` has no
`peerFleets` cap.

bump-maille-peerfleets only moved the transitive `kin/maille` node
(b849d73→156486c, `peer_fleets` field present in src/config.rs). That
satisfies the maille-side `caps.peerFleets` probe but the probe itself
doesn't exist at kin@2785e63 — the option path is the actual blocker.

## why

Unblocks backlog/adopt-peer-kin-infra.md (ADR-0011 reciprocal). The
kin.nix delta there sets `services.mesh.peerFleets.kin-infra` and
`services.identity.peers.kin-infra`; both throw "option does not exist"
at kin@2785e63.

## how-much

```sh
nix flake update kin
```

371 commits in range (2785e63..6dc3fea8). Relevant for this:
a8d56b76 (peerFleets option), f2d7cb96 (label charset guard),
657e7ceb (peerFleets ⊆ identity.peers throw), 81f64154 (extraCerts →
static_certs), 7c17f57e (kin's own maille bump → e562c6d).

`nix flake update kin` re-resolves `kin/maille` from kin's lock
(e562c6d at 7c17f57e — still ≥eaefaae, so `caps.peerFleets` stays
true). Gate: `kin gen --check` then all 3 hosts eval + dry-build. Large
range — skim for `gen/` schema changes; if `kin gen --check` reports
drift, run `kin gen` and include the regenerated files.

## blockers

None — bump-* prefix has lock-write per merge denylist. Does not touch
kin.nix.
