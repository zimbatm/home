# relay1 + web2: redeploy (drifted again post-d2ad1d1)

**What:** `kin deploy relay1 web2` from a mesh-connected machine.

**Why:** Both were have==want @ d2ad1d1 (relay1 `dpxnfwvk`, web2
`zv4kapl1`); web2 re-converged @ 53bed8f (`l6wwl43y`). Want has moved
many times since on both.

**Blockers:** Human-gated (CLAUDE.md). Worker probe RESTORED @ 139c681
self-heal (kin-bir7vyhu mtime Apr-23-10:43) after 10 blind rounds.

## Latest status (drift @ f4d909c, 2026-04-23)

```
relay1: have 9l7p6ryp… (PROBED — kin status live)  ≠ want 3w3kxh74…
web2:   have gxj4h6lw… (PROBED — kin status live)  ≠ want lm3szkqw…
```

**Ground-truth replaces 10-round carry-forward:** both deployed @
d7d1096 (2026-04-22, ~28h ago — verified relay1=9l7p6ryp web2=gxj4h6lw
both eval-match d7d1096). Prior journal's "carried have dpxnfwvk/
l6wwl43y from 53bed8f" was stale by 12 commits — Jonas deployed both
servers while worker was blind. **Carries drop: relay1 14→3, web2
20→5.** Same nixpkgs b12141e deployed and declared (0 nixpkgs minors
pending). Dry-build: relay1 73/9 (140.7 MiB), web2 160/76 (285.5 MiB)
— UNCHANGED since 6a4ed7a (kin@757b0221 + iets@fa604918 already on
cache.assise).

**web2 degraded:** acme-order-renew-gts.zimbatm.com.service failed —
see backlog/ops-web2-acme-renew.md (filed 6a4ed7a, surfaced by restored
probe).

## Reconcile

```sh
kin deploy relay1 web2
```

Then walk runtime checks. Then delete this file.

## relay1-affecting commits since d7d1096 (deployed-at; reset 2026-04-23 ground-truth)

| commit | what | scope |
|---|---|---|
| b657104 | kin 3118eb1d→7d4c7bfd netrc bridge | both |
| fee393d | kin →45cd3818 pin-back (drop EROFS regression) | both |
| 28a9fe4 | kin →ba0e1a81 unpin (EROFS fixed; +iets-everywhere, kin show, fleetd-put) | both |
| 575b547 | internal bump kin→757b0221 iets→fa604918 nix-skills llm-agents | both |

Net relay1: 9l7p6ryp→3w3kxh74 (kin 4-hop; ba0e1a81..757b0221
home-surface = 9d6da8cf RestartSec=2 on kin-secrets/kin-mesh units).

## web2-only additional commits since d7d1096

| commit | what |
|---|---|
| 5963105 | zimbatm flake update (hm/iets/kin/nixvim/llm-agents/nix-skills) — relay1-neutral |
| 1d32ccb | iets 34686f1f→2c5337f9 + llm-agents bd0e8933→03a24500 — relay1-neutral |

(Totals: relay1 carries 4, web2 carries 4+2 = 6. Pre-d7d1096 stack
deployed 2026-04-22 — see git log for the d2ad1d1..d7d1096 history.)

Closure-neutral both since d7d1096 (verified): 6ecfb12 srvos, 7184a6d
srvos, c10990b ask-local-perms (nv1-only), 7e6e5d5 tuicr (nv1-only).

## Runtime checks (cumulative)

After deploy, on each host:

- **CA derivations** — `nix config show | grep ca-derivations` enabled
- **peer-kin-infra trust** — `grep '@cert-authority' /etc/ssh/ssh_known_hosts` includes kin-infra CA; `maille config show | jq .peer_fleets` lists kin-infra
- **pin-nixpkgs dropped** — `nix registry list | grep nixpkgs` and `echo $NIX_PATH` resolve to system pin (kin upstream now provides; regression = `nix-shell -p` pulls channel)
- **attest identity** — `ls /run/kin/identity/attest.*` exists post-deploy
- **cache.assise substituter** — `nix config show | grep substituters` lists cache.assise.systems
- **restic-gotosocial** (web2 only) — `systemctl status restic-backups-gotosocial.{service,timer}` active
- **peer-fleet /48 route** — `ip -6 route show dev kinq0 | grep fdc5:e1a6:b03f::/48` present (identity.peers.kin-infra.net landed; this redeploy activates ADR-0021 cedar curl-pair leg-2 datapath — kin-infra side already reciprocal)

