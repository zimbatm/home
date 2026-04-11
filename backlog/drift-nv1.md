# nv1: deployed ≠ declared (repo-local drift)

**What:** nv1 is running `i4yx1sbx…-nixos-system-nv1-26.05.20260409.4c1018d`;
declared toplevel @ cb5eaa3 is
`6smhxby3…-nixos-system-nv1-26.05.20260409.4c1018d`. Same nixpkgs
(4c1018d) — drift is entirely repo-local commits not yet deployed. Want
closure is **not** in nv1's store (diff-closures: "no substituter can
build it"), so nothing has pushed it. relay1/web2 both match HEAD
(have==want, health=running).

**Why:** Several recent commits land nv1-only changes whose runtime
verification was explicitly "deferred to human deploy on nv1":

- 409ea70 — Meteor Lake NPU enable (ivpu module + intel-npu-driver +
  openvino probe)
- a4dc86c — ptt-dictate GNOME `<Super>d` hotkey
- 205d703 — ask-local (llama-cpp+vulkan on Arc iGPU)
- c326db7 — nixvim.inputs.nixpkgs follows (rebuilds nvim closure)

None of these are in the running system. nv1 is otherwise healthy
(`systemctl is-system-running` → `running`, no failed units).

**How much:** Human runs `kin deploy nv1` from a mesh-connected
machine, then verifies the deferred runtime checks above (NPU device
enum via `python -c 'from openvino import Core;
print(Core().available_devices)'`; ptt-dictate hotkey; ask-local
≥15tok/s falsification; agent-eyes `peek` under GNOME Wayland).

**Blockers:** Human-gated deploy (CLAUDE.md). Also: see structural
note below — `kin deploy nv1` from this grind worker would fail the
same way `kin status nv1` does.

---

## Structural: `kin status nv1` is blind from grind worker

`kin status nv1` here returns `health: not-on-mesh` / `have: ""`
because `machines.nv1.host = "fd0c:3964:8cda::6e42:b995:2026:deae"`
(mesh ULA only) and the grind worker is not a mesh peer (`Network is
unreachable`). nv1 **is** up — `ping` from relay1 succeeds.

**Workaround used this round:**
```sh
ssh -i ~/.ssh/kin_ed25519 -o CertificateFile=~/.ssh/kin_ed25519-cert.pub \
    -J root@95.216.188.155 root@fd0c:3964:8cda:0:6e42:b995:2026:deae \
    readlink /run/current-system
```

**Reconciliation options** (pick one, separate item):
1. Join the grind worker to the mesh (maille peer + key) — heaviest,
   but makes `kin status/deploy nv1` Just Work.
2. Teach kin a per-machine `proxyJump` (kin spec has no such field
   today; grep clean). File `../kin/backlog/feat-machine-proxyjump.md`.
3. Accept nv1 drift is human-check-only; drift-checker keeps using the
   ProxyJump workaround and reports `kin status` blind spot as
   informational.

Filed cross-repo: `../kin/backlog/feat-machine-proxyjump.md` (option 2).
