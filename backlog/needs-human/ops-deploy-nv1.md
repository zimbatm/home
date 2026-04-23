# nv1: deploy + walk deferred runtime checks

**What:** Run `kin deploy nv1` from a mesh-connected machine, then walk
the deferred runtime checks below.

**Blockers:** Human-gated (CLAUDE.md). From this grind worker `kin
status nv1` is currently UNPROBEABLE (ops-kin-login-worker.md — fleet
identity `~/.ssh/kin-bir7vyhu*` lost).

**⚠ Off-main `have`:** nv1 has been deployed from a dirty/off-branch
tree **twice** (d2ad1d1: `gfcs7jg5` matched no origin/main eval;
53bed8f: `sxmv9yvi` again off-main). **Confirm any intentional local
delta on nv1 is committed+pushed before `kin deploy nv1` overwrites
it.**

## Latest status (drift @ ead5fd4, 2026-04-17)

```
have: sxmv9yvi…  (carried forward from 53bed8f, NOT re-probed — worker blind 5th round)
want: /nix/store/sw0fhi25jaj1rfc5v312b1qi6lhkzhsz-nixos-system-nv1-26.05.20260409.4c1018d
```

Same nixpkgs 4c1018d throughout. Last confirmed have==want on
origin/main: `www09p3bx` @ 9403a95 (≈ e196255 deploy, 2026-04-11).
Hostcert IPv6 chicken-and-egg (structural note) was **resolved** at
that deploy. Since then probe was blind (worker key rotation) →
unblind @ d2ad1d1 (007ccaa cert re-sign) → blind again @ e969d2c (fleet
identity lost on worker; ops-kin-login-worker.md unactioned 5 rounds).

## Reconcile

```sh
kin deploy nv1
```

Then walk the runtime checks. Then delete this file.

## nv1-affecting commits since e196255 (cumulative bisect log, compacted 2026-04-17)

