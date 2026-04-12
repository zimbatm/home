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

## drift @ 9e8c8e8 (2026-04-12): gap reopened, probe blocked

Since the e196255 deploy confirmed above, declared has moved again.
declared @ 9e8c8e8 want = `x93kiwy9…-nixos-system-nv1-26.05.20260409.4c1018d`
(same nixpkgs 4c1018d). Probe blocked on ops-worker-ssh-reauth.md (worker
key rotated; relay1 proxyJump auth fails) — last-known have `www09p3bx…`
@ 9403a95 carried forward.

New deploy-affecting commits since e196255 (8):

- c9491bc — modules/home/desktop: swap 4 llm-agents pkgs → nixpkgs (nv1-only)
- d90e847 — kin/iets/nix-skills/llm-agents bump + gen/* regen (all hosts)
- f4398c4 — transcribe-npu pkg + ptt-dictate NPU-prefer (nv1-only)
- 6f87665 — flake.lock follows-dedupe 30→19 nodes (all hosts)
- 3a891ab — agent-eyes: peek --ask moondream2 VLM (nv1-only)
- 7d092c5 — kin/iets internal bump (all hosts)
- b1f1bb3 — nix-index-database bump (all hosts)
- f7eaa19 — +treefmt-nix input + formatter/checks (all hosts)

No new runtime checks — transcribe-npu and peek --ask ride the existing
ptt-dictate/NPU and agent-eyes checks above. Deploy + the runtime-checks
list remain the only human-gated work.
