# adopt: home as second attestation builder (threshold=2 enabler)

## What

One home machine (web2 — always-on, hetzner, distinct infra from
kin-infra's hcloud) signs CA-build attestations with a home-fleet
ed25519 builder key and serves its `AttestationLogService` over the
mesh. Same wiring as `../kin-infra/backlog/adopt-attest-builder-publish.md`
applied here: post-build hook → `sign_attestation` → `Append` to local
log; log + CAS exposed at `kin://<home-fleet-id>/service/attest`.

Publish the home builder pubkey via `fleet.genPublic` so consumers
(crops-demo's `crops.attestation.trustedKeys`, kin-infra's own
substituter) can list it.

## Why

threshold=2 is the actual trust story — single-builder attestation is
no stronger than a signed cache. kin-infra is builder #1; home is the
genuinely independent #2: different cloud provider, different operator
key custody (Jonas's YubiKey vs assise infra admin), different fleet CA.
A consumer trusting `{kin-infra, home}` at threshold=2 gets a real
"two unrelated parties built this and agreed" guarantee.

Also dogfoods the publish path on the second fleet — if it only works
on kin-infra, it's not a pattern.

## How much

~0.5r once the kin-infra item lands and proves the shape. This is the
same `services/attest.nix` (or whatever kin-infra ends up with)
instantiated in `kin.nix` with `on = "web2"`. If the kin-infra work
lifts into a kin builtin service, this collapses to one line.

## Blockers

- `../kin-infra/backlog/adopt-attest-builder-publish.md` — proves the
  wiring first; don't duplicate the exploration.
- needs-human: `kin gen attest/signing-key` for the home fleet + `kin
  deploy web2`.

## Falsifies

Cross-fleet CA reproducibility: build the same `../collection` drv on
kin-infra hcloud-02 and home web2; if `output_hash` differs, M-of-N
across independent builders is dead and the non-determinism source
(kernel? glibc? locale?) is the real next item.
