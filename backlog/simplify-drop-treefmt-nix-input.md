# Drop `treefmt-nix` flake input — zero references

**What:** Remove `inputs.treefmt-nix` from `flake.nix:15` and relock.

**Why:** `grep -rn treefmt . --include='*.nix'` → only the input
declaration itself. `formatter` output uses `pkgs.nixfmt-rfc-style`
directly (flake.nix:63), not treefmt. Dead input = lock churn + eval
time for nothing.

**How much:** Delete one line, `nix flake lock`. Gate passes (nothing
consumes it). ~2 min.

**Blockers:** none.
