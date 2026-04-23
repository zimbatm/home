# relay1 + web2: redeploy (drifted again post-d2ad1d1)

**What:** `kin deploy relay1 web2` from a mesh-connected machine.

**Why:** Both were have==want @ d2ad1d1 (relay1 `dpxnfwvk`, web2
`zv4kapl1`); web2 re-converged @ 53bed8f (`l6wwl43y`). Want has moved
many times since on both.

**Blockers:** Human-gated (CLAUDE.md). Worker probe RESTORED @ 139c681
self-heal (kin-bir7vyhu mtime Apr-23-10:43) after 10 blind rounds.

## Latest status (drift @ 6a4ed7a, 2026-04-23)

```
relay1: have 9l7p6ryp… (PROBED — kin status live)  ≠ want xhcdw782…
web2:   have gxj4h6lw… (PROBED — kin status live)  ≠ want z78zi5y7…
```

**Ground-truth replaces 10-round carry-forward:** both deployed @
d7d1096 (2026-04-22, ~28h ago — verified relay1=9l7p6ryp web2=gxj4h6lw
both eval-match d7d1096). Prior journal's "carried have dpxnfwvk/
l6wwl43y from 53bed8f" was stale by 12 commits — Jonas deployed both
servers while worker was blind. **Carries drop: relay1 14→3, web2
20→5.** Same nixpkgs b12141e deployed and declared (0 nixpkgs minors
pending). Dry-build: relay1 73/9 (140.7 MiB), web2 160/76 (285.5 MiB)
— DOWN from 352/264 + 424/376 (kin@ba0e1a81 in cache.assise).

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

Net relay1: 9l7p6ryp→xhcdw782 (kin 3-hop nets to 7d4c7bfd-era surface;
a66409db..ba0e1a81 home-surface-neutral on relay1).

## web2-only additional commits since d7d1096

| commit | what |
|---|---|
| 5963105 | zimbatm flake update (hm/iets/kin/nixvim/llm-agents/nix-skills) — relay1-neutral |
| 1d32ccb | iets 34686f1f→2c5337f9 + llm-agents bd0e8933→03a24500 — relay1-neutral |

(Totals: relay1 carries 3, web2 carries 3+2 = 5. Pre-d7d1096 stack
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

Risk profile: kin 3-hop only (3118eb1d→7d4c7bfd→45cd3818→ba0e1a81),
same nixpkgs b12141e both ends. No service-surface changes either host.
Low — internal-only since deployed-at.

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
