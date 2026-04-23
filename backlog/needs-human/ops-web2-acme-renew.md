# ops: web2 acme-order-renew-gts.zimbatm.com.service failed

**needs-human** — root SSH to production; investigate before deploy.

## What

`kin status` (first live probe after 16-round identity outage, restored
@ 139c681) shows web2 degraded:

```
✗  web2  26.05.20260418.b121…  active  degraded  15d1h36m  acme-order-renew-gts.zimbatm.com.service
```

Pull the journal and triage:

```sh
kin ssh root@web2 -- systemctl status acme-order-renew-gts.zimbatm.com.service --no-pager -l
kin ssh root@web2 -- journalctl -u acme-order-renew-gts.zimbatm.com.service --no-pager -n 80
kin ssh root@web2 -- 'openssl x509 -in /var/lib/acme/gts.zimbatm.com/cert.pem -noout -enddate 2>/dev/null || echo no-cert'
```

## Why

Cert renewal failure on a 15d-uptime host. If the cert is near expiry,
TLS for gts.zimbatm.com breaks. Drift was blind to this for ~16 rounds
while the home-fleet identity was absent.

## How much

5min triage. Likely outcomes:
- DNS-01 challenge token stale → `kin set` the DNS API secret, redeploy
- Rate-limited by Let's Encrypt → wait, or check if config thrashed
- Upstream lego/acme module change in the pending bumps → deploy fixes it

## Blockers

Explicit authorization for root SSH to web2.