| commit | what | scope |
|---|---|---|
| c9491bc | desktop: 4 llm-agents pkgs → nixpkgs | nv1 |
| d90e847 | kin/iets/nix-skills/llm-agents bump + gen/ regen | all |
| f4398c4 | transcribe-npu pkg + ptt-dictate NPU-prefer | nv1 |
| 6f87665 | flake.lock follows-dedupe 30→19 nodes | all |
| 3a891ab | agent-eyes: peek --ask moondream2 VLM | nv1 |
| 7d092c5 | kin/iets internal bump | all |
| b1f1bb3 | nix-index-database bump | all |
| f7eaa19 | +treefmt-nix input + formatter/checks | all |
| eea133f | now-context --clip (wl-clipboard fold) | nv1 |
| 325a1bc | wake-listen pkg + user unit, NPU-gated | nv1 |
| 0d2890f | kin/iets internal bump | all |
| 0a84820 | srvos bump f56f105→7983ea7 | all |
| cb57e80 | modules/home self'=self.packages binding | nv1 |
| eb82a38 | ptt-dictate --intent (GBNF→intents.toml) | nv1 |
| 0ce69c5 | **Niri as 2nd GDM session** (modules/nixos/niri.nix) | nv1 |
| 3ae52ac | kin/iets internal bump | nv1+web2 |
| 51cb90c | home-manager bump e35c39f→f6196e5 | nv1 |
| e23db0f | sem-grep pkg (NPU bge-small over assise repos) | nv1 |
| d4e1fea | +crops-demo flake input (lock 19→32) | nv1+web2 |
| fc83166 | **crops-demo userland** (vfio-host + 7 CLIs, gated) | nv1 |
| 0d0321d | coord-panes pkg + agentshell wire | nv1 |
| ffef511 | live-caption-log pkg + hm module (off-by-default) | nv1 |
| dc59a67 | kin/iets internal bump | nv1+web2 |
| 1a5519c d60c257 | man-here pkg + skill | nv1 |
| 3b08f00 821a88e | tab-tap pkg + Firefox native-messaging | nv1 |
| 9b55b4e | kin/iets bump | all |
| c03a8a8 | nixvim bump | nv1 |
| 7cb19d4 | dconf `<Super>Return`→ghostty (fix hm registry wipe) | nv1 |
| 7d300c5 | foot default terminal; `<Super>Return`→foot | nv1 |
| 007ccaa | users.claude.sshKeys rotate + gen/ re-sign | all |
| dacd1ec | crops.nix: drop run-crops (crane IFD) | nv1 |
| c170da0 | packages/nvim: enableMan=false (eval -19%) | nv1 |
| 1201785 | gsnap compositor-aware (portal/grim) + per-session baselines | nv1 |
| f2c38c8 | kin/iets/nix-skills/llm-agents bump | all |
| 2419f94 | sel-act pkg + `<Super>a` keybind | nv1 |
| 107acef | sem-grep `hist` verb + bash feeder | nv1 |
| 082a29f | iets bump 396eb90→ef58583 | nv1+web2 |
| b016581 | home-manager bump f6196e5→8a423e4 | nv1 |
| 65e3984 | kin/iets/llm-agents/nixvim bump | nv1+web2 |
| 0251202 | niri: fonts += font-awesome+nerd-symbols+noto-emoji | nv1 |
| 396d2de | live-caption enable on nv1 (+retentionDays, +CLI) | nv1 |
| 35c8232 | common.nix: cache.assise.systems substituter | nv1+web2 |
| a603e7c | home-manager bump 8a423e4→3c7524c | nv1 |
| 94cf5c6 | wake-listen+transcribe-npu: ship models as FODs | nv1 |
| 2243fd1 | transcribe-npu: TRANSFORMERS_OFFLINE=1 HF_HUB_OFFLINE=1 | nv1 |
| 0580584 | wake-listen: silero-vad v5.1→v4.0; +StartLimitBurst | nv1 |
| e969d2c | wake-listen: res[p_out].item() ([1,1] output) | nv1 |
| 02441a9 | live-caption-log: stop swallowing errors + heartbeat | nv1 |
| e4d45cd | kin/iets/nix-skills/llm-agents bump (incl maille→b849d73) | all |
| 85d68cd | ask-local --fast (llama-lookup speculative + bench.sh) | nv1 |
| 2194b90 | sem-grep -r/--rerank (bge-reranker-base NPU stage-2) | nv1 |
| 07b2b2f | ask-local --agent (bounded ReAct loop, tools.json) | nv1 |
| 99e9212 | sem-grep log/index-log + modules/home/desktop/sem-grep.nix | nv1 |
| dd5677f | ask-local --agent {args} guard + kin-hosts split | nv1 |
| b0b4acd | common.nix: +ca-derivations experimental-feature | all |
| 0319657 | kin gen — per-host certs/fps + tls-ca regen | all |
| cdd1904 | ask-local: mkdir -p before model-not-found check | nv1 |
| 61459a1 | deepfilter noise cancellation (hm module + nv1 enable) | nv1 |
| 497ddec | iets pkg → nv1 home.packages + iets flake.lock bump | nv1 |

Closure-neutral (verified): 2efe8bf, c27c5c1, e170608, 6bf3705,
d00a686, 9dbb216, 8172dfe, 24cc8e8, 2898dcd, 26cb8a9 (nv1-neutral),
bfcd408 (relay1-only), 6673c0c (nv1-neutral internal bump), 9ba7bf5
(.envrc), ead5fd4 (treefmtFor devshell), 4ded977 (backlog). 821b625
srvos: relay1-neutral, nv1 not bisected (server-profile, unlikely).

## Runtime checks (cumulative, since e196255)

Walk these at the nv1 desk after deploy:

