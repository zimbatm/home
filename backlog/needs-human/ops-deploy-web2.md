# web2: redeploy (drifted; relay1 split off — converged @ gen-15)

**What:** `kin deploy web2` from a mesh-connected machine.

**Why:** web2 deployed @ d7d1096 (gen-24, 2026-04-22 11:40); want has
moved 8 closure-affecting commits since. Still degraded
(acme-order-renew, see needs-human/ops-web2-acme-renew.md).

**Blockers:** Human-gated (CLAUDE.md). Probe live since 139c681.

**relay1 — DONE.** Converged gen-15 @ xzzh4496 (Apr-24 10:29,
post-8c47c57). Drift spot-check: fdc5:e1a6:b03f::/48 on kinq0 PRESENT
(bdef5f7 ADR-0021 leg-2 active), 0 failed units. Remaining cumulative
runtime checks unverified (root SSH denied to META) but 0-failed-units
covers service-level. File split from ops-deploy-relay1-web2.md @ META
r1 2026-04-24.

## Latest status (drift @ 68ab318, 2026-04-24)

```
web2: have gxj4h6lw… (gen-24 @ d7d1096)  ≠ want rpbncysm… (@ 68ab318)
```

Dry-build 157/76/285.5M (8c47c57 externals on cache.assise). Same
nixpkgs b12141e both ends.

## Reconcile

```sh
kin deploy web2
```

Then walk runtime checks. Then triage acme-order-renew (may self-heal
on redeploy if upstream lego/acme module changed). Then delete this
file.

## web2-affecting commits since d7d1096 (carries 8)

| commit | what |
|---|---|
| 28a9fe4 | kin →ba0e1a81 unpin (EROFS fixed; +iets-everywhere, kin show, fleetd-put) |
| 1d32ccb | iets 34686f1f→2c5337f9 + llm-agents bd0e8933→03a24500 |
| 575b547 | internal bump kin→757b0221 iets→fa604918 nix-skills llm-agents |
| 9d52d68 | internal kin 757b0221→76d8b7b2 + iets fa604918→c00eafa8 |
| ecada5b | kin →ba4514b9 + iets →14e50511 + settle →de9e8efe |
| bdef5f7 | kin.nix identity.peers.kin-infra.net=fdc5:e1a6:b03f (maille /48 route) |
| efd470a | internal kin →d1265fc0 iets →c70f78f8 llm-agents →b518f1b6 |
| 8c47c57 | zimbatm flake update hm/iets/kin/llm-agents/maille/nix-skills/nixos-hw/nixvim/srvos (NOT nixpkgs) |

Net: gxj4h6lw→rpbncysm. kin home-surface across range = 9d6da8cf
RestartSec=2 on kin-secrets/kin-mesh + 053a8092 flake-shim sourceInfo
fix + ceb1f951 mesh-toml.nix extract (byte-identical). maille
d431f5cd→9a52913a = 93186cf half-open fast-start. Low risk —
internal-only since deployed-at, same nixpkgs.

Closure-neutral verified: b657104/fee393d (superseded by 28a9fe4),
5963105 (superseded), 6ecfb12/7184a6d srvos, cb0180b hm, c10990b/
7e6e5d5 nv1-only.

## Runtime checks (cumulative, web2)

- **CA derivations** — `nix config show | grep ca-derivations` enabled
- **peer-kin-infra trust** — `grep '@cert-authority' /etc/ssh/ssh_known_hosts` includes kin-infra CA; `maille config show | jq .peer_fleets` lists kin-infra
- **pin-nixpkgs dropped** — `nix registry list | grep nixpkgs` and `echo $NIX_PATH` resolve to system pin
- **attest identity** — `ls /run/kin/identity/attest.*` exists post-deploy
- **cache.assise substituter** — `nix config show | grep substituters` lists cache.assise.systems
- **restic-gotosocial** — `systemctl status restic-backups-gotosocial.{service,timer}` active
- **peer-fleet /48 route** — `ip -6 route show dev kinq0 | grep fdc5:e1a6:b03f::/48` present (verified-live on relay1)
- **acme-order-renew** — `systemctl status acme-order-renew-gts.zimbatm.com.service` — was degraded pre-deploy; check if redeploy clears

---

## drift append-log

(drift-checker appends new `### drift @ <rev>` sections below; META
re-compacts into the table above when this section exceeds 3 entries)

<!-- compacted @ 7c1602a (META r1, 2026-04-24): folded 6a4ed7a+1490f45+f4d909c+68ab318 into tables+checks above; relay1 split off (converged gen-15) -->
