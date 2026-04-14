# adopt-assise-cache

## What

Add `cache.assise.systems` (kin-infra's `services.cache`, key
`cache.assise.systems-1`) to home's substituters so nv1/relay1/web2 pull
pre-built kin/maille/iets/tng closures instead of rebuilding on every
input bump.

## Why

home and kin-infra are separate fleets; kin's `services.cache`
auto-wires substituters intra-fleet (mesh ULA at
`http://[${machineIp6}]:port`, kin/services/cache.nix:92) but not
cross-fleet. Every kin bump currently rebuilds the world on Jonas's
machines. The federation cache (Track G, M-of-N attestation via
`kin.attest`) is exactly for this.

## How

`modules/nixos/common.nix:23` substituters list — append (or replace
the `mkForce` with `mkDefault` + explicit list including assise). Two
shapes:

- **(a) public HTTPS** — `https://cache.assise.systems` if kin-infra
  exposes it via `services.ingress` (check `kin-infra/kin.nix` for a
  route). Works without mesh.
- **(b) cross-fleet mesh** — if home federates with kin-infra (CA
  exchange per ADR-0011), the mesh-ULA URL works directly. Cleaner
  (one transport) but needs the federation step.

Either way: add the public key to `trusted-public-keys`. With
`kin.attest` + `ietsd substitute-proxy` (live both dogfoods), home can
also require quorum on what it pulls — that's
`services.attest.quorum` config, separate item.

## Blockers

- Is `cache.assise.systems` reachable over public HTTPS, or mesh-only?
  (`curl https://cache.assise.systems/nix-cache-info` from outside)
- The `mkForce` on substituters means kin's `mkAfter` from
  services.cache wouldn't compose even if home declared it — may need
  to drop the force.

## Falsifies

`nix path-info --store https://cache.assise.systems <some-kin-drv>`
returns a hit; bumping kin in home and `nixos-rebuild --dry-run` shows
substitutes from assise instead of local builds.
