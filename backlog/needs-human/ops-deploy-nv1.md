# nv1: deploy + walk deferred runtime checks

**What:** Run `kin deploy nv1` from a mesh-connected machine, then walk
the deferred runtime checks accumulated since 82d7737.

nv1 deployed = `i4yx1sbx…-nixos-system-nv1-26.05.20260409.4c1018d` (last
confirmed @ 509c65d; unprobeable from this worker — see structural
note); declared @ this branch = `mv28jx13…` (same nixpkgs 4c1018d,
repo-local drift only). Gap is now ~14 commits (was 10 @ 2d918a1):

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

**Runtime checks after deploy:**
- NPU: `python -c 'from openvino import Core; print(Core().available_devices)'` lists NPU
- ptt-dictate: `<Super>d` hotkey fires
- ask-local: ≥15 tok/s on Arc iGPU
- agent-eyes: `peek` works under GNOME Wayland; `poke key 125+32` (Super+d) works
- infer-queue: `infer-queue add -d arc …` lands in arc lane; `pueue status` shows pueued running
- agent-meter: starship segment renders; gauge shows Arc/NPU occupancy + queue depth
- pty-puppet: `pty-puppet @t spawn 'nix repl' && pty-puppet @t expect 'nix-repl>'`
- say-back: `echo hello | say-back` audible

**Blockers:** Human-gated (CLAUDE.md). `kin deploy nv1` from this grind
worker would still fail — see structural note below.

---

## Structural: hostcert IPv6 fix landed upstream, past current pin

`machines.nv1.proxyJump = "relay1"` is set; `gen/ssh/_shared/config`
emits the ProxyJump correctly. **But** `kin status nv1` from this worker
still reports `not-on-mesh` (have empty): nv1's host cert lists only the
compressed `::` form of its ULA as a principal, while ssh canonicalizes
to the `:0:` form before matching → "Certificate invalid: name is not a
listed principal" under `StrictHostKeyChecking=yes`.

**Upstream fix landed:** kin@8179a78 (`identity/machine: add RFC 5952
canonical IPv6 to host-cert principals`), merged da68650, past home's
current pin kin@43cfb97. See `backlog/bump-kin.md`. After bump + `kin
gen` (regenerates nv1 host cert with both forms) + this deploy, `kin
status nv1` works from any worker without workarounds.

Until then: drift-checker cannot probe nv1 `have` from this worker
(relay1→nv1 root ssh has no key path; direct -F gen/ssh fails on
host-key verification). Last-known `i4yx1sbx` carried forward.
