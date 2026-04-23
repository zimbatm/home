# adopt: identity.peers.kin-infra.net — peer-fleet /48 over kinq0

## what

Add `services.identity.peers.kin-infra.net = "fdc5:e1a6:b03f";` next to the
existing `peers.kin-infra.tlsCaCert` (kin.nix:67). This is kin-infra's
`gen/_fleet/_shared/ula-prefix`. Renders `[fleet.<id>].net` in maille.toml so
maille installs `ip -6 route add fdc5:e1a6:b03f::/48 dev kinq0` and forwards
matching packets over the held peer-fleet conn (feat-mesh-peer-fleets-tun;
maille config.rs PeerFleet.net).

## why

../kin-infra/backlog/adopt-mesh-peerfleets-outbound-cedar.md leg-2 (ADR-0021
cedar exportTo curl-pair) needs `curl http://[<kin-infra-svc-ULA>]:PORT` from
a ../home host. Probed 2026-04-23 16:25 from web2: `ip -6 route show dev
kinq0` has only own-/48 fd0c:3964:8cda::/48 — **no route to
fdc5:e1a6:b03f::/48**, so the curl-pair has no datapath. web2's deployed
maille.toml `[fleet."dwqfzbq5…"]` has seeds+ca but no `net=` (default
sidecar-only; web2 has no `[svc.*]` either). Reciprocal already landed
kin-infra side (`identity.peers.home.net = "fd0c:3964:8cda"`).

## how-much

One-line kin.nix delta + `kin gen` + redeploy relay1/web2/nv1. Gated on
`caps.peerFleetNet` (throwIf in kin services/mesh.nix:290) — needs the
already-pending maille≥148eccd redeploy anyway (relay1/web2 still on
0.2.1578). Couples with `ops-deploy-relay1-web2` (same redeploy unblocks
both this and kin-infra leg-1 outbound-hold).

## blockers

- relay1/web2 redeploy with maille supporting PeerFleet.net (current
  deployed 0.2.1578; want-closure already has maille→2bd47c55 ⊇ feat).

## falsifies

feat-mesh-peer-fleets-tun raw-TUN datapath under a real two-dogfood
federation (vs the kin VM test). Unblocks ADR-0021 cedar curl-pair from
the ../home side.
