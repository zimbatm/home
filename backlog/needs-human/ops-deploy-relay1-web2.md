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
---

## drift @ 7f572ea (2026-04-15): both want moved again; have STILL UNPROBEABLE

`kin status --json`: relay1+web2 `have=""` health=unreachable —
`~/.ssh/kin-bir7vyhu*` still absent (ops-kin-login-worker.md
unactioned). **have carried forward** from 53bed8f: relay1=`dpxnfwvk`,
web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want 6dxixaw6…  (was m1shwflm @ e969d2c)
web2:   have l6wwl43y… (carried) ≠ want abqnqrp0…  (was d3w23bih @ e969d2c)
```

**Bisect e301f49..7f572ea** — single closure-affecting commit for both:
- e4d45cd — internal bump kin/iets/nix-skills/llm-agents (6 lock nodes:
  kin 31acf3f→23094e5, iets cf11339→a4abd7b, nix-skills 1c13ad4→4b604a9,
  llm-agents f721224→78aa310, transitive maille 6ece63e→b849d73 +
  blueprint 06ee719→56131e8). relay1 m1shwflm→6dxixaw6, web2
  d3w23bih→abqnqrp0. **relay1 closure moved on an internal bump** —
  first time since f2c38c8 (26cb8a9+prior were relay1-neutral); maille
  is kin's mesh transitive and the likely relay1-reaching path.

02441a9 (live-caption-log, nv1-only) + 8172dfe (checks.no-ifd,
flake.nix-checks-only) both relay1+web2-neutral, verified.

**Reconcile:** `kin deploy relay1 web2`. relay1 now carries 3 deltas
(f2c38c8 + bfcd408 + e4d45cd); web2 carries 3 (35c8232 + 26cb8a9 +
e4d45cd). Same nixpkgs 4c1018d throughout; all internal lib/mesh bumps
+ substituter add — low-risk. have unprobed 2nd round running, so
can't confirm no out-of-band changes since 53bed8f.
---

## drift @ 0404fbb (2026-04-15): relay1 want UNCHANGED; web2 want moved; have UNPROBEABLE 3rd round

`kin status --json`: relay1+web2 `have=""` health=unreachable —
`~/.ssh/kin-bir7vyhu*` still absent (ops-kin-login-worker.md unactioned
3rd round). **have carried forward** from 53bed8f: relay1=`dpxnfwvk`,
web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want 6dxixaw6…  (UNCHANGED since 7f572ea)
web2:   have l6wwl43y… (carried) ≠ want 731rixqs…  (was abqnqrp0 @ 7f572ea)
```

**Bisect b411c2d..0404fbb** — 3 .nix-touching commits:
- 85d68cd ask-local --fast + 2194b90 sem-grep -r — both packages/ nv1-only;
  relay1+web2-neutral (web2 verified abqnqrp0 @ 2194b90)
- 6673c0c internal bump kin 23094e5→2785e63, iets a4abd7b→2a0cbb9,
  nix-skills 4b604a9→76e053a: relay1-neutral (6dxixaw6 unchanged), web2
  abqnqrp0→731rixqs

**relay1 zero new delta** this round — still carries the same 3
(f2c38c8 + bfcd408 + e4d45cd). 6673c0c is the 2nd consecutive internal
bump that's relay1-neutral (after e4d45cd was the exception via maille).

**web2 +1 delta** — now carries 4 (35c8232 + 26cb8a9 + e4d45cd +
6673c0c), all internal lib bumps + substituter add.

**Reconcile:** `kin deploy relay1 web2`. Same nixpkgs 4c1018d
throughout; low-risk. have unprobed 3rd round running — can't confirm
no out-of-band changes since 53bed8f.
---

## drift @ b9b1d94 (2026-04-15): both want UNCHANGED; have UNPROBEABLE 4th round

