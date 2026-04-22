# bump: nixpkgs 4bd9165a → b12141ef (nixos-unstable)

**What:** `nix flake update nixpkgs` (4bd9165a, 2026-04-14 → upstream
HEAD b12141ef as of 2026-04-22). 7d18h stale.

**Why:** Highest-priority external (bumper cadence: nixpkgs > kin >
iets). Last nixpkgs bump fa68a27 (4c1018d→4bd9165, 2026-04-17) moved
all 3 host closures; expect same here.

**How much:** One commit. `nix flake update nixpkgs`, then gate (all 3
hosts eval + dry-build). Watch for: gitbutler-cli cargoPatches (fa68a27
needed a fix last time), packages/nvim eval, llm-agents pkgs that moved
to nixpkgs @ c9491bc.

**Blockers:** None. Closure-affecting all 3 → appends to
ops-deploy-{nv1,relay1-web2}.
