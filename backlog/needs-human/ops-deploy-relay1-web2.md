# relay1 + web2: redeploy (drifted again post-d2ad1d1)

**What:** `kin deploy relay1 web2` from a mesh-connected machine.

**Why:** Both were have==want @ d2ad1d1 (relay1 `dpxnfwvk`, web2
`zv4kapl1`). Bumper landed f2c38c8 (kin/iets/nix-skills/llm-agents
internal bump) and 821b625 (srvos bump) since; both closures moved.

`kin status --json` @ 589a2f5:
```
relay1: have dpxnfwvk… ≠ want cfp7bc9j…  (health=running, secrets=active, failed=-, uptime 6d1h)
web2:   have zv4kapl1… ≠ want d5x5xl4j…  (health=running, secrets=active, failed=-, uptime 6d4h)
```

**Closure attribution (bisect relay1 @ 7e93604 vs f2c38c8):**
- 1201785 gsnap, d00a686 IFD-ban, 6bf3705 kin.nix admin-drop —
  relay1-closure-neutral (relay1 still `dpxnfwvk` @ 7e93604)
- f2c38c8 kin/iets bump — relay1 `dpxnfwvk`→`cfp7bc9j` (the current
  want; sole relay1-affecting commit)
- 821b625 srvos bump — relay1-closure-neutral (`cfp7bc9j` unchanged);
  web2 not bisected, may contribute there alongside f2c38c8

**Reconcile:** just deploy. No declared-side gap (deployed has nothing
declared lacks — `have` matches the d2ad1d1 want exactly). web2
restic-backups-gotosocial timer runtime check from d2ad1d1 still
applies if not yet walked.

**Blockers:** Human-gated (CLAUDE.md). Low-risk: kin/iets lib bump +
srvos minor; same nixpkgs 4c1018d throughout.
---

## drift @ 0251202 (2026-04-14): web2 want moved, relay1 unchanged

`kin status --json` @ 0251202:
```
relay1: have dpxnfwvk… ≠ want cfp7bc9j…  (UNCHANGED since 589a2f5; health=running, uptime 6d4h)
web2:   have zv4kapl1… ≠ want l6wwl43y…  (was d5x5xl4j @ 589a2f5; health=running, uptime 6d7h)
```

**web2 bisect 589a2f5..0251202** (toplevel outPath):
```
589a2f5..e170608  d5x5xl4j  (sel-act/hist-sem/gen-regen all web2-neutral)
082a29f..b016581  5y6261mv  ← 082a29f iets 396eb90→ef58583
65e3984..0251202  l6wwl43y  ← 65e3984 kin 0feb503→1306b57 + iets/llm-agents
```
relay1 stayed `cfp7bc9j` across both bumps — relay1's minimal closure
doesn't reach the iets/kin paths that moved. (65e3984 commit msg claims
"host drvPaths unchanged" — false for web2.)

**Reconcile unchanged:** just deploy. Same nixpkgs 4c1018d throughout;
internal lib bumps only. web2 restic-backups-gotosocial timer runtime
check from d2ad1d1 still applies if not yet walked.
---

## drift @ 53bed8f (2026-04-14): web2 deployed ✓, relay1 still pending

`kin status --json` live:
```
relay1: have dpxnfwvk… ≠ want cfp7bc9j…  (UNCHANGED both sides since 589a2f5; uptime 6d8h)
web2:   have l6wwl43y… == want l6wwl43y…  ✓ (deployed since e4c1d3d; uptime 6d11h)
```

**web2 done** — have moved `zv4kapl1`→`l6wwl43y` matching want;
deployed sometime in the ~4h since e4c1d3d. restic-backups-gotosocial
timer runtime check from d2ad1d1 still applies if not yet walked;
otherwise web2 is fully reconciled.

**relay1 unchanged** — still the single f2c38c8 kin/iets bump as sole
delta. 396d2de (live-caption, nv1-only home module) is
relay1-closure-neutral (want stayed `cfp7bc9j`, verified). relay1 is
now the only stale host of the pair; uptime 6d8h, no failed units.

**Reconcile:** `kin deploy relay1`. After that lands and the web2
restic check is walked, delete this file.
---

## drift @ e969d2c (2026-04-15): both want moved; have UNPROBEABLE this round

`kin status --json` from grind worker: relay1+web2 `have=""`
health=unreachable. Root cause: `~/.ssh/kin-bir7vyhu_ed25519` (home
fleet identity) is gone from this worker — see ops-deploy-nv1.md same
section. **have carried forward** from 53bed8f: relay1=`dpxnfwvk`,
web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want m1shwflm…  (was cfp7bc9j @ 53bed8f)
web2:   have l6wwl43y… (carried) ≠ want d3w23bih…  (was l6wwl43y == have @ 53bed8f)
```

**relay1 bisect** cfp7bc9j→m1shwflm: single commit.
- bfcd408 — relay1/configuration.nix: add cache.assise.systems
  substituter+key (relay1 doesn't import common.nix, so 35c8232 missed
  it). 26cb8a9 internal bump + a603e7c hm bump + all wake-listen/
  transcribe-npu commits relay1-neutral (verified).

**web2 bisect** l6wwl43y→d3w23bih: two commits.
- 35c8232 — common.nix: cache.assise.systems substituter+key
  (l6wwl43y→44z9l6xb)
- 26cb8a9 — internal bump kin/iets/nix-skills/llm-agents
  (44z9l6xb→d3w23bih). a603e7c hm bump + bfcd408 relay1-only + all
  wake-listen/transcribe-npu/live-caption commits web2-neutral
  (verified).

**web2 stale again** — was have==want @ 53bed8f, now want moved past
it. Both deltas are low-risk (extra binary cache + internal lib bump,
same nixpkgs 4c1018d throughout).

**Reconcile:** `kin deploy relay1 web2`. relay1 now carries 2 deltas
(f2c38c8 from 589a2f5 + bfcd408); web2 carries 2 (35c8232 + 26cb8a9).
No declared-side gap suspected — but have is unprobed this round, so
can't confirm no out-of-band changes since 53bed8f.
