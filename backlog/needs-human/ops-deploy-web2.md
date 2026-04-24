# web2: post-deploy runtime checks (CONVERGED gen-25; relay1 gen-16)

**What:** Walk the remaining runtime checks below on web2, then delete
this file. Deploy itself is **done** — web2 + relay1 both human-deployed
Apr-24 20:06 batch @ fcc6b68-tip and CONVERGED.

**Blockers:** Human-gated. Non-root probe (kin-bir7vyhu) covers
service-level (0 failed units verified by drift); the unchecked items
below need root SSH or at-the-host verification, refused by harness for
META.

## Status (drift @ fcc6b68, 2026-04-24)

```
web2:   have c27fxv31… == want c27fxv31…  (gen-25, 2026-04-24 20:06)  0 failed units
relay1: have xmb9mkd4… == want xmb9mkd4…  (gen-16, 2026-04-24 20:06)  0 failed units
```

Both carried 0 since deploy; 778e7b8 was the last closure-affecting
commit. Dry-build web2 158/76/285.5M, relay1 71/9/140.7M. acme-degraded
cleared from failed-state by redeploy (last-run pre-deploy still
status=1; next timer tells — see ops-web2-acme-renew.md).

## Runtime checks — web2 (3/8 PASS via drift spot-check, 5 remain)

| check | status | command |
|---|---|---|
| peer-fleet /48 route | **PASS** | `ip -6 route show dev kinq0 \| grep fdc5:e1a6:b03f::/48` present |
| CA derivations | **PASS** | `nix config show \| grep ca-derivations` enabled |
| cache.assise substituter | **PASS** | `nix config show \| grep substituters` lists cache.assise.systems |
| peer-kin-infra trust | unverified | `grep '@cert-authority' /etc/ssh/ssh_known_hosts` includes kin-infra CA; `maille config show \| jq .peer_fleets` lists kin-infra |
| pin-nixpkgs dropped | unverified | `nix registry list \| grep nixpkgs` and `echo $NIX_PATH` resolve to system pin |
| attest identity | unverified | `ls /run/kin/identity/attest.*` exists |
| restic-gotosocial | unverified | `systemctl status restic-backups-gotosocial.{service,timer}` active |
| acme-order-renew | next-timer | see ops-web2-acme-renew.md |

relay1: /48 route PASS + 0 failed units (drift @ fcc6b68); same 5
remain unverified (root SSH denied to META) but 0-failed-units covers
service-level.

---

## drift append-log

(drift-checker appends new `### drift @ <rev>` sections below; META
re-compacts into the table above when this section exceeds 3 entries)

<!-- restructured @ b236e97 (META r1, 2026-04-24): web2 CONVERGED gen-25 — header "redeploy (drifted)" stale, folded carries-8 table + fcc6b68 append into 3-PASS/5-remain checks table. relay1 history retained: split from ops-deploy-relay1-web2.md @ META r1 2026-04-24, converged gen-15 @ xzzh4496 Apr-24 10:29, gen-16 Apr-24 20:06. -->
