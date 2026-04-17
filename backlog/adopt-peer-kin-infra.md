# adopt: services.{identity.peers,mesh.peerFleets}.kin-infra — ADR-0011 reciprocal

## what

kin-infra@grind/adopt-mesh-peerfleets-federation landed its half of the
ADR-0011 cross-fleet federation pair: `identity.peers.home` (this fleet's
CA as trust anchor) + `mesh.peerFleets.home.seeds = ["95.216.188.155:7850"]`
(relay1). This is the reciprocal — without it, kin-infra dials relay1 and
relay1's maille rejects the leaf (unknown CA).

## kin.nix delta

```nix
services.identity.peers.kin-infra.tlsCaCert =
  builtins.readFile ./keys/peers/kin-infra-ca.crt;
services.mesh.peerFleets.kin-infra.seeds = [ "5.75.246.255:7850" ];
```

`keys/peers/kin-infra-ca.crt` ← `../kin-infra/gen/identity/ca/_shared/tls-ca.crt`
(O=assise, URI-SAN `assise://dwqfzbq5zxrlhfhcub6fsaeb4zitwfxa/ca`). Seed
is kin-infra hcloud-01 (ingress-tagged); port 7850 = kin default.

Then `kin gen` mints `gen/identity/peers/_shared/{kin-infra-ca.crt,
kin-infra-fleet-id,trust-bundle.crt}`.

## why

- 0/2 dogfood for `services.mesh.peerFleets` (kin@a8d56b76); home×kin-infra
  is the only pair available.
- Concrete pull: kin-infra set `services.cache.exportTo = ["home"]` —
  federating gives this fleet `cache.assise.systems` as a substituter
  over mTLS without going through public ingress.
- Falsifies ADR-0011 cross-fleet mTLS (per-fleet CA accept, not shared root).

## blockers

- BLOCKED on backlog/bump-maille-peerfleets.md — pin b849d73 lacks
  eaefaae; CA cert already staged at keys/peers/kin-infra-ca.crt.
- maille p2 (dial-seeds runtime) for the actual cross-fleet dial; p1 is
  config+union-CA-verifier only.

## how-much

~4 lines kin.nix + 1 committed PEM + `kin gen` round.

## falsifies

A relay1/web2 host dials 5.75.246.255:7850, presents its home-CA leaf,
kin-infra hcloud-01 accepts via `peers/home/ca.crt` trust anchor (and
vice versa). Then `nix-store --realise` against kin-infra cache over the
peer mesh proves the exportTo/cedar leg.

(kin-infra cross-file — see ../kin-infra/backlog/adopt-mesh-peerfleets-federation.md)
