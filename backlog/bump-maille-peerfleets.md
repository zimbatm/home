# bump: maille input → ≥eaefaae for peerFleets options

## what

`nix flake lock --update-input maille` to pull pin past eaefaae
(feat-mesh-peer-fleets-config p1). Current pin b849d73 is 38 commits
behind and lacks `services.mesh.peerFleets` / `services.identity.peers`
option definitions — verified `nixosConfigurations.relay1.options.services.mesh.peerFleets`
does not exist at b849d73.

## why

Unblocks backlog/adopt-peer-kin-infra.md (ADR-0011 reciprocal). The
kin.nix delta there references both option paths; adding them now fails
the eval gate with "option does not exist".

## how-much

```sh
nix flake lock --update-input maille
```

Gate: all 3 hosts (nv1, relay1, web2) eval + dry-build. 38 commits in
range — skim `git -C ../maille log --oneline b849d73..` for breaking
renames before gating.

## blockers

None — bump-* prefix has lock-write per merge denylist.