`kin status --json`: empty — `~/.ssh/kin-bir7vyhu*` still absent
(ops-kin-login-worker.md unactioned 4th round). **have carried forward**
from 53bed8f: relay1=`dpxnfwvk`, web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want 6dxixaw6…  (UNCHANGED since 7f572ea)
web2:   have l6wwl43y… (carried) ≠ want 731rixqs…  (UNCHANGED since 0404fbb)
```

**Bisect 3a46943..b9b1d94** — 2 .nix-touching merges (07b2b2f ask-local
--agent, 99e9212 sem-grep log + hm module), both packages/ +
modules/home/desktop nv1-only; relay1+web2-neutral verified at both
points (6dxixaw6/731rixqs throughout). Zero new delta either host.

**relay1 still carries 3** (f2c38c8 + bfcd408 + e4d45cd); **web2 still
carries 4** (35c8232 + 26cb8a9 + e4d45cd + 6673c0c). Reconcile
unchanged: `kin deploy relay1 web2`. Same nixpkgs 4c1018d throughout.
have unprobed 4th round running — can't confirm no out-of-band changes
since 53bed8f.

---

## drift @ ead5fd4 (2026-04-17): both want MOVED (b0b4acd+0319657 all-host); have UNPROBEABLE 5th round

`kin status`: both unreachable — `~/.ssh/kin-bir7vyhu*` still absent
(only kin-dwqfzbq5+kin-infra mtime Apr-15-12:17 unchanged;
ops-kin-login-worker.md unactioned 5th round). **have carried forward**
from 53bed8f: relay1=`dpxnfwvk`, web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want ljb7slc2…  (MOVED from 6dxixaw6)
web2:   have l6wwl43y… (carried) ≠ want ai4xln7x…  (MOVED from 731rixqs)
```

**Bisect feac33c..ead5fd4** — 2 all-host commits broke the
3-consecutive-unchanged streak:
- b0b4acd modules/nixos/common.nix `nix.settings.experimental-features`
  +ca-derivations (ALL 3 hosts)
- 0319657 `kin gen` — gen/identity per-host certs + tls-ca + mesh fps
  regenerated (ALL 3 hosts)
- 497ddec flake.lock iets bump: relay1/web2-neutral (inputs.iets only
  ref'd in machines/nv1/; grep'd modules/ kin.nix → 0 hits)
- remaining delta nv1-only (ask-local, deepfilter) or non-closure
  (.envrc, treefmtFor devshell, backlog, markers)

**relay1 now carries 5** (f2c38c8 + bfcd408 + e4d45cd + b0b4acd +
0319657); **web2 now carries 6** (35c8232 + 26cb8a9 + e4d45cd + 6673c0c
+ b0b4acd + 0319657). Reconcile unchanged: `kin deploy relay1 web2`.
Same nixpkgs 4c1018d throughout. **+1 runtime check both hosts:** `nix
config show | grep ca-derivations` shows enabled. have unprobed 5th
round running — can't confirm no out-of-band changes since 53bed8f.
---

## drift @ 605cd1b (2026-04-17): both want MOVED (4 commits incl nixpkgs); have UNPROBEABLE 6th round