Risk profile: kin 4-hop (3118eb1d→7d4c7bfd→45cd3818→ba0e1a81→757b0221)
+ iets 3-hop, same nixpkgs b12141e both ends. Only service-surface
change: kin 9d6da8cf adds RestartSec=2 to kin-secrets/kin-mesh units
(tight-loop damper). Low — internal-only since deployed-at.

---

## drift append-log

(drift-checker appends new `### drift @ <rev>` sections below; META
re-compacts into the table above when this section exceeds 3 entries)

<!-- compacted @ ccb5047 (META r1, 2026-04-23): folded 0251202+53bed8f+e969d2c+7f572ea+0404fbb+b9b1d94+ead5fd4+605cd1b+5858216+ec62a90+bump-nixpkgs+da0b27b+0beecde into tables+checks above -->

### drift @ 6a4ed7a (2026-04-23)

**PROBEABLE — first live `kin status` after 10 blind rounds.** Identity
kin-bir7vyhu restored (mtime Apr-23-10:43, via 139c681 self-heal `kin
login claude --key kin-infra`).

Ground-truth HAVE: relay1=9l7p6ryp web2=gxj4h6lw — both eval-match
d7d1096 (deployed 2026-04-22 while worker blind). Prior carry-forward
(dpxnfwvk/l6wwl43y from 53bed8f) stale by 12 commits; tables above
reset to d7d1096 baseline. Carries: relay1 14→3, web2 20→5.