- **NPU** — `python -c 'from openvino import Core; print(Core().available_devices)'` lists NPU
- **ptt-dictate** — `<Super>d` fires; `--intent` mode dispatches per intents.toml
- **ask-local** — ≥15 tok/s on Arc iGPU
- **agent-eyes** — `peek` works under GNOME Wayland; `poke key 125+32` works
- **infer-queue** — `infer-queue add -d arc …` lands in arc lane; `pueue status` shows pueued running
- **agent-meter** — starship segment renders; gauge shows Arc/NPU occupancy + queue depth
- **pty-puppet** — `pty-puppet @t spawn 'nix repl' && pty-puppet @t expect 'nix-repl>'`
- **say-back** — `echo hello | say-back` audible
- **now-context** — `now-context | jq .` shows non-empty `focused.title`
- **llm-router** — `curl -s localhost:8090/v1/models` responds; small-prompt routes to ask-local:8088
- **wake-listen** — `systemctl --user status wake-listen` active (not crash-looping; StartLimitBurst catches it); `journalctl --user -u wake-listen -n5` shows VAD probabilities, no TypeError/OpConversionFailure
- **transcribe-npu** — invoke once with no network; model loads from store path, no HF Hub fetch in stderr
- **niri** — GDM picker lists "Niri"; session works; switching back to GNOME unaffected; waybar shows icon glyphs not tofu
- **sem-grep** — `sem-grep index && sem-grep "kin deploy"` returns hits; `sem-grep hist "<q>"` returns history lines; `sem-grep index-log && sem-grep log "wake-listen crash"` returns journald lines; walk packages/sem-grep/bench-log.txt (≥7/10 pass = keep, else rm verb + live-caption fold)
- **crops-userland** — `lsmod | grep -E 'vfio_pci|vfio_iommu'` loaded; CLIs in PATH (gated, off until toggled)
- **live-caption** — `systemctl --user status live-caption-log` active; `live-caption tail` follows today's jsonl; `live-caption off` stops unit; nightly reindex prunes >30d; `journalctl --user -u live-caption-log -n20` shows heartbeat; forced transcribe error surfaces in journal
- **man-here** — `man-here jq` renders store-exact docs
- **tab-tap** — Firefox about:addons lists tab-tap; `tab-tap read` returns Readability text of active tab
- **foot** — `<Super>Return` opens foot (server mode); ghostty still launchable
- **gsnap** — `gsnap capture` works under both GNOME (portal) and Niri (grim); per-session baseline dirs created
- **sel-act** — select text, hit `<Super>a` → ask-local transform menu; result replaces selection
- **ask-local --fast** — `ask-local --fast "<p>"` via llama-lookup; `packages/ask-local/bench.sh` tok/s ≥ plain on the 4 cases
- **sem-grep -r** — `sem-grep -r "<q>"` loads bge-reranker-base on NPU (3rd tenant); evals.jsonl shows `rerank:true` rows; fetch-hint fires if model dir absent
- **ask-local --agent** — `ask-local --agent "<goal>"` ≤4-turn ReAct; walk `packages/ask-local/bench-agent.jsonl` (20 goals, expect_tool+expect_substr); tools.json CLIs resolve on PATH
- **ask-local --mem** — `packages/ask-local/bench.sh --mem` runs cold×3 / warm-up+index / warm×3 over the 20-case agent bench; record `cold=X/20 warm=Y/20 dP50=+Nms PASS|FAIL`. Bar: warm ≥ cold+3 ∧ dP50 ≤ +150ms. PASS → flip `--mem` default on + llm-router keeps repeat-intent goals local; FAIL → memory-shaped goals route to cloud regardless of complexity gate. Also: `sem-grep index-runs && sem-grep runs "am I AFK?"` returns ≥1 JSON trace line
- **sem-grep timer** — `systemctl --user list-timers | grep sem-grep` shows nightly index-log; `which sem-grep` on PATH (was only hist-sem alias before)
- **deepfilter** — `pactl list sources short | grep -i deepfilter` shows virtual mic; `systemctl --user status pipewire` clean; speak with fan noise → output denoised
- **CA derivations** — `nix config show | grep ca-derivations` shows enabled; build a trivial CA drv to confirm store accepts
- **iets** — `which iets` on PATH; `iets --version`
- **restic-gotosocial** (web2, carried) — `systemctl status restic-backups-gotosocial.{service,timer}`

