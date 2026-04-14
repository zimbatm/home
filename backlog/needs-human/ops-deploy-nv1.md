# nv1: deploy + walk deferred runtime checks

**What:** Run `kin deploy nv1` from a mesh-connected machine, then walk
the deferred runtime checks accumulated since 82d7737.

nv1 deployed = `i4yx1sbx…-nixos-system-nv1-26.05.20260409.4c1018d` (last
confirmed @ 509c65d; still unprobeable from this worker — see structural
note); declared @ 6fcd114 = `0i4lkscz…` (same nixpkgs 4c1018d,
repo-local drift only). Gap is now ~19 commits (was 14 @ 92818b4):

- 409ea70 — Meteor Lake NPU enable (ivpu + intel-npu-driver + openvino)
- a4dc86c — ptt-dictate GNOME `<Super>d` hotkey
- 205d703 — ask-local (llama-cpp+vulkan on Arc iGPU)
- c326db7 — nixvim.inputs.nixpkgs follows (nvim closure rebuild)
- 8a1aa5d — kin-opts wired into agentshell
- 24fbf66 — infer-queue (pueue lanes arc/npu/cpu; pueued user unit)
- 40e840f — kin bump 59dc9bda→4d49b8cd
- ce96923 — agent-eyes +poke (ydotool act-side)
- c9700ab — agent-meter (spend/occupancy gauge in starship + hm desktop)
- 2d918a1 — kin bump 4d49b8cd→f0f2098 + nv1.proxyJump=relay1
- 8954ef0 — pty-puppet (tmux expect/send; agentshell + hm desktop)
- 80d0d6a — say-back (piper-tts→pw-play; hm desktop)
- 9649a5f — kin bump f0f2098→43cfb97
- 4039530 — activitywatch.nix watcher units genAttrs refactor
- 13d408b — now-context (activitywatch :5600 ambient-state CLI; hm desktop + skill)
- 85aed14 — llm-router (:8090 shape-proxy → ask-local|upstream; hm desktop)
- 23376bf — kin bump 43cfb97→a33a3dc + `kin gen` (nv1 hostcert now lists both IPv6 forms)
- b5e638f — iets bump 11d1e715→e9669508
- 55c4a4d — drop dead `flake=inputs.self` specialArg

**Runtime checks after deploy:**
- NPU: `python -c 'from openvino import Core; print(Core().available_devices)'` lists NPU
- ptt-dictate: `<Super>d` hotkey fires
- ask-local: ≥15 tok/s on Arc iGPU
- agent-eyes: `peek` works under GNOME Wayland; `poke key 125+32` (Super+d) works
- infer-queue: `infer-queue add -d arc …` lands in arc lane; `pueue status` shows pueued running
- agent-meter: starship segment renders; gauge shows Arc/NPU occupancy + queue depth
- pty-puppet: `pty-puppet @t spawn 'nix repl' && pty-puppet @t expect 'nix-repl>'`
- say-back: `echo hello | say-back` audible
- now-context: `now-context | jq .` shows `{afk,focused,last_15m}` with non-empty `focused.title` (falsifies GNOME/Wayland title population)
- llm-router: `curl -s localhost:8090/v1/models` responds; small-prompt routes to ask-local:8088

**Blockers:** Human-gated (CLAUDE.md). `kin deploy nv1` from this grind
worker would still fail — see structural note below.

---

## Structural: hostcert IPv6 fix regenerated, awaiting deploy

`kin status nv1` from this worker still reports `not-on-mesh` (have
empty). Root cause unchanged: nv1's *deployed* host cert lists only the
compressed `::` form of its ULA as a principal; ssh canonicalizes to the
`:0:` form → "Certificate invalid: name is not a listed principal" under
`StrictHostKeyChecking=yes`.

**Repo side is done:** kin@8179a78 fix bumped in (23376bf,
kin@a33a3dc), `kin gen` regenerated `gen/identity/machine/nv1/ssh-host.cert`
with both IPv6 principal forms. `backlog/bump-kin.md` consumed.

