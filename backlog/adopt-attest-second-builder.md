# adopt: home as second attestation builder — ops remainder

**needs-human** — module is wired (`services/attest.nix` registered via
`extraServices` in flake.nix, ported from kin-infra@4f04e4c). What's left
is key custody + deploy, which the grind loop cannot do.

## What remains

1. Uncomment `services.attest.on = [ "web2" ];` in kin.nix.
2. `kin gen` — mints `gen/attest/signing-key/{key.age,_shared/public}`.
   Requires `zimbatm-yk` (age-plugin-yubikey) present; the loop has no
   YubiKey. Commit the gen/ output.
3. `kin deploy web2`.
4. Later, once `../iets/backlog/feat-attest-log-cli.md` ships: set
   `services.attest.package = inputs.iets.packages.${system}.iets;` to
   activate the systemd unit + post-build-hook (currently gated on
   `package != null`).

## Why

threshold=2 is the actual trust story — single-builder attestation is
no stronger than a signed cache. kin-infra is builder #1; home web2 is
the genuinely independent #2 (different cloud, different operator key
custody, different fleet CA).

## Falsifies

Cross-fleet CA reproducibility: build the same `../collection` drv on
kin-infra hcloud-02 and home web2; if `output_hash` differs, M-of-N
across independent builders is dead and the non-determinism source is
the real next item.
