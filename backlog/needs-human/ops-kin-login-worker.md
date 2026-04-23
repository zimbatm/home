# ops: `kin login` on grind worker (home fleet identity absent)

**needs-human** — `kin login` requires the hardware key.

## What

On the grind worker, restore the home-fleet ssh identity:

```sh
cd /root/src/home && kin login   # writes ~/.ssh/kin-bir7vyhu_ed25519{,-cert.pub}
kin status --json | jq '.hosts[].have'   # expect non-empty for relay1+web2
```

## Why

drift @ e969d2c (e301f49): `kin status` → all 3 hosts `have=""`
(nv1 not-on-mesh, relay1+web2 unreachable). `~/.ssh/kin-bir7vyhu_ed25519`
is gone; only kin-infra's `kin-dwqfzbq5` present (mtime 2026-04-15).
`gen/ssh/_shared/config:3` references the bir7vyhu path. drift carried
forward stale `have` hashes from 53bed8f instead of probing live —
degrades drift signal (can't confirm interim deploys).

2nd loss (1st: 2026-04-12 @ b1e05ae, see `tried/ssh-config-contention.md`).
kin-side durable fix `feat-ssh-per-fleet-identity` has since **landed**
(kin 959caa93) — namespaced paths no longer clobber across fleets, so
this re-login should stick.

## How much

~30s with the hardware key plugged in.

## Blockers

Hardware key. Worker can't self-heal.

## Update @ 0beecde (2026-04-23)

`kin-dwqfzbq5*` (kin-infra fleet) is **now also gone** — was present
mtime Apr-19-10:47 through r7. Only `kin-infra-hosts` (known_hosts file,
not an identity) remains in `~/.ssh/`. Likely homespace ephemeral state
loss between r7 and this round. **Both** fleets now need `kin login`.
