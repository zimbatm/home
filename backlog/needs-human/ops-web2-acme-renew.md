# ops: web2 acme-order-renew-gts.zimbatm.com — verify next timer fire

**needs-human** — root SSH to production. `kin ssh web2` refused by
harness for META (re-tested 2026-04-24 r1); drift's non-root probe gets
status but not journal.

## What

web2 redeployed gen-25 (Apr-24 20:06). acme-order-renew **cleared from
failed-state** post-deploy — `systemctl --failed` now 0 units (was 1).
But last invocation still shows `inactive (dead)` with exit
status=1/FAILURE at Apr 24 02:26 (pre-deploy). Next timer fire tells if
the redeploy + lego/acme churn since d7d1096 actually fixed it.

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

5min triage. Likely outcomes:
- Redeploy fixed it (lego/acme module changed in pending bumps) → close
- DNS-01 challenge token stale → `kin set` the DNS API secret, redeploy
- Rate-limited by Let's Encrypt → wait, or check if config thrashed

## Blockers

Explicit authorization for root SSH to web2. Or: wait for next drift
round to re-probe failed-units after the timer fires (daily cadence).
