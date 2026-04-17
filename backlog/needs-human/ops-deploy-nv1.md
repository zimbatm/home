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

## Latest status (drift @ 7f572ea, 2026-04-15)

```
have: sxmv9yvi…  (carried forward from 53bed8f, NOT re-probed — worker blind)
want: /nix/store/9qwbl2bww0k5zpj0jz6f3jrlg6z7p3rx-nixos-system-nv1-26.05.20260409.4c1018d
```

Same nixpkgs 4c1018d throughout. Last confirmed have==want on
origin/main: `www09p3bx` @ 9403a95 (≈ e196255 deploy, 2026-04-11).
Hostcert IPv6 chicken-and-egg (structural note) was **resolved** at
that deploy. Since then probe was blind (worker key rotation) →
unblind @ d2ad1d1 (007ccaa cert re-sign) → blind again @ e969d2c (fleet
identity lost on worker).

## Reconcile

```sh
kin deploy nv1
```

Then walk the runtime checks. Then delete this file.

## nv1-affecting commits since e196255 (cumulative bisect log, compacted 2026-04-15)

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

Closure-neutral (verified): 2efe8bf, c27c5c1, e170608, 6bf3705,
d00a686, 9dbb216, 8172dfe, 24cc8e8, 2898dcd, 26cb8a9 (nv1-neutral),
bfcd408 (relay1-only). 821b625 srvos: relay1-neutral, nv1 not
bisected (server-profile, unlikely).

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
- **restic-gotosocial** (web2, carried) — `systemctl status restic-backups-gotosocial.{service,timer}`

---

## drift append-log

(drift-checker appends new `## drift @ <rev>` sections below; META
re-compacts into the table above when this section exceeds 3 entries)

### drift @ 0404fbb (2026-04-15): want 9qwbl2bw→x2p8iwvp; have UNPROBEABLE 3rd round

`kin status --json`: nv1 `have=""` health=not-on-mesh — `~/.ssh/kin-bir7vyhu*`
still absent (only kin-dwqfzbq5+kin-infra; ops-kin-login-worker.md
unactioned). **have carried forward** from 53bed8f: `sxmv9yvi` (off-main).

```
have: sxmv9yvi…  (carried, NOT re-probed)
want: /nix/store/x2p8iwvpl5g7y8f5casmi8pz23s2cxfa-nixos-system-nv1-26.05.20260409.4c1018d
```

**Bisect b411c2d..0404fbb** — 2 nv1-affecting commits (both packages/, nv1-only):
- 85d68cd ask-local --fast (llama-lookup speculative decoding + bench.sh):
  9qwbl2bw→vpdxwmdz
- 2194b90 sem-grep -r/--rerank (bge-reranker-base NPU stage-2):
  vpdxwmdz→x2p8iwvp
- 6673c0c internal bump (kin/iets/nix-skills): nv1-neutral (x2p8iwvp
  unchanged; per META r7, re-confirmed)

**+2 runtime checks** (append to list above on next compact):
- **ask-local --fast** — `ask-local --fast "<prompt>"` runs via llama-lookup;
  `packages/ask-local/bench.sh` reports tok/s ≥ plain path on the 4 cases
- **sem-grep -r** — `sem-grep -r "<q>"` loads bge-reranker-base on NPU
  (3rd tenant alongside VAD+bge-small); evals.jsonl shows `rerank:true`
  rows; fetch-hint fires if model dir absent

Same nixpkgs 4c1018d throughout. Reconcile unchanged: `kin deploy nv1`.

### drift @ b9b1d94 (2026-04-15): want x2p8iwvp→y1ii1g33; have UNPROBEABLE 4th round

`kin status --json`: empty — `~/.ssh/kin-bir7vyhu*` still absent (only
kin-dwqfzbq5+kin-infra mtime 12:17; ops-kin-login-worker.md unactioned
4th round). **have carried forward** from 53bed8f: `sxmv9yvi` (off-main).

```
have: sxmv9yvi…  (carried, NOT re-probed)
want: /nix/store/y1ii1g33cyc0aqqyhby6v6s6r4r9akw7-nixos-system-nv1-26.05.20260409.4c1018d
```

**Bisect 3a46943..b9b1d94** — 2 nv1-affecting merges (both packages/ +
home-module, nv1-only; relay1+web2-neutral verified):
- 07b2b2f ask-local --agent (bounded ReAct loop, tools.json +
  bench-agent.jsonl): x2p8iwvp→9mdzqlsm
- 99e9212 sem-grep log/index-log verbs + new
  modules/home/desktop/sem-grep.nix (nightly timer, puts sem-grep on
  PATH): 9mdzqlsm→y1ii1g33

**+2 runtime checks** (append to list above on next compact):
- **ask-local --agent** — `ask-local --agent "<goal>"` runs ≤4-turn
  ReAct loop; walk `packages/ask-local/bench-agent.jsonl` (20 goals,
  expect_tool+expect_substr); tools.json CLIs all resolve on PATH
- **sem-grep timer** — `systemctl --user list-timers | grep sem-grep`
  shows nightly index-log timer; `which sem-grep` on PATH (was only
  hist-sem alias before, now via hm module)

Same nixpkgs 4c1018d throughout. Reconcile unchanged: `kin deploy nv1`.
2 append-log entries — META compacts at 3.

### drift @ ead5fd4 (2026-04-17): want y1ii1g33→sw0fhi25 via 6; have UNPROBEABLE 5th round

`kin status nv1`: `have=—` health=not-on-mesh — `~/.ssh/kin-bir7vyhu*`
still absent (only kin-dwqfzbq5+kin-infra mtime Apr-15-12:17 unchanged;
ops-kin-login-worker.md unactioned 5th round). **have carried forward**
from 53bed8f: `sxmv9yvi` (off-main).

```
have: sxmv9yvi…  (carried, NOT re-probed)
want: /nix/store/sw0fhi25jaj1rfc5v312b1qi6lhkzhsz-nixos-system-nv1-26.05.20260409.4c1018d
```

**Bisect feac33c..ead5fd4** — 6 nv1-affecting commits (2 all-host, 4
nv1-only):
- dd5677f ask-local --agent {args} flag-injection guard + kin-hosts
  split (agent.py/tools.json/bench-agent.jsonl)
- b0b4acd modules/nixos/common.nix CA derivations (ALL 3 hosts)
- 0319657 kin gen — per-host certs/fps regenerated (ALL 3 hosts)
- cdd1904 ask-local default.nix mkdir-p before model-not-found check
- 61459a1 deepfilter noise cancellation (modules/home/desktop/ + nv1
  config `home.deepfilter.enable=true`)
- 497ddec iets pkg added to nv1 home.packages + iets flake.lock bump
  (nv1-only; relay1/web2 don't ref inputs.iets)
- non-closure: 9ba7bf5 .envrc, ead5fd4 flake.nix treefmtFor devshell,
  4ded977 backlog, marker commits

**+3 runtime checks** (append to list above on next compact):
- **deepfilter** — `pactl list sources short | grep -i deepfilter`
  shows virtual mic; `systemctl --user status pipewire` clean; speak
  into mic with fan noise → output denoised
- **CA derivations** — `nix config show | grep ca-derivations` shows
  enabled; build a trivial CA drv to confirm store accepts it
- **iets** — `which iets` on PATH (nv1 home.packages); `iets --version`

Same nixpkgs 4c1018d throughout. Reconcile unchanged: `kin deploy nv1`.
**3 append-log entries — META compact threshold reached.**