Bisect 5f9422b8..6a4ed7a (3 .nix-touching): 28a9fe4 kin→ba0e1a81 ALL3
(nv1 dvgqw9cg→b5cn8gij relay1 bg6drqcb→xhcdw782 web2 375jz32a→fzzrmr1l;
result == 5963105-era, kin a66409db..ba0e1a81 home-surface-neutral);
1d32ccb iets+llm-agents nv1+web2 (b5cn8gij→av9v7mmc fzzrmr1l→z78zi5y7,
relay1-neutral; ⚠ bumper msg hashes l05iw1sz/jjd1z1z3/qzc3adw1/3ybvppf2
don't match flake-eval — likely iets-eval path divergence); 7184a6d
srvos closure-neutral 3/3 verified.

web2 health=degraded: acme-order-renew-gts.zimbatm.com.service failed
(uptime 15d2h). Filed backlog/ops-web2-acme-renew.md @ 6a4ed7a. relay1
health=running, no failed units.

### drift @ 1490f45 (2026-04-23)

Ground-truth re-probed (kin status --json): relay1=9l7p6ryp
web2=gxj4h6lw — UNCHANGED since 6a4ed7a (still @ d7d1096, no human
deploy this session). web2 still degraded acme-order-renew (uptime
15d3h, needs-human/ops-web2-acme-renew.md). relay1 running clean.

Bisect 8f7f2db..1490f45 (2 flake.lock-touching): 575b547 internal bump
kin ba0e1a81→757b0221 + iets 2c5337f9→fa604918 + nix-skills +
llm-agents → ALL3 (relay1 xhcdw782→3w3kxh74, web2 z78zi5y7→a6lmyy7x);
cb0180b hm 936d579f→667b3c47 → relay1+web2-NEUTRAL verified (3w3kxh74/
a6lmyy7x unchanged across cb0180b). Carries: relay1 3→4, web2 5→6.

kin ba0e1a81..757b0221 home-surface scan: 9d6da8cf adds RestartSec=2 to
kin-secrets/kin-mesh renderedUnits (image.links→build-time, decrypt
drops /etc ln-sf — EROFS-safe but image-path only); 6d721e7c ci-dispatch
+ e7a6a357 ci.pollInterval (home doesn't enable services.ci); rest =
docs/backlog/coverage/meta. Net surface: RestartSec=2 only.

Dry-build: relay1 73/9/140.7M web2 160/76/285.5M — IDENTICAL to 6a4ed7a
(kin@757b0221 + iets@fa604918 already on cache.assise; closure-hash
moved but build-set unchanged). Note: meta(r3) reported want=09jyamnj/
m61f67w1 — those are iets-via-default.nix outPaths (19700101.dirty
versionSuffix per 4e214f9 factor-2); kin-status flake-eval want=
3w3kxh74/a6lmyy7x is deploy-authoritative. Divergence expected, kin
cross-file 7ecc09f0 bug-flake-shim-sourceinfo open upstream.

### drift @ f4d909c (2026-04-23)

Ground-truth re-probed (kin status --json): relay1=9l7p6ryp
web2=gxj4h6lw — UNCHANGED (still @ d7d1096, no human deploy this
session). web2 still degraded acme-order-renew-gts.zimbatm.com (uptime
15d11h, needs-human/ops-web2-acme-renew.md). relay1 running clean.

Bisect c65afb4..f4d909c (2 flake.lock-touching): 9d52d68 internal kin
757b0221→76d8b7b2 + iets fa604918→c00eafa8 → web2 a6lmyy7x→ixvc24yz,
**relay1 NEUTRAL 3w3kxh74**; ecada5b kin 76d8b7b2→ba4514b9 + iets
c00eafa8→14e50511 + settle 40c11486→de9e8efe → web2 ixvc24yz→lm3szkqw,
**relay1 NEUTRAL 3w3kxh74**. relay1 want UNCHANGED 2 rounds — closure
excludes kin-CLI/iets/settle (mesh-relay minimal; only renderedUnits).
Carries: relay1 4→5, web2 6→7.

kin 757b0221..ba4514b9 home-surface = 053a8092 flake-shim epochToDate/
shortRev (CLOSES iets-vs-flake outPath divergence — kin#7ecc09f0
resolved, NB above now stale) + 76d8b7b2 deploy batched-build CLI-only;
a20955cf transitive iets/settle re-pin; rest meta/architect analysis.
iets fa604918..14e50511 = git-credential helper auth (d8816ec) + ietsd
FOD credential injection (14e5051) — daemon/fetch-layer, in web2
closure via kin→iets dep. settle 40c11486..de9e8efe = meta/analysis
only, narHash content-identical per kin a20955cf.

Dry-build: relay1 73/9/140.7M web2 160/76/285.5M — IDENTICAL to
1490f45 (bumped iets/kin on cache.assise; build-set unchanged). f4d909c
adopt-peer-kin-infra-net.md couples here: same maille redeploy picks up
kinq0 /48 route once implemented. No new runtime checks (packages/
pty-puppet+shell-squeeze are agentshell-only, host-closure-neutral).

### drift @ 68ab318 (2026-04-24)

**relay1 CONVERGED — HUMAN DEPLOYED.** gen 14→15 (9l7p6ryp→xzzh4496)
@ Apr-24 10:29 UTC, post-8c47c57 flake-update. have==want xzzh4496.
Runtime spot-check: `ip -6 route show dev kinq0` → fdc5:e1a6:b03f::/48
PRESENT (bdef5f7 peer-route ACTIVE, ADR-0021 cedar leg-2 datapath
live); 0 failed units. **Carries: relay1 5→0.** META: drop relay1 from
this file's title/reconcile/tables; remaining runtime checks need
verification on relay1 then this becomes web2-only.

web2 re-probed: have gxj4h6lw (gen-24 Apr-22 11:40, @ d7d1096) ≠ want
rpbncysm. UNCHANGED — Jonas deployed relay1-only this round. Still
degraded acme-order-renew-gts.zimbatm.com (uptime 16d9h, needs-human/
ops-web2-acme-renew). **Carries: web2 7→8.**

Bisect 120e2d1..68ab318 (3 closure-touching): bdef5f7 kin.nix
identity.peers.kin-infra.net → ALL3 (relay1 3w3kxh74→v261gni7, web2
lm3szkqw→9bz2n0vn); efd470a internal kin d1265fc0/iets/llm-agents →
web2 9bz2n0vn→9ajlnmii, **relay1-NEUTRAL v261gni7** (bumper msg
misattributed relay1 move to maille-caps — actually bdef5f7); 8c47c57
zimbatm flake update hm/iets/kin/llm-agents/maille/nix-skills/nixos-hw/
nixvim/srvos (NOT nixpkgs) → ALL3 (relay1 v261gni7→xzzh4496, web2
9ajlnmii→rpbncysm). kin d1265fc0..68623880 home-surface = ceb1f951
mesh-toml.nix extract (mesh.nix 383→260L, byte-identical toml) +
05819b51 -C chaining CLI-only + 06572ab7 transitive. maille d431f5cd..
9a52913a = 93186cf half-open fast-start asym-supersede ~10s bound
(mesh daemon, deploy-surface).

Dry-build: relay1 72/9/140.7M web2 157/76/285.5M (-1/-3 built vs
f4d909c, fetch identical — 8c47c57 inputs landing on cache.assise).
web2 d7d1096..68ab318 net = same nixpkgs b12141e + bdef5f7 peer-route +
4× internal-hop + hm/maille/nixos-hw/nixvim/srvos externals. New
runtime check (web2): peer-fleet /48 route (already in list line 76,
verified-live on relay1).
