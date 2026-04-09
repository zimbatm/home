# CLAUDE.md still references deleted flake-shim.nix

## What

`CLAUDE.md` "What to edit" section says:

> `flake-shim.nix` — the non-flake entrypoint for `iets eval`. Tracks `flake.lock` via `fetchTarball`.

But `flake-shim.nix` was removed in 5d660ee ("simplify: drop dead lib/ + local
flake-shim.nix"). The non-flake entrypoint is now `default.nix`, which
bootstraps kin's `lib/flake-shim.nix` from `flake.lock` (README.md is already
correct on this).

## How much

One-line doc swap in CLAUDE.md:

```diff
-- `flake-shim.nix` — the non-flake entrypoint for `iets eval`. Tracks `flake.lock` via `fetchTarball`.
+- `default.nix` — the non-flake entrypoint for `iets eval`. Bootstraps kin's flake-shim from `flake.lock`.
```

Zero eval surface. No gate impact.

## Why bother

CLAUDE.md is the agent-facing map. A stale pointer to a deleted file sends
the next session looking for something that doesn't exist.

## Blockers

None. Trivial doc fix; implementer can land it alongside any other change.

---

## Simplifier sweep r260409-2 — otherwise CLEAN

Confirming 24a9c4c's findings still hold post-e10abeb (dead-host retirement):

- **modules/**: all 9 nixosModules imported (common/perlless/zimbatm via
  relative path from common.nix+desktop.nix; rest via `inputs.self.nixosModules.*`).
  Both homeModules imported (desktop→nv1, terminal←desktop).
- **inputs**: all 9 referenced (iets→devshell only; nixvim→packages/nvim only;
  rest multi-ref).
- **commented-out**: no zerotier/tailscale. kin.nix:27 attest is needs-human
  w/ backlog ref (keep). perlless.nix forbiddenDependenciesRegex is documented
  (keep).
- **per-host dup**: none liftable (relay1=5L minimal, web2=14L, nv1 unique
  hardware/VFIO).
- **packages**: svg-term+alpacasay already backlogged needs-human; core/myvim/nvim
  all consumed.
- **machines/**: proper symlink (mode 120000), not a dup dir.

Not filed (judgment call): `users.migration-test` + `keys/users/migration-test.{key,pub}`
— 1 kin.nix line + 2 key files, plausibly live kin test fixture; not worth a
needs-human round-trip for ~3 LoC.
