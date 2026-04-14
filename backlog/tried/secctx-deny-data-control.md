# secctx-deny-data-control

## What

The ADR-0018 shell's `wp_security_context_v1` deny-list must include
`zwlr_data_control_manager_v1` and `ext_data_control_v1` alongside the
existing four (`zwlr_layer_shell_v1`, `zwlr_screencopy_manager_v1`,
`zwp_virtual_keyboard_manager_v1`, `zwp_input_method_v2`). tng now
encodes a `data-control` opt-in into the secctx `instance_id` suffix
(see `tng/crates/tng-core/src/manifest.rs:WaylandProtocol::DataControl`),
so the shell-side contract is: deny by default, re-expose iff
`instance_id` carries `+…,data-control`.

## Why

`zwlr_data_control_manager_v1` grants *unfocused* clipboard read/write
— the `wl-paste --watch` back door. ADR-0017 §Consequences guarantees
clipboard is "mediated, not ambient"; that holds only if the secctx
deny-list strips data-control from sandboxed clients. Without this a
tng `kind = "app"` workload can poll the clipboard despite never
declaring `portals = ["clipboard"]`, bypassing the broker prompt.

## How much

S. Wherever the shell's secctx handler enumerates privileged globals
to filter from `wl_registry` for `sandbox_engine="tng"` clients, add
both data-control interface names. Re-expose when the parsed
`instance_id` proto list contains `data-control`. No new dep.

## Blockers

None — tng side landed (cap-wayland-data-control). If no secctx
handler exists yet in this repo, fold this into the item that adds it.

## Tried

**Outcome:** closed — misfiled cross-dispatch, no home code path.

**What happened:** Verified `grep -rn
'security_context|secctx|sandbox_engine|wl_registry' --include='*.nix'`
over home → zero hits. `modules/nixos/niri.nix` is pure config.kdl on
nixpkgs' `programs.niri.enable` (no overlay, no patch);
`modules/home/desktop/crops.nix` only consumes crops-demo packages;
crops-demo itself has no secctx code. home owns no compositor and no
secctx-handler.

**Why no home change:** ADR-0018
(`../meta/adr/0018-shell-is-the-trust-boundary.md`) names the shell as
`../tng/crates/tng-shell`, and
`../meta/backlog/feat-shell-broker-prompt-stub.md` says it is "Not a
compositor — runs under any wlroots compositor". So the secctx
deny-list enforcement is compositor-internal (upstream niri/wlroots),
not assise-owned today. The Blockers clause says "fold this into the
item that adds it" — no such item exists in home and none is planned
(home consumes nixpkgs niri, doesn't patch it).

**Already covered elsewhere:**
- tng manifest side (`WaylandProtocol::DataControl` enum +
  `instance_id` suffix): `../tng/backlog/cap-wayland-data-control.md`
- meta ADR-0018 §Status already records the 5th global post-acceptance
  (chronicle 2026-04-12).

No further cross-file needed.

**Don't retry as-is:** any re-file of this into home will find the same
zero code paths. If/when home grows a niri overlay or a tng-shell
service that owns the secctx deny-list, that item carries the
data-control entry directly — don't split it back out.
