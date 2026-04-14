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
