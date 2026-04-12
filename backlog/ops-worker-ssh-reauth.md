# ops-worker-ssh-reauth — grind worker lost fleet ssh access

## what
`kin status` from the grind worker returns `unreachable` /
`not-on-mesh` for **all three hosts** as of 2026-04-12. Hosts ping
fine; sshd answers; auth is rejected:
```
claude@95.216.188.155: Permission denied (publickey)
root@95.216.188.155:   Permission denied (publickey)
```
Worked @ 9403a95 (2026-04-11). Broke overnight.

## why
The worker's ssh keypair was **rotated locally** (mtimes:
`~/.ssh/kin-infra_ed25519` 2026-04-12 00:50, `~/.ssh/id_ed25519`
03:42). New pubkey:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeTgAfmrKax1TAMTiv/D8IImSRfnELGamSJvDqfQt21 claude@kin-infra
  SHA256:d4hLpc9cQO/wyv9DZ511kq0LuGaEr0ysWUiMF69WFMU
```
Neither auth path accepts it:
1. **Static key** — `kin.nix` users.claude.sshKeys still lists the
   *old* key `…IJ4A37V7FWTQgVqVNw+Ub+2AyRAgkll0ZBX6udc/C1E6`
   (SHA256:q+vuWh4nSDy4OwnoSMs+qnPo4N1xMk+0qhaCc7+g7no). Mismatch.
2. **CA cert** — worker has `id_ed25519-cert.pub` valid
   2026-04-11→2027-04-10, principals root+claude, but it's signed by
   the **kin-infra** fleet CA
   (SHA256:19wpMsGzu3fOEuNVXQXG+OWSiqCKDCd4PK2fROGyXfs, fleet
   `dwqfzbq5…`). home's deployed sshd trusts only home's CA
   (gen/identity/ca/_shared/ssh-ca.pub →
   SHA256:K8GPw7xnxqRhz0kZi4JvIeJdZL3uoAlsUmuFY+afR0I, fleet
   `bir7vyhu…`). Wrong CA → cert rejected.

`gen/identity/user-claude/_shared/certs` holds a home-CA cert, but
for the *old* key (`…IJ4A37V7…`) — useless without that private key.

## reconcile (human)
Pick one, then redeploy from a machine Jonas's own key reaches:

**A. Update the static key (simplest):**
```nix
# kin.nix
users.claude.sshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeTgAfmrKax1TAMTiv/D8IImSRfnELGamSJvDqfQt21 claude@kin-infra" ];
```
Then `kin gen && kin deploy @all`. Breaks again on next rotation.

**B. Re-cert the new key with home's CA (durable until next rotation):**
`kin login claude --key ~/.ssh/id_ed25519.pub` from a machine that
can decrypt `gen/identity/ca/_shared/ssh-ca.age` (i.e. an admin age
recipient — Jonas or yubikey). Writes a new
`gen/identity/user-claude/_shared/certs`, then deploy.

**C. Cross-trust kin-infra's CA (structural, no re-work on rotation):**
Add kin-infra's user-CA pubkey as a second `TrustedUserCAKeys` entry
on home hosts. The worker is a kin-infra runner; its key rotates with
that fleet. If home is meant to be drivable from kin-infra runners
long-term, this is the assise-honest fix — file the gap in
`../meta/backlog/` if chosen.

## blockers
Human-gated: needs an ssh path Jonas's key still has (zimbatm sshKeys
unchanged), and/or age decrypt rights for home's CA. Chicken-and-egg
for the worker itself.

## impact
Until fixed, drift-checker is **blind** — can compute `want` but not
`have`. drift-{nv1,relay1,web2}.md this round carry structural drift
only (d90e847 known-undeployed), no live diff-closures.
