# nv1: deploy + walk deferred runtime checks

**What:** Run `kin deploy nv1` from a mesh-connected machine, then walk
the deferred runtime checks accumulated since 82d7737.

nv1 deployed = `i4yx1sbx…-nixos-system-nv1-26.05.20260409.4c1018d`;
declared @ this branch = `7wq8ql00…` (same nixpkgs 4c1018d, repo-local
drift only). Gap is now ~10 commits (was 7 @ 509c65d):

- 409ea70 — Meteor Lake NPU enable (ivpu + intel-npu-driver + openvino)
- a4dc86c — ptt-dictate GNOME `<Super>d` hotkey
- 205d703 — ask-local (llama-cpp+vulkan on Arc iGPU)
- c326db7 — nixvim.inputs.nixpkgs follows (nvim closure rebuild)
- 8a1aa5d — kin-opts wired into agentshell
- 24fbf66 — infer-queue (pueue lanes arc/npu/cpu; pueued user unit)
- 40e840f — kin bump 59dc9bda→4d49b8cd
- ce96923 — agent-eyes +poke (ydotool act-side)
- c9700ab — agent-meter (spend/occupancy gauge in starship + hm desktop)
- (this) — kin bump 4d49b8cd→f0f2098 + nv1.proxyJump=relay1

nv1 itself is healthy (`systemctl is-system-running` → `running`, no
failed units via ProxyJump probe).

**Runtime checks after deploy:**
- NPU: `python -c 'from openvino import Core; print(Core().available_devices)'` lists NPU
- ptt-dictate: `<Super>d` hotkey fires
- ask-local: ≥15 tok/s on Arc iGPU
- agent-eyes: `peek` works under GNOME Wayland; `poke key 125+32` (Super+d) works
- infer-queue: `infer-queue add -d arc …` lands in arc lane; `pueue status` shows pueued running
- agent-meter: starship segment renders; gauge shows Arc/NPU occupancy + queue depth

**Blockers:** Human-gated (CLAUDE.md). `kin deploy nv1` from this grind
worker would still fail — see structural note below.

---

## Structural: proxyJump landed, host-cert IPv6 principal gap remains

`machines.nv1.proxyJump = "relay1"` is now set (kin@ea0d9b8 via
f0f2098). `gen/ssh/_shared/config` emits `ProxyJump root@95.216.188.155`
for nv1; `kinManifest.machines.nv1.proxyJump = "root@95.216.188.155"`.
The drift-checker's manual `-J` workaround is obsolete.

**But** `kin status nv1` from this worker still fails: nv1's host cert
lists principal `fd0c:3964:8cda::6e42:b995:2026:deae` (compressed `::`
from kin.nix), while ssh canonicalizes to `…:0:…` before matching →
"Certificate invalid: name is not a listed principal" → host-key
verification fails under `StrictHostKeyChecking=yes`. Filed as
`../kin/backlog/bug-hostcert-ipv6-principal.md`. Independent of
proxyJump — would bite any operator hitting nv1 via its ULA with kin's
ssh_opts.

Workaround until kin fix lands: drift-checker can probe via
`kin ssh relay1 'ssh nv1.ztm …'` or keep the explicit form (no
StrictHostKeyChecking) from drift-nv1.md history.