---

## drift append-log

(drift-checker appends new `### drift @ <rev>` sections below; META
re-compacts into the table above when this section exceeds 3 entries)

<!-- compacted @ aa28b38 (META r1, 2026-04-17): folded 0404fbb+b9b1d94+ead5fd4 into table+checks above -->

### drift @ 605cd1b (2026-04-17): want MOVED (5 commits incl nixpkgs bump); have UNPROBEABLE 6th round

`kin status --json`: empty — `~/.ssh/kin-bir7vyhu*` still absent (only
dwqfzbq5+infra mtime Apr-15-12:17 unchanged; ops-kin-login-worker.md
unactioned 6th round). **have carried forward** from 53bed8f:
nv1=`sxmv9yvi` (off-main).

```
have: sxmv9yvi…  (carried, NOT re-probed — worker blind 6th round)
want: /nix/store/lhz6s49yw6x0mwf4ni0banamp42wc73k-nixos-system-nv1-26.05.20260414.4bd9165
```

**⚠ nixpkgs moved** — was 4c1018d throughout, now 4bd9165 (fa68a27).
First nixpkgs bump in the pending stack since the e196255 deploy.

**Bisect ead5fd4..605cd1b** (sw0fhi25→lhz6s49y, 5 nv1-affecting):
- 6759648 model-autofetch: packages/{agent-eyes,ask-local,ptt-dictate,
  say-back,sem-grep} → shared `fetch_model` helper, auto-fetch on first
  run instead of hint+exit (sw0fhi25→hgm1srsh, nv1-only — relay1/web2
  verified neutral)
- 11edb95 maille bump b849d73→156486c peer_fleets cap (hgm1srsh→y7fkxsfh,
  ALL 3)
- fa68a27 **nixpkgs 4c1018d→4bd9165** + gitbutler-cli cargoPatches fix
  (y7fkxsfh→ic973czy, ALL 3)
- 4a60b42 internal bump kin 2785e63→e736801 + iets/nix-skills/llm-agents
  + `kin gen` re-sign per-host certs/fps (ic973czy→c73x6kl3, ALL 3)
- cadfc52 kin.nix `identity.peers.kin-infra` + `mesh.peerFleets` +
  gen/identity/peers/ (ADR-0011 reciprocal) (c73x6kl3→lhz6s49y, ALL 3)

Closure-neutral (verified): 7aa2a6e srvos bump (c73x6kl3 unchanged all
3 hosts — none import the bumped srvos paths). aa28b38 keys/peers/ cert
stage (unread until cadfc52). e41b5bc/f388e7e/a197fe6/ffdecfa/9904667/
ed83b09/e4d1e1a/605cd1b markers+backlog only.

**+2 runtime checks:**
- **fetch_model** — `rm -rf ~/.local/share/ask-local/models/<one>`;
  `ask-local "<q>"` auto-fetches (curl progress in stderr) instead of
  printing fetch-hint+exit-1. Same for sem-grep/say-back/agent-eyes/
  ptt-dictate first-run.
- **peer-kin-infra trust** — `grep -c '@cert-authority' /etc/ssh/ssh_known_hosts`
  includes kin-infra fleet CA; `maille config show | jq .peer_fleets`
  lists kin-infra; ssh from a kin-infra host lands without TOFU prompt.

### drift @ 5858216 (2026-04-17): want UNEVALABLE at HEAD; last-evalable 3f3124d snfxm0c9; have UNPROBEABLE 7th round