`kin status --json`: empty — `~/.ssh/kin-bir7vyhu*` still absent (only
dwqfzbq5+infra mtime Apr-15-12:17 unchanged; ops-kin-login-worker.md
unactioned 6th round). **have carried forward** from 53bed8f:
relay1=`dpxnfwvk`, web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want 4v9sfxzk…  (MOVED from ljb7slc2)
web2:   have l6wwl43y… (carried) ≠ want sasxqy66…  (MOVED from ai4xln7x)
```

**⚠ nixpkgs moved** — was 4c1018d throughout the whole pending stack,
now 4bd9165 (fa68a27). Risk profile bumps from "internal lib only" to
"full nixpkgs minor".

**Bisect ead5fd4..605cd1b** — 4 commits move both hosts identically:
- 11edb95 maille b849d73→156486c peer_fleets cap (relay1 ljb7slc2→
  cc5gr4ll, web2 ai4xln7x→02rvlq7n; mesh transitive reaches both, 2nd
  time after e4d45cd)
- fa68a27 **nixpkgs 4c1018d→4bd9165** (relay1 →zrzdp9sh, web2 →jvwfslid)
- 4a60b42 internal bump kin 2785e63→e736801 + iets/nix-skills/llm-agents
  + `kin gen` per-host cert re-sign (relay1 →1kaj1gbh, web2 →4q1ihclg)
- cadfc52 kin.nix `identity.peers.kin-infra` + `mesh.peerFleets` +
  gen/identity/peers/ regen (relay1 →4v9sfxzk, web2 →sasxqy66)

Closure-neutral both hosts (verified): 6759648 model-autofetch
(packages/ nv1-only, relay1=ljb7slc2 web2=ai4xln7x unchanged); 7aa2a6e
srvos bump (relay1=1kaj1gbh web2=4q1ihclg unchanged — neither imports
the bumped srvos paths). aa28b38 keys/ stage unread until cadfc52.

**relay1 now carries 9** (f2c38c8 bfcd408 e4d45cd b0b4acd 0319657 +
11edb95 fa68a27 4a60b42 cadfc52); **web2 now carries 10** (35c8232
26cb8a9 e4d45cd 6673c0c b0b4acd 0319657 + 11edb95 fa68a27 4a60b42
cadfc52). Reconcile: `kin deploy relay1 web2`. **+1 runtime check both
hosts:** peer-kin-infra trust — `grep '@cert-authority'
/etc/ssh/ssh_known_hosts` includes kin-infra CA; maille peer_fleets
lists kin-infra. have unprobed 6th round — can't confirm no out-of-band
changes since 53bed8f.
---

## drift @ 5858216 (2026-04-17): want UNEVALABLE at HEAD; relay1 unchanged / web2 +1 @ 3f3124d; have UNPROBEABLE 7th round

`kin status --json`: dies at eval (crops-demo fetch fail — see
ops-deploy-nv1.md same section + backlog/bug-eval-broken-crops-demo-
5858216.md). `~/.ssh/kin-bir7vyhu*` still absent (mtime Apr-15-12:17
unchanged 10th check; ops-kin-login-worker.md unactioned 7th round).
**have carried forward** from 53bed8f: relay1=`dpxnfwvk`,
web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want@3f3124d 4v9sfxzk…  (UNCHANGED since 605cd1b)
web2:   have l6wwl43y… (carried) ≠ want@3f3124d kzz0zmsj…  (MOVED from sasxqy66)
want@5858216: UNEVALABLE both (crops-demo fetch fails)
```

**Bisect 605cd1b..3f3124d** — 1 web2-affecting, relay1 fully neutral:
- 8bde140 fetch-model.sh + 4ec63e0 ask-local/terminal + 92d2cd8
  sem-grep sig — all packages/+modules/home nv1-only; relay1=4v9sfxzk
  web2=sasxqy66 unchanged (verified)
- 483fadb internal bump kin e736801→df0a4b2 + iets/llm-agents:
  relay1-neutral (4v9sfxzk unchanged — 3rd consecutive relay1-neutral
  internal bump after 6673c0c, 26cb8a9-precedent), web2
  sasxqy66→kzz0zmsj
- 3a809a9 nixvim bump: neutral both (verified)

**5858216 unbisectable** — bumps incl maille+kin which historically
reach both hosts; re-bisect after eval fix lands.

**relay1 still carries 9** (no change since 605cd1b); **web2 now
carries 11** (+483fadb). Reconcile unchanged: `kin deploy relay1 web2`.
have unprobed 7th round — can't confirm no out-of-band changes since
53bed8f.
---

## drift @ ec62a90 (2026-04-22): both want MOVED (5858216 re-bisect lands); have UNPROBEABLE 8th round

