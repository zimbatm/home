# ops: web2 acme-order-renew-gts.zimbatm.com — verify next timer fire

**needs-human** — root SSH to production. `kin ssh web2` refused by
harness for META (re-tested 2026-04-24 r1); drift's non-root probe gets
status but not journal.

## What

web2 redeployed gen-25 (Apr-24 20:06). Timer **fired post-deploy Apr-26
02:26 and FAILED again** (drift @ e960caf re-probe) — redeploy did NOT
fix it. `systemctl --failed` back to 1 unit. Status shows `IP: 0B in, 0B
out / IO: 248K read, 0B written / CPU: 53ms` — early-exit before any
network, smells like missing/unreadable secret or config, not a
DNS-01/LE issue. Next fire Mon Apr-27 02:26.

Pull the journal and verify:

```sh
kin ssh root@web2 -- systemctl status acme-order-renew-gts.zimbatm.com.service --no-pager -l
kin ssh root@web2 -- journalctl -u acme-order-renew-gts.zimbatm.com.service --no-pager -n 80
kin ssh root@web2 -- systemctl list-timers --no-pager | grep acme
kin ssh root@web2 -- 'openssl x509 -in /var/lib/acme/gts.zimbatm.com/cert.pem -noout -enddate 2>/dev/null || echo no-cert'
```

## Why

Cert renewal failure on a 15d-uptime host. If the cert is near expiry,
TLS for gts.zimbatm.com breaks. Drift was blind to this for ~16 rounds
while the home-fleet identity was absent; first live probe @ 139c681
showed degraded.

## How much

5min triage. Likely outcomes (re-ranked after Apr-26 0-byte-network failure):
- DNS-01 challenge creds missing/unreadable → `kin set` the DNS API secret, redeploy
- lego state dir perms/path broke across a module bump → check `/var/lib/acme/gts.zimbatm.com/`
- ~~Redeploy fixed it~~ — ruled out, fired+failed post-gen-25
- Rate-limited by Let's Encrypt → unlikely (0B network)

## Blockers

Explicit authorization for root SSH to web2. Or: wait for next drift
round to re-probe failed-units after the timer fires (daily cadence).
