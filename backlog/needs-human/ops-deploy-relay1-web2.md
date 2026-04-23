# relay1 + web2: redeploy (drifted again post-d2ad1d1)

**What:** `kin deploy relay1 web2` from a mesh-connected machine.

**Why:** Both were have==want @ d2ad1d1 (relay1 `dpxnfwvk`, web2
`zv4kapl1`); web2 re-converged @ 53bed8f (`l6wwl43y`). Want has moved
many times since on both.

**Blockers:** Human-gated (CLAUDE.md). From this grind worker `kin
status` is currently UNPROBEABLE (ops-kin-login-worker.md — fleet
identity `~/.ssh/kin-bir7vyhu*` lost, blind since e969d2c).

## Latest status (drift @ 0beecde, 2026-04-23)

```
relay1: have dpxnfwvk… (carried from 53bed8f, NOT re-probed — blind 10th round) ≠ want bg6drqcb…  drv igdnpx3x…
web2:   have l6wwl43y… (carried from 53bed8f, NOT re-probed — blind 10th round) ≠ want 375jz32a…  drv szm4pz75…
```

nixpkgs b12141e (since 608e987; was 4c1018d at 53bed8f → 4bd9165 @
fa68a27 → b12141e @ 608e987). **2 nixpkgs minors in pending stack.**
Dry-build: relay1 352 drvs/264 fetch (222.4 MiB), web2 424 drvs/376
fetch (437.3 MiB) — JUMP from 75/9 + 159/76 @ da0b27b (cache.assise
hasn't built kin@45cd3818 pinned-back rev). **relay1 carries 14
deltas, web2 carries 20.** have unprobed 10th round — can't confirm no
out-of-band changes since 53bed8f.

**Post-journal:** 28a9fe4 (this META round) unpins kin 45cd3818→ba0e1a81
(EROFS fixed) — moves both again; next drift bisects.

## Reconcile

```sh
kin deploy relay1 web2
```

Then walk runtime checks. Then delete this file.

## relay1-affecting commits since d2ad1d1 (cumulative bisect log, compacted 2026-04-23)

| commit | what | scope |
|---|---|---|
| f2c38c8 | kin/iets/nix-skills/llm-agents bump | both |
| bfcd408 | relay1/configuration.nix: +cache.assise.systems substituter | relay1 |
| e4d45cd | kin/iets/nix-skills/llm-agents bump (incl maille→b849d73) | both |
| b0b4acd | common.nix: +ca-derivations experimental-feature | both |
| 0319657 | kin gen — per-host certs/fps + tls-ca regen | both |
| 11edb95 | maille bump b849d73→156486c peer_fleets cap | both |
| fa68a27 | **nixpkgs 4c1018d→4bd9165** | both |
| 4a60b42 | internal bump kin→e736801 + gen re-sign | both |
| cadfc52 | kin.nix identity.peers.kin-infra + mesh.peerFleets | both |
| 69f7bb4 | META keep-6 of 5858216 (hm/iets/kin/llm-agents/maille/nixvim) | both |
| 608e987 | **nixpkgs 4bd9165→b12141e** | both |
| 206cf2d | internal bump kin→3118eb1d + gen attest + drop pin-nixpkgs | both |
| b657104 | kin 3118eb1d→7d4c7bfd netrc bridge | both |
| fee393d | kin →45cd3818 pin-back (drop EROFS regression) | both |

## web2-only additional commits (cumulative)

| commit | what |
|---|---|
| 35c8232 | common.nix: cache.assise.systems substituter |
| 26cb8a9 | internal bump kin/iets/nix-skills/llm-agents |
| 6673c0c | internal bump kin/iets/nix-skills |
| 483fadb | internal bump kin→df0a4b2 + iets/llm-agents |
| c7939f0 | iets bump 714989b→d6739fad |
| b7ea207 | iets bump →68367fb0 + nixfmt→iets-fmt swap |
| d7d1096 | iets bump e4098058→e1cd6980 |
| 5963105 | zimbatm flake update (hm/iets/kin/nixvim/llm-agents/nix-skills) — relay1-neutral |

(Totals: relay1 carries 14, web2 carries 14+6 web2-only = 20. 65e3984 +
082a29f web2-affecting pre-53bed8f, already deployed.)

Closure-neutral both (verified): 821b625 srvos, 7aa2a6e srvos, 6ecfb12
srvos, 3a809a9 nixvim, 3dd9fb7 nixos-hardware, f1e5fca nix-index-db,
e98e1c5 vfio-vendor, 3092054 vfio-original, 69158d6 fleetManifest,
b911f6e kin gen, ed7d465 crops-residue, 6759648 model-autofetch, all
packages/+modules/home/desktop changes (nv1-only).

## Runtime checks (cumulative)

After deploy, on each host:

- **CA derivations** — `nix config show | grep ca-derivations` enabled
- **peer-kin-infra trust** — `grep '@cert-authority' /etc/ssh/ssh_known_hosts` includes kin-infra CA; `maille config show | jq .peer_fleets` lists kin-infra
- **pin-nixpkgs dropped** — `nix registry list | grep nixpkgs` and `echo $NIX_PATH` resolve to system pin (kin upstream now provides; regression = `nix-shell -p` pulls channel)
- **attest identity** — `ls /run/kin/identity/attest.*` exists post-deploy
- **cache.assise substituter** — `nix config show | grep substituters` lists cache.assise.systems
- **restic-gotosocial** (web2 only) — `systemctl status restic-backups-gotosocial.{service,timer}` active

Risk profile: 2× nixpkgs minor + internal/mesh bumps + identity regen +
kin 4-hop churn (3118eb1d→7d4c7bfd→a66409db→45cd3818→ba0e1a81). No
service-surface changes either host.

---

## drift append-log

(drift-checker appends new `### drift @ <rev>` sections below; META
re-compacts into the table above when this section exceeds 3 entries)

<!-- compacted @ ccb5047 (META r1, 2026-04-23): folded 0251202+53bed8f+e969d2c+7f572ea+0404fbb+b9b1d94+ead5fd4+605cd1b+5858216+ec62a90+bump-nixpkgs+da0b27b+0beecde into tables+checks above -->