`kin status --json`: dies at eval — `Failed to fetch git repository
'ssh://git@github.com/assise/crops-demo'`. 5858216 (zimbatm out-of-band
`flake update`) bumped crops-demo cad8614b→0182fa2c (revCount 301→1,
repo recreated); worker key still 404s, sibling /root/src/crops-demo
lacks 0182fa2c. **Gate broken at HEAD** — filed
backlog/bug-eval-broken-crops-demo-5858216.md (revert crops-demo hunk).
`~/.ssh/kin-bir7vyhu*` still absent (only dwqfzbq5+infra mtime
Apr-15-12:17 unchanged 10th check; ops-kin-login-worker.md unactioned
7th round). **have carried forward** from 53bed8f: nv1=`sxmv9yvi`
(off-main).

```
have: sxmv9yvi…  (carried, NOT re-probed — worker blind 7th round)
want@3f3124d: /nix/store/snfxm0c9hpdi42q44j8fwvigzanm9cvx-nixos-system-nv1-26.05.20260414.4bd9165
want@5858216: UNEVALABLE (crops-demo fetch fails)
```

**Bisect 605cd1b..3f3124d** (lhz6s49y→snfxm0c9, 4 nv1-affecting):
- 8bde140 packages/lib/fetch-model.sh HF-repo-id validate +
  flags-before-positional (lhz6s49y→30ci0cam, nv1-only — relay1/web2
  verified neutral)
- 4ec63e0 ask-local --diff-gate + llm-router /review +
  modules/home/terminal pre-commit/starship hooks (30ci0cam→6wbrhkxa,
  nv1-only)
- 92d2cd8 sem-grep `sig` verb tree-sitter signature index
  (6wbrhkxa→72x0j76x, nv1-only)
- 483fadb internal bump kin e736801→df0a4b2 + iets/llm-agents
  (72x0j76x→snfxm0c9, nv1+web2; relay1-neutral)

Closure-neutral all 3 (verified): 3a809a9 nixvim bump 0a12693→4f75992
(snfxm0c9 unchanged — packages/nvim enableMan=false from c170da0 likely
makes the bumped paths unreferenced).

**5858216 unbisectable** — bumps 7 inputs (crops-demo home-manager iets
kin llm-agents maille nixvim); home-manager+maille+kin would move nv1
once eval is fixed. Re-bisect after bug-eval-broken-crops-demo-5858216
lands.

**+2 runtime checks:**
- **ask-local --diff-gate** — stage a diff, `ask-local --diff-gate`
  returns pass/fail JSON; pre-commit hook fires it; starship `diff_gate`
  segment renders on dirty tree; `curl -s localhost:8090/review -d
  @<diff>` responds.
- **sem-grep sig** — `sem-grep sig 'def main'` returns tree-sitter
  signature matches across indexed repos.

### drift @ ec62a90 (2026-04-22): want MOVED 4× (eval restored, crops-demo dropped); have UNPROBEABLE 8th round

`kin status --json`: nv1 `have=""` health=not-on-mesh.
`~/.ssh/kin-bir7vyhu*` still absent — **but dwqfzbq5+infra mtime CHANGED
Apr-15-12:17→Apr-19-10:47** (someone re-ran `kin login` on the worker
Apr-19 for the kin-infra fleet, NOT home; ops-kin-login-worker.md still
unactioned 8th round). **have carried forward** from 53bed8f:
nv1=`sxmv9yvi` (off-main).

```
have: sxmv9yvi…  (carried, NOT re-probed — worker blind 8th round)
want: /nix/store/zcz5jfkf4y1jhd5vz2klqjx6rm5c5pi5-nixos-system-nv1-26.05.20260414.4bd9165
```