**Remaining:** nv1 still *presents* the old cert until this deploy
lands. Chicken-and-egg for the grind worker — deploy must come from a
mesh-connected machine (or one-shot `-o StrictHostKeyChecking=accept-new`).
After deploy, `kin status nv1` works from any worker without workarounds
and drift-checker can probe `have` directly.

Until then: last-known `i4yx1sbx` carried forward.

---

## drift-checker @ 9403a95 (2026-04-11): deploy landed, nv1 now probeable

`kin status --json` from the grind worker now returns nv1 **have == want**
= `www09p3bx…-nixos-system-nv1-26.05.20260409.4c1018d` (health=running,
secrets=active, no failed units, uptime 3d8h). No `not-on-mesh`; nv1's
new host cert (both IPv6 principal forms, regenerated @ 23376bf) is now
presented — the structural chicken-and-egg above is **resolved**.

`want` here == `want` @ e196255 (no nix-touching commits since; 671c868
and 9403a95 are backlog-only), so nv1 was deployed at or after e196255
alongside or shortly after the relay1/web2 redeploy in 671c868. The
19-commit gap above is closed.

**What remains for a human:** the runtime-checks list only (NPU/hotkey/
ask-local/agent-eyes/infer-queue/agent-meter/pty-puppet/say-back/
now-context/llm-router). Those need someone at the nv1 desk. Once
walked, this file can be deleted.

---

## drift @ 93e01e7 (2026-04-12): gap grown, probe still blocked

Since the e196255 deploy confirmed above, declared has moved again.
declared @ 93e01e7 want = `63yvjk31…-nixos-system-nv1-26.05.20260409.4c1018d`
(same nixpkgs 4c1018d). Probe still blocked on ops-worker-ssh-reauth.md
(worker key rotated; relay1 proxyJump auth fails) — last-known have
`www09p3bx…` @ 9403a95 carried forward.

New deploy-affecting commits since e196255 (13):

