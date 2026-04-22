# bump: nixos-hardware c775c277 → 72674a6b

**What:** `nix flake update nixos-hardware` (c775c277, 2026-04-06 →
upstream HEAD 72674a6b as of 2026-04-22). 15d stale.

**Why:** Upstream moved since last drift (was upstream-HEAD==locked @
24783dc, no longer). nv1 imports a nixos-hardware profile
(machines/nv1/); relay1/web2 likely don't — expect nv1-only closure
move.

**How much:** One commit. `nix flake update nixos-hardware`, gate.
Low-risk: hardware profiles are mostly kernel-param/firmware-enable
toggles.

**Blockers:** None.
