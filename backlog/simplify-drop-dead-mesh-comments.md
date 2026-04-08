# Drop commented-out zerotier/tailscale config

**What:** `modules/nixos/common.nix:51-62` has commented-out
`zerotierone` + `tailscale` config. A1/A2 shipped maille as the only
mesh; these are dead.

**Why:** kin.nix declares `services.mesh.member = [ "all" ]` and nothing
else; the comments document a state that no longer exists. ADR-0013:
don't keep "in case."

**How much:** delete ~12 lines.

**Blockers:** none.

**Falsifies:** nothing — pure cleanup.