- c9491bc — modules/home/desktop: swap 4 llm-agents pkgs → nixpkgs (nv1-only)
- d90e847 — kin/iets/nix-skills/llm-agents bump + gen/* regen (all hosts)
- f4398c4 — transcribe-npu pkg + ptt-dictate NPU-prefer (nv1-only)
- 6f87665 — flake.lock follows-dedupe 30→19 nodes (all hosts)
- 3a891ab — agent-eyes: peek --ask moondream2 VLM (nv1-only)
- 7d092c5 — kin/iets internal bump (all hosts)
- b1f1bb3 — nix-index-database bump (all hosts)
- f7eaa19 — +treefmt-nix input + formatter/checks (all hosts)
- eea133f — now-context --clip flag (wl-clipboard fold) (nv1-only)
- 325a1bc — wake-listen pkg + systemd --user unit, NPU-gated (nv1-only)
- 0d2890f — kin/iets internal bump (all hosts)
- 0a84820 — srvos bump f56f105→7983ea7 (all hosts)
- cb57e80 — modules/home self' = inputs.self.packages binding (nv1-only)

(2efe8bf devshell-treefmt + drop `overlays=[]` is closure-neutral —
relay1 want unchanged across it.)

**One new runtime check:** wake-listen — `systemctl --user status
wake-listen` active on nv1 (ConditionPathExists=/dev/accel/accel0);
Silero VAD on NPU gates ptt-dictate. now-context --clip rides the
existing now-context check. Deploy + runtime-checks list remain the
only human-gated work.

---

## drift @ 41238a4 (2026-04-12): r15-r16 closure delta

Probe still blind (ops-worker-ssh-reauth.md — worker key rotated,
publickey denied on all 3). Last-known have `www09p3bx…` @ 9403a95
carried forward. declared @ 41238a4 want =
`rmbkbby6…-nixos-system-nv1-26.05.20260409.4c1018d` (was `63yvjk31…`
@ 93e01e7; same nixpkgs 4c1018d).

New deploy-affecting commits since 93e01e7 (6):

- eb82a38 — ptt-dictate --intent (GBNF classify → intents.toml dispatch; +ask-local grammar) (nv1-only)
- 0ce69c5 — **nv1: Niri as second GDM session** (modules/nixos/niri.nix +144L; machines/nv1 import) (nv1-only)
- 3ae52ac — kin/iets internal bump (web2+nv1; relay1 closure-neutral)
- 51cb90c — home-manager bump e35c39f→f6196e5 (nv1-only)
- e23db0f — packages/sem-grep (NPU embedding index over assise repos; flake.nix export) (nv1-only)
- d4e1fea — +crops-demo flake input (lock 19→32 nodes; consumed by pending adopt-crops-userland) (nv1+web2; relay1 closure-neutral)

**Two new runtime checks:**
- niri — GDM session picker lists "Niri"; selecting it starts a working
  session; switching back to GNOME unaffected (lockout-recovery: GNOME
  stays default, Niri is opt-in at picker)
- sem-grep — `sem-grep index && sem-grep "kin deploy"` returns hits
  (falsifies NPU bge-small co-residency w/ transcribe-npu)

ptt-dictate check above extends to `--intent` mode (speak "open
terminal" → dispatched per intents.toml). Deploy + runtime-checks list
remain the only human-gated work.

---

## drift @ e8c0ad4 (2026-04-12): r17-r20 closure delta

Probe still blind (ops-worker-ssh-reauth.md — `kin status` returns
`not-on-mesh`, have empty). Last-known have `www09p3bx…` @ 9403a95
carried forward. declared @ e8c0ad4 want =
`3mschyps…-nixos-system-nv1-26.05.20260409.4c1018d` (was `rmbkbby6…`
@ 41238a4; same nixpkgs 4c1018d).

New deploy-affecting commits since 41238a4 (4; c27c5c1 follows-dedupe
is drvPath-identical, closure-neutral):

- fc83166 — **nv1: crops-demo userland** (machines/nv1 +vfio-host import; modules/home/desktop/crops.nix +7 CLIs, gated) (nv1-only)
- 0d0321d — coord-panes pkg + agentshell wire (flake.nix export; dev-tool) (nv1-only)
- ffef511 — live-caption-log pkg + hm module, **off-by-default** pending ops-live-caption-privacy (nv1-only)
- dc59a67 — kin/iets internal bump 69dbf2a→12d99c5 / 7d651f2→8259dcd (nv1+web2; relay1 closure-neutral — want unchanged)

**Two new runtime checks:**
- crops-userland — `lsmod | grep -E 'vfio_pci|vfio_iommu'` loaded;
  `crops-guest list` (or whichever of the 7 CLIs is the entry) runs
  without "module not found" (gate is feature-flag, so off until
  toggled — verify CLIs in PATH at minimum)
- live-caption-log — stays inert until ops-live-caption-privacy
  resolves; if enabled: `systemctl --user status live-caption-log`
  active + `~/.local/share/live-caption/*.jsonl` grows during audio
  playback

coord-panes is agentshell/dev-side; no nv1 desk check. Deploy +
runtime-checks list remain the only human-gated work.
---

## drift @ d2ad1d1 (2026-04-14): probe unblind; nv1 deployed off-main

`kin status --json` from this worker now returns live data for all 3
hosts (no `not-on-mesh`, no publickey-denied). Unblind path: 007ccaa
`kin gen` re-signed gen/identity/user-claude/_shared/certs for the
current worker key; deployed sshd already trusts home-CA, so the local
cert suffices — ops-worker-ssh-reauth resolved without needing 007ccaa
itself deployed.

**relay1 + web2: have == want** (relay1 `dpxnfwvk…`, web2
`zv4kapl1…`; health=running, secrets=active, failed=-). Human deployed
both at or after e50356f. `ops-deploy-relay1-web2.md` deleted — gap
closed. One web2 runtime check carried here: `systemctl status
restic-backups-gotosocial.{service,timer}` (e50356f hourly→rsync.net;
`kin set` for rsyncnet password must have landed or first timer fire
will fail).

**nv1: have ≠ want.**
```
have: /nix/store/gfcs7jg5f5k5zb0yy9wf2jmqip1rjcgf-nixos-system-nv1-26.05.20260409.4c1018d
want: /nix/store/db5j0ss1r5hqr9rchqfpwlhszv070405-nixos-system-nv1-26.05.20260409.4c1018d
```
uptime 0d18h (boot ~2026-04-13 18:40Z). want `db5j0ss1` is stable
since c170da0 — e50356f (gotosocial, web2-only) and d2ad1d1 (harness)
are nv1-closure-neutral.

**have `gfcs7jg5` matches NO commit on origin/main.** Evaluated nv1
toplevel at 7 points 821a88e..c170da0 (p8rjl6gv, 7y92ns00, pln9jmzq,
dvvzcpy6, 6xjfsk8i, 1y04sk7i, db5j0ss1) — none match. nv1 was deployed
from a dirty tree or an off-branch ref. Reconcile = `kin deploy nv1`
to bring it to a reproducible state; if the off-main delta was
intentional, commit it first.

New nv1-affecting commits since e8c0ad4 refresh (9; 9b55b4e nv1=hb3ac25
already noted by bumper):

- 1a5519c / d60c257 — man-here pkg + skill (terminal/default.nix)
- 3b08f00 / 821a88e — tab-tap pkg + Firefox native-messaging extension
- 9b55b4e — kin/iets bump (d5b44cb / 62a6681)
- c03a8a8 — nixvim bump (3682e0d)
- 7cb19d4 — dconf custom-keybinding `<Super>Return`→ghostty (fix hm-activation registry wipe)
- 7d300c5 — foot as default terminal; `<Super>Return`→foot
- 007ccaa — users.claude.sshKeys rotate + gen/ re-sign
- dacd1ec — crops.nix: drop run-crops (IFD via crane; `nix run crops-demo#run-crops` ad-hoc instead)
- c170da0 — packages/nvim: enableMan=false (eval -19%)

**Three new runtime checks:**
- foot — `<Super>Return` opens foot (server mode); ghostty still
  launchable
- tab-tap — Firefox about:addons lists tab-tap; `tab-tap read` from a
  shell returns Readability text of the active tab
- man-here — `man-here jq` (or any PATH CLI) renders store-exact docs

Deploy + runtime-checks list remain the only human-gated work. The
**off-main `have`** is the new flag — confirm no intentional local
delta on nv1 before deploy overwrites it.

---

## drift @ 589a2f5 (2026-04-12): want moved, have unchanged off-main

`kin status --json` live:
```
have: /nix/store/gfcs7jg5f5k5zb0yy9wf2jmqip1rjcgf-nixos-system-nv1-26.05.20260409.4c1018d
want: /nix/store/fvq2yl042n4vaz7mcpr3nfkfzkhv3h88-nixos-system-nv1-26.05.20260409.4c1018d
```
have `gfcs7jg5` unchanged since d2ad1d1 (still off-main, still
unmatched against any origin/main eval; uptime 0d18h same boot). want
`db5j0ss1`→`fvq2yl04` via 2 nv1-affecting commits since fbececb:

- 1201785 — gsnap compositor-aware (xdg-portal GNOME / grim wlroots) +
  per-desktop baselines; modules/home/desktop +20L (nv1-only)
- f2c38c8 — kin/iets/nix-skills/llm-agents internal bump; drop stale
  llm-agents follows (all hosts; relay1 bisect confirms closure delta)

Closure-neutral for nv1 (verified via relay1 bisect @ 7e93604):
6bf3705 kin.nix `admin=true` drop (mkDefault'd), d00a686 IFD-ban
(flake.nix nixConfig + grind harness only). 821b625 srvos bump
relay1-neutral; nv1 not bisected but srvos is server-profile —
unlikely nv1-affecting.

**One new runtime check:**
- gsnap — `gsnap capture` works under both GNOME (xdg-portal path)
  and Niri (grim path); per-desktop baseline dirs created

Off-main `have` flag from d2ad1d1 still stands — confirm no
intentional local delta on nv1 before `kin deploy nv1` overwrites it.
---

## drift @ 0251202 (2026-04-14): want moved, have unchanged off-main

`kin status --json` live (probe ok, all 3 reachable):
```
have: /nix/store/gfcs7jg5f5k5zb0yy9wf2jmqip1rjcgf-nixos-system-nv1-26.05.20260409.4c1018d
want: /nix/store/fvazrzw4f1v85fg8lyyikdd2bny597ic-nixos-system-nv1-26.05.20260409.4c1018d
```
have `gfcs7jg5` unchanged since d2ad1d1 (still off-main, uptime 0d22h —
same boot). want `fvq2yl04`→`fvazrzw4` via 6 nv1-affecting commits
since 589a2f5 (e170608 gen-regen drvPath-identical, neutral):

- 2419f94 — sel-act pkg + `<Super>a` keybind (wayland selection →
  ask-local transform; modules/home/desktop +30L) (nv1-only)
- 107acef — sem-grep `hist` verb + bash PROMPT_COMMAND feeder
  (modules/home/terminal +19L) (nv1-only)
- 082a29f — iets bump 396eb90→ef58583 (nv1+web2; relay1-neutral)
- b016581 — home-manager bump f6196e5→8a423e4 (nv1-only)
- 65e3984 — kin 0feb503→1306b57 + iets/llm-agents/nixvim bump
  (nv1+web2; relay1-neutral — commit msg "host drvPaths unchanged" is
  wrong for web2, see ops-deploy-relay1-web2.md bisect)
- 0251202 — niri: fonts.packages += font-awesome + nerd-fonts.symbols-only
  + noto-emoji (waybar tofu fix) (nv1-only)

**Three new runtime checks:**
- sel-act — select text in any wayland app, hit the sel-act keybind →
  ask-local transform menu appears; result replaces selection
- sem-grep hist — open fresh bash, run a few commands, then
  `sem-grep hist "<semantic query>"` returns relevant history lines
  (falsifies feeder hook + NPU index append)
- niri waybar glyphs — log into Niri session; waybar shows icon glyphs
  (Font Awesome / nerd-symbols), not tofu boxes

Off-main `have` flag from d2ad1d1 still stands — confirm no
intentional local delta on nv1 before `kin deploy nv1` overwrites it.
---

## drift @ 53bed8f (2026-04-14): have moved off-main AGAIN, want +live-caption

`kin status --json` live (probe ok, all 3 reachable, health=running, 0 failed):
```
have: /nix/store/sxmv9yvibgy7xvf56yfg09gjm99knnjv-nixos-system-nv1-26.05.20260409.4c1018d
want: /nix/store/xx8swk3nzr3ck07z3lr93sp8bcz2rpmh-nixos-system-nv1-26.05.20260409.4c1018d
```
have `gfcs7jg5`→`sxmv9yvi` since e4c1d3d (uptime 0d22h→1d2h, same
boot — switched-not-rebooted in the ~4h window). `sxmv9yvi` is
**off-main again**: eval at every commit 0251202..53bed8f yields only
`fvazrzw4` (pre-396d2de) or `xx8swk3n` (post). Second consecutive
off-main have (`gfcs7jg5` since d2ad1d1, now `sxmv9yvi`) — nv1 is
being deployed from a working tree or local branch, not origin/main.
**Confirm the local delta is intentional before `kin deploy nv1`
overwrites it** — or commit+push the local tree first.

want `fvazrzw4`→`xx8swk3n` via **1 commit** since e4c1d3d:

- 396d2de — live-caption enable on nv1 (`home.live-caption.enable=true`
  in machines/nv1/configuration.nix); module +`retentionDays` opt
  (default 30, prune in nightly reindex) + `live-caption
  {on|off|status|tail}` CLI wrapper (nv1-only; relay1+web2
  closure-neutral, verified want unchanged)

**One new runtime check:**
- live-caption — `systemctl --user status live-caption-log` active;
  `live-caption tail` follows today's jsonl; `live-caption off`
  stops the unit; nightly reindex prunes
  `~/.local/state/live-caption/*.jsonl` older than 30d