**Eval restored** — 5858216 unevalable last round; META r1 (69f7bb4)
surgical-reverted crops-demo, then e98e1c5 dropped the input entirely.
69f7bb4 itself is now also unevalable (cad8614b store-GC'd) but
e98e1c5-onwards is independent of it.

**Bisect 3f3124d..ec62a90** (snfxm0c9→zcz5jfkf, 4 nv1-affecting; the
deferred 5858216 re-bisect):
- 69f7bb4 META keep-6 of zimbatm 5858216 (hm/iets/kin/llm-agents/maille/
  nixvim, crops-demo reverted): snfxm0c9→fqdl5ns7 (per META r1 commit
  msg; ALL 3 hosts — maille+kin reach all)
- e98e1c5 **drop crops-demo input** — vendor modules/nixos/vfio-host.nix
  (same crops.vfio.* interface), nv1 home.crops.enable=false, lock
  −crops-demo−10-transitive: fqdl5ns7→agkzmf1s (nv1-only; relay1/web2
  verified neutral)
- 3092054 vfio-host: replace reconstruction w/ recovered original —
  +crops.vfio.pciIds (overridable list), +crops.gpu.pciAddr nullable,
  +softdep amdgpu, drop gpu-default.nix import: agkzmf1s→szw7bfc1
  (nv1-only)
- c7939f0 iets bump 714989b→d6739fad (zimbatm out-of-band):
  szw7bfc1→zcz5jfkf (nv1+web2; relay1-neutral)

Closure-neutral all 3 (verified): 69158d6 flake inherit fleetManifest
from kinOut (eval-only), b911f6e `kin gen` (gen/manifest.lock rehash).

**Runtime check changes:**
- **crops-userland** check above is now **MOOT** — e98e1c5 set
  home.crops.enable=false (modules/home/desktop/crops.nix stubbed,
  throws on enable). Strike the "CLIs in PATH" half.
- **vfio-host (kernel side)** still applies, now vendored: `lsmod | grep
  -E 'vfio_pci|vfio_iommu'` loaded; `grep vfio-pci
  /etc/modprobe.d/nixos.conf` shows `ids=10de:28a0,10de:22be` + 3
  softdeps (nvidia/nouveau/amdgpu — amdgpu added @ 3092054).

### bump-nixpkgs @ f9f1694+1 (grind, 2026-04-22): want MOVED 2× since ec62a90

Bumper round, not drift — `have` not re-probed (worker still blind,
kin-bir7vyhu absent). Interstitial since last drift @ ec62a90:

- b7ea207 iets d6739fad→68367fb0 + nixfmt→iets-fmt swap + 3-file
  reformat: zcz5jfkf→**i1lvki9d** (nv1+web2; relay1-neutral). **⚠
  Regressed iets-eval of nv1** — IETS-0025 on
  `pathExists "${home-manager.src}/.git"` (hm `home.version.revision`);
  pre-existing on origin/main, cross-filed
  iets/backlog/bug-ifd-pathexists-realized-subpath.md. nix eval +
  `nix flake check --no-allow-import-from-derivation` still pass.

This commit — **nixpkgs 4bd9165→b12141e** (2026-04-14→04-18):
i1lvki9d→**zjw5mk6h** (ALL 3). No package fixes needed (gitbutler-cli/
nvim/llm-agents watch-points clean). Dry-build: 515 drvs to build,
1235 to fetch (4.4 GiB).

```
have: sxmv9yvi…  (carried, NOT re-probed)
want: /nix/store/zjw5mk6hls5xy4gnvdval64mjk2mkc85-nixos-system-nv1-26.05.20260418.b12141e
drv:  /nix/store/nxamxnp384876jdyajiy9jxhhlqkif2b-nixos-system-nv1-26.05.20260418.b12141e.drv
```

**⚠ 2nd nixpkgs in pending stack** (after fa68a27 4c1018d→4bd9165).
Risk profile: full nixpkgs minor ×2.

### bump-nix-index-database @ 2a6538f+1 (grind, 2026-04-22): nv1-only

Bumper round — `have` not re-probed. Interstitial since 608e987:
3dd9fb7 nixos-hardware c775c277→72674a6b — **closure-neutral all 3**
(zjw5mk6h unchanged, verified prior round).

This commit — **nix-index-database bedba598→c43246d4** (2026-04-12→
04-22, 10d): zjw5mk6h→**s946x49k** (nv1-only; relay1 m39a2zk3 + web2
48l2zlxg verified unchanged — neither imports nix-index/comma).
Data-only weekly index regen. Dry-build: 512 drvs to build, 1233 to
fetch (4.4 GiB) — dominated by pending nixpkgs stack, not this bump.

```
have: sxmv9yvi…  (carried, NOT re-probed)
want: /nix/store/s946x49k8770hy156lw2j5q1gn6f3mz8-nixos-system-nv1-26.05.20260418.b12141e
drv:  /nix/store/86mfsyd401rgdab65nxb8bn7vaq3f84s-nixos-system-nv1-26.05.20260418.b12141e.drv
```

Risk profile: trivially-low (data-only, nv1-only, no service surface).

### drift @ da0b27b (2026-04-22): want MOVED 2× since last journal; have UNPROBEABLE 9th round

`kin status --json`: nv1 `not-on-mesh`, have="" — `~/.ssh/kin-bir7vyhu*`
still absent (dwqfzbq5 mtime Apr-19-10:47 unchanged; kin-infra-hosts
mtime Apr-22-07:31 hosts-only). **have carried forward**: `sxmv9yvi`
(off-main).

**⚠ Prior entry s946x49k was side-branch** — a6c394a is NOT a 206cf2d
ancestor; merge 294585c kept journal-only. Main-line never evaluated to
s946x49k; actual sequence zjw5mk6h→l7pfiyl7→km5rdiqw.

**Bisect a6c394a-journal..da0b27b (main-line):**
- ed7d465 simplify crops-residue (-28L): nv1 zjw5mk6h **unchanged**
  (verified; drvPath-neutral as claimed)
- 206cf2d internal bump kin 26243512→3118eb1d + iets 68367fb0→e4098058
  + nix-skills 395c80af→9178f1f1 + llm-agents c4a2f76e→bb6fb1ef + `kin
  gen` (NEW gen/identity attest.{key.age,pub} per-machine + operator-
  {claude,zimbatm,migration-test} TLS + operator sign.key) + drop
  modules/nixos/pin-nixpkgs.nix (-7L, kin upstream now handles):
  zjw5mk6h→**l7pfiyl7** (ALL 3)
- f1e5fca nix-index-db bedba598→c43246d4 (re-land on main-line):
  l7pfiyl7→**km5rdiqw** (nv1-only)
- 73d5ccf merge crops-residue: **unchanged** (km5rdiqw verified)

```
have: sxmv9yvi…  (carried, NOT re-probed)
want: /nix/store/km5rdiqwfnxzidv525vm82xgjpay0dig-nixos-system-nv1-26.05.20260418.b12141e
drv:  /nix/store/2hvgz8d6cd7gnkwy4h6ln2bmxal9j4rg-nixos-system-nv1-26.05.20260418.b12141e.drv
```

Dry-build: 509 drvs / 1204 fetch (3.9 GiB).

**Runtime check changes (206cf2d):**
- **pin-nixpkgs** dropped — verify `nix registry list | grep nixpkgs`
  and `echo $NIX_PATH` still resolve to the system nixpkgs (kin upstream
  now provides this; regression = `nix-shell -p` pulls channel)
- **attest identity** new — `ls /run/kin/identity/attest.*` exists
  post-deploy (kin 3118eb1d feature; per-machine attestation key)

Risk profile: internal-bump dominated (kin/iets/nix-skills/llm-agents,
all assise-local) + identity-material regen + 1 module drop. Same
nixpkgs b12141e since 608e987.

### drift @ 0beecde (2026-04-23): want MOVED 7× since da0b27b; have UNPROBEABLE 10th round

`kin status nv1`: empty output. `~/.ssh/kin-bir7vyhu*` still absent —
**and `kin-dwqfzbq5*` NOW ALSO ABSENT** (was present mtime Apr-19-10:47
through r7; only `kin-infra-hosts` remains, mtime Apr-23-05:22 = this
round's `kin status` write). Likely homespace state loss; both fleets
need `kin login` now. ops-kin-login-worker.md unactioned 10th drift
round. **have carried forward**: `sxmv9yvi` (off-main).

```
have: sxmv9yvi…  (carried, NOT re-probed — worker blind 10th round)
want: /nix/store/dvgqw9cgdls3v76qsd8jxzakr2sfjgfn-nixos-system-nv1-26.05.20260418.b12141e
drv:  /nix/store/i7fn1sbawaci8r7k51m041a9zddqshlj-nixos-system-nv1-26.05.20260418.b12141e.drv
```

**Bisect 22ab7e3..0beecde** (km5rdiqw→dvgqw9cg, 7 nv1 moves):
- 0e4dd69+eb6794c r5-merges sem-grep `refs` verb + ask-local `--mem`
  trace-retrieval + sem-grep `runs`/`index-runs`: km5rdiqw→**8bfq9s56**
  (nv1-only — relay1/web2 verified neutral)
- d7d1096 iets e4098058→e1cd6980: 8bfq9s56→**zyn8gd7w** (nv1+web2;
  relay1-neutral, confirms bumper)
- c10990b ask-local owner-only perms 0o700/0o600 on state+traces:
  zyn8gd7w→**xy3vk45v** (nv1-only)
- 7e6e5d5 terminal +tuicr (llm-agents pkg, TUI diff review):
  xy3vk45v→**1qml6kwp** (nv1-only)
- b657104 kin 3118eb1d→7d4c7bfd (access-tokens→netrc bridge):
  1qml6kwp→**q66g1har** (ALL 3)
- 5963105 **zimbatm out-of-band `flake update`** — hm 565e5349→936d579f
  + iets e1cd6980→34686f1f + kin 7d4c7bfd→a66409db + nixvim
  698d1749→53aad7a9 + llm-agents bb6fb1ef→bd0e8933 + nix-skills
  9178f1f1→4199b5e6: q66g1har→**b5cn8gij** (nv1+web2; **relay1-neutral**
  — kin 7d4c7bfd..a66409db delta doesn't reach relay1 surface, hm/nixvim/
  llm-agents/nix-skills relay1-absent)
- fee393d kin a66409db→**45cd3818 pin-back** (keep netrc bridge, drop
  `--store local://` EROFS regression; see bump-kin-blocked-erofs.md):
  b5cn8gij→**dvgqw9cg** (ALL 3)

Closure-neutral all 3 (verified): 6ecfb12 srvos 01d98209→4968d2a4
(zyn8gd7w/9l7p6ryp/gxj4h6lw unchanged — confirms bumper claim). 0beecde
backlog-only.

Dry-build: 726 drvs / 1996 fetch (4.8 GiB) — **JUMP from 509/1204/3.9
GiB** @ da0b27b (hm+nixvim bump + kin-stack churn; cache.assise.systems
likely hasn't built kin@45cd3818 yet — pinned-back rev).

**+3 runtime checks:**
- **sem-grep refs** — `sem-grep refs <symbol>` returns file:line for
  every ts-identifier use across indexed repos; walk
  `packages/sem-grep/bench-refs.txt` ground truth
- **tuicr** — `tuicr` over a staged diff renders TUI; comments export
  as markdown for backlog/ round-trip
- **ask-local perms** — `stat -c '%a' ~/.local/state/ask-local{,/*.jsonl}`
  shows 700/600 (c10990b hardening)

Risk profile: internal-bump dominated + 1 hm bump + 1 nixvim bump + kin
3-hop churn (3118eb1d→7d4c7bfd→a66409db→45cd3818-pin). Same nixpkgs
b12141e since 608e987. ⚠ kin@45cd3818 is a pin-back — deployed kin
runtime will be ahead of the EROFS regression but behind kin HEAD.
