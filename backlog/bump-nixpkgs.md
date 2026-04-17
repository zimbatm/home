# bump: nixpkgs (8d stale, nixos-unstable)

## What

```sh
nix flake update nixpkgs
kin gen --check && nix flake check  # gate: all 3 eval+dry-build
```

## Why

drift @ ead5fd4: `flake.lock` nixpkgs lastModified=1775710090
(2026-04-09, rev 4c1018da) — **8.2d** vs 7d threshold. Follows
`nixos-unstable`; channel has advanced since (was 6d at feac33c, now
crossed threshold). All 3 host toplevels currently pin
`26.05.20260409.4c1018d`.

Other externals checked at ead5fd4:
- nixos-hardware 10.8d but `git ls-remote` upstream HEAD == locked
  c775c277 (re-verified, no commits upstream) — no bump available
- treefmt-nix 9.1d but upstream HEAD == locked 790751ff (re-verified)
  — no bump available
- home-manager 2.7d, srvos 4.3d, nix-index-database 5.2d, nixvim 3.4d
  — all ≤7d

## How much

One `nix flake update nixpkgs` + full eval. nixos-unstable bumps are
the largest blast radius (all 3 hosts move); expect rebuild of most
closure. Bumper's oldest-first priority puts this at the top.

## Blockers

None. If eval breaks: pin back, file the breakage upstream or in
backlog/tried/.
