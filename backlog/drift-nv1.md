# nv1: deployed ≠ declared (repo-local drift, growing)

**What:** nv1 is running `i4yx1sbx…-nixos-system-nv1-26.05.20260409.4c1018d`
(unchanged since 82d7737); declared toplevel @ 477f681 is
`pjc5v09a…-nixos-system-nv1-26.05.20260409.4c1018d`. Same nixpkgs
(4c1018d) — drift is entirely repo-local commits not yet deployed.
relay1/web2 both match HEAD (have==want `2pr46yxn…`/`pp1zqfk6…`,
health=running, uptime ~3d).

**Why:** nv1-touching commits with explicitly deferred runtime checks
keep landing while no human has run `kin deploy nv1`. Gap is now 7
commits deep (was 4 @ cb5eaa3):

- 409ea70 — Meteor Lake NPU enable (ivpu + intel-npu-driver + openvino)
- a4dc86c — ptt-dictate GNOME `<Super>d` hotkey
- 205d703 — ask-local (llama-cpp+vulkan on Arc iGPU)
- c326db7 — nixvim.inputs.nixpkgs follows (nvim closure rebuild)
- 8a1aa5d — kin-opts wired into agentshell
- 24fbf66 — infer-queue (pueue lanes arc/npu/cpu; pueued user unit)
- 40e840f — kin bump 59dc9bda→4d49b8cd

nv1 itself is healthy (`systemctl is-system-running` → `running`, no
failed units via ProxyJump probe).

**How much:** Human runs `kin deploy nv1` from a mesh-connected
machine, then walks the deferred runtime checks: NPU device enum
(`python -c 'from openvino import Core; print(Core().available_devices)'`);
ptt-dictate `<Super>d`; ask-local ≥15tok/s; agent-eyes `peek` under
GNOME Wayland; `infer-queue add -d arc …` lane assertion; `pueue
status` shows pueued running.

**Blockers:** Human-gated deploy (CLAUDE.md). `kin deploy nv1` from
this grind worker would also fail (see structural note).

---

## Structural: `kin status nv1` blind from grind worker

`kin status nv1` here returns `health: not-on-mesh` / `have: ""`
because `machines.nv1.host = "fd0c:3964:8cda::6e42:b995:2026:deae"`
(mesh ULA only) and the grind worker is not a mesh peer. nv1 **is** up
— ProxyJump via relay1 succeeds.

**Workaround used this round:**
```sh
ssh -i ~/.ssh/kin_ed25519 -o CertificateFile=~/.ssh/kin_ed25519-cert.pub \
    -J root@95.216.188.155 root@fd0c:3964:8cda:0:6e42:b995:2026:deae \
    'readlink /run/current-system; systemctl is-system-running'
```

**Reconciliation:** `../kin/backlog/feat-machine-proxyjump.md` is
filed (kin@b02671c per 40e840f). When kin grows
`machines.<n>.proxyJump`, set `nv1.proxyJump = "relay1"` here and
drift-checker can drop the manual `-J`. Until then this workaround
stays.

(feef522 claimed a `~/.ssh/config` Host block for nv1/relay1/web2 was
added on the worker; it is not present today — only the explicit
`-i`/`-J` form works. Non-blocking; noted for whoever revisits worker
ssh setup.)