`kin status --json`: relay1+web2 `have=""` health=unreachable.
`~/.ssh/kin-bir7vyhu*` still absent — **dwqfzbq5+infra mtime CHANGED
Apr-15-12:17→Apr-19-10:47** (kin-infra fleet re-logged-in Apr-19, NOT
home; ops-kin-login-worker.md unactioned 8th round). **have carried
forward** from 53bed8f: relay1=`dpxnfwvk`, web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want cfz6z9c0…  (MOVED from 4v9sfxzk; UNCHANGED since 69f7bb4)
web2:   have l6wwl43y… (carried) ≠ want y3nfx6q6…  (MOVED from kzz0zmsj via 69f7bb4→mzg6jhl8→c7939f0)
```

**Eval restored** — 5858216 was unevalable last round; META r1 (69f7bb4)
surgical-reverted crops-demo, e98e1c5 dropped the input. The deferred
5858216 re-bisect resolves as 69f7bb4-keep-6.

**Bisect 3f3124d..ec62a90:**
- 69f7bb4 META keep-6 of zimbatm 5858216 (hm/iets/kin/llm-agents/maille/
  nixvim): relay1 4v9sfxzk→cfz6z9c0, web2 kzz0zmsj→mzg6jhl8 (per META
  r1; maille+kin reach both)
- e98e1c5 drop crops-demo + vendor vfio-host: relay1+web2-neutral
  (cfz6z9c0/mzg6jhl8 verified — neither imports vfio-host nor crops hm)
- 3092054 vfio-host original: relay1+web2-neutral (verified)
- 69158d6 fleetManifest inherit + b911f6e `kin gen`: neutral (verified)
- c7939f0 iets bump 714989b→d6739fad: relay1-neutral (cfz6z9c0
  unchanged), **web2 mzg6jhl8→y3nfx6q6**. Iets-only bump now
  web2-affecting (cf 497ddec was web2-neutral) — kin.inputs.iets.follows
  has been in place since 2a6ea95; this particular iets delta reaches
  web2's kin-surface where 497ddec's didn't.

**relay1 now carries 10** (f2c38c8 bfcd408 e4d45cd b0b4acd 0319657
11edb95 fa68a27 4a60b42 cadfc52 + 69f7bb4-keep-6); **web2 now carries
13** (35c8232 26cb8a9 e4d45cd 6673c0c b0b4acd 0319657 11edb95 fa68a27
4a60b42 cadfc52 483fadb + 69f7bb4-keep-6 + c7939f0). Reconcile: `kin
deploy relay1 web2`. Same nixpkgs 4bd9165 throughout this round; risk
unchanged from 605cd1b (one nixpkgs minor + internal/mesh bumps). have
unprobed 8th round — can't confirm no out-of-band changes since 53bed8f.
---

## bump-nixpkgs @ f9f1694+1 (grind, 2026-04-22): both want MOVED; b12141e

Bumper round — `have` not re-probed. Interstitial since ec62a90:
b7ea207 (iets d6739fad→68367fb0 + fmt swap) — **relay1-neutral**
(cfz6z9c0 unchanged), web2 y3nfx6q6→**62xadr6g**.

This commit — **nixpkgs 4bd9165→b12141e** (2026-04-14→04-18): relay1
cfz6z9c0→**m39a2zk3**, web2 62xadr6g→**48l2zlxg**. No package fixes
needed. Dry-build: relay1 76 drvs/9 fetch (140.7 MiB), web2 160 drvs/
76 fetch (285.5 MiB).

```
relay1: have dpxnfwvk… (carried) ≠ want m39a2zk3…  drv 838rqpjw…
web2:   have l6wwl43y… (carried) ≠ want 48l2zlxg…  drv kanb14p8…
```

**relay1 now carries 11** (+this bump); **web2 now carries 15**
(+b7ea207 +this bump). **⚠ 2nd nixpkgs in pending stack** (after
fa68a27). Reconcile: `kin deploy relay1 web2`.
---

## drift @ da0b27b (2026-04-22): both want MOVED (206cf2d); have UNPROBEABLE 9th round

`kin status --json`: relay1+web2 `unreachable`, have="" —
`~/.ssh/kin-bir7vyhu*` still absent (dwqfzbq5 mtime Apr-19-10:47
unchanged). **have carried forward**: relay1=`dpxnfwvk`, web2=`l6wwl43y`.

**Bisect 608e987..da0b27b (per META r3 deferral):**
- 3dd9fb7/164b97c nixos-hardware c775c277→72674a6b: **neutral both**
  (zero closure delta, prior verified)
- ed7d465/73d5ccf simplify crops-residue: **neutral both** (touches
  only nv1 + desktop hm + vfio-host; neither host imports)
- 206cf2d internal bump kin 26243512→3118eb1d + iets 68367fb0→e4098058
  + nix-skills + llm-agents + `kin gen` (NEW per-machine attest keys +
  operator TLS) + drop pin-nixpkgs module: relay1 m39a2zk3→**9l7p6ryp**,
  web2 48l2zlxg→**i6kjbnph** — sole mover both hosts
- f1e5fca nix-index-db: **neutral both** (verified 9l7p6ryp/i6kjbnph
  unchanged; neither imports nix-index/comma)

```
relay1: have dpxnfwvk… (carried) ≠ want 9l7p6ryp…  drv b6vcxcrn…
web2:   have l6wwl43y… (carried) ≠ want i6kjbnph…  drv 78vdw1gs…
```

Dry-build: relay1 75 drvs/9 fetch (140.7 MiB), web2 159 drvs/76 fetch
(285.5 MiB).

**relay1 now carries 12** (+206cf2d); **web2 now carries 16** (+206cf2d).
Reconcile: `kin deploy relay1 web2`. Same nixpkgs b12141e since 608e987.
Risk: internal-bump + identity-material regen + pin-nixpkgs drop (verify
`nix registry list | grep nixpkgs` post-deploy resolves to system pin).
---

## drift @ 0beecde (2026-04-23): both want MOVED (kin churn); have UNPROBEABLE 10th round

`kin status`: relay1+web2 `unreachable`, have="". `~/.ssh/kin-bir7vyhu*`
still absent — **and `kin-dwqfzbq5*` NOW ALSO ABSENT** (was present
mtime Apr-19-10:47 through r7; only `kin-infra-hosts` remains). Likely
homespace state loss. **have carried forward** from 53bed8f:
relay1=`dpxnfwvk`, web2=`l6wwl43y`.

```
relay1: have dpxnfwvk… (carried) ≠ want bg6drqcb…  drv igdnpx3x…
web2:   have l6wwl43y… (carried) ≠ want 375jz32a…  drv szm4pz75…
```

**Bisect 22ab7e3..0beecde:**
- 0e4dd69+eb6794c r5 packages/ + c10990b ask-local perms + 7e6e5d5
  tuicr — all packages/+modules/home nv1-only; relay1=9l7p6ryp
  web2=i6kjbnph unchanged (verified)
- d7d1096 iets e4098058→e1cd6980: relay1-neutral (9l7p6ryp unchanged),
  **web2 i6kjbnph→gxj4h6lw** (confirms bumper)
- 6ecfb12 srvos 01d98209→4968d2a4: **neutral both** (verified, confirms
  bumper)
- b657104 kin 3118eb1d→7d4c7bfd (netrc bridge): **relay1
  9l7p6ryp→xhcdw782**, **web2 gxj4h6lw→vv853xw3** — kin reaches both
- 5963105 zimbatm `flake update` (hm/iets/kin→a66409db/nixvim/
  llm-agents/nix-skills): **relay1-neutral** (xhcdw782 unchanged — kin
  7d4c7bfd..a66409db relay1-surface-neutral, others relay1-absent),
  **web2 vv853xw3→fzzrmr1l**
- fee393d kin a66409db→45cd3818 pin-back (drop EROFS regression):
  **relay1 xhcdw782→bg6drqcb**, **web2 fzzrmr1l→375jz32a** — kin
  45cd3818 vs both 7d4c7bfd and a66409db is relay1-distinct

Dry-build: relay1 352 drvs/264 fetch (222.4 MiB), web2 424 drvs/376
fetch (437.3 MiB) — **JUMP from 75/9 + 159/76** @ da0b27b
(cache.assise.systems likely hasn't built kin@45cd3818 pinned-back rev).

**relay1 now carries 14** (+b657104 +fee393d; 5963105 neutral); **web2
now carries 20** (+d7d1096 +b657104 +5963105 +fee393d). Reconcile: `kin
deploy relay1 web2`. Same nixpkgs b12141e since 608e987. Risk: kin 3-hop
churn settles at 45cd3818 pin-back (ahead of EROFS regression, behind
kin HEAD); web2 also +iets/hm/nixvim/llm-agents/nix-skills via 5963105.
have unprobed 10th round — can't confirm no out-of-band changes since
53bed8f.
