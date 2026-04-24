# bug: `kin deploy` IETS-0022 on maille.src recurs after kin@17ca881c fix

## What

`kin deploy` on nv1 @ home`8c47c57` (cold store, kin binary from prior
deploy @ ba4514b9) still hits:

```
error[IETS-0022]: derivation: daemon reported: path '/nix/store/69v9czd4...-source' is not valid
 = note: while evaluating the option `systemd.services.kin-mesh.serviceConfig':
 = note: while evaluating definitions from `<kin:service:mesh>':
```

`69v9czd4` = `pkgs.maille.src` (fileset.toSource filtered). The fix
kin@17ca881c added `mailleSrc ? maille.inputSrc or maille.src` and
kinOverlay attaches `inputSrc` — verified present under both cppnix and
worker iets at `nixosConfigurations.nv1.pkgs.maille.inputSrc.outPath` =
`xv8n1xwp...`. Yet nv1's eval falls through to `.src`.

## Why

Third cold-store IFD escape (after cp.run-crops 2026-04-13 and
maille-caps round 1). fastCheck passes on the worker because the store
is warm; Jonas hits it on every fresh deploy.

## Hypotheses

1. **(remaining)** Old kin/iets binary in nv1's PATH (from ba4514b9
   deploy) evaluates differently — kinOverlay at ba4514b9 was
   `maille = maille.packages.<sys>.default;` WITHOUT `// { inputSrc }`
   (verified `git -C ../kin show ba4514b9:lib/default.nix`), so if the
   old `kin` CLI's eval path bundles its own lib instead of the lock's,
   `.inputSrc` is absent. evaluator.py at ba4514b9 does go via
   `default.nix` → flake-shim → lock's kin lib (checked), so the
   remaining suspect is the iets binary itself or a packaging path that
   bypasses the shim. **Ask Jonas: does `nix develop -c kin deploy`
   succeed on nv1?** If yes → bootstrap-only; file kin docs note (use
   `nix develop -c` after a kin bump until first post-bump deploy lands)
   and close. If no → the iets binary is the suspect; cross-file
   `../iets/backlog/` with the `derivation // {attr}` repro.
2. ~~mesh.nix:121's eval-scope `pkgs` ≠ `nixosConfigurations.<h>.pkgs`~~
   — **REFUTED 2026-04-23.** Static read: kin lib/default.nix:140-144
   imports nixpkgs with `overlays = [ kinOverlay ]`; that `pkgs` flows
   via lib/services.nix:24,50-51 to mesh.nix:112 `eval { pkgs, ... }` →
   :127 `maille = pkgs.maille` → maille-caps.nix:20. Same kinOverlay
   instance as machine.nix:261. Empirical: worker cold-store
   `nix develop -c iets eval --store /tmp/cold-$$ default.nix -A
   nixosConfigurations.nv1.config.systemd.services.kin-mesh.serviceConfig`
   AND `…toplevel.outPath` both succeed cleanly on the current lock
   (kin@6862388, has 17ca881c) — no IETS-0022/0025. The fix is
   effective on the eval-scope path; the failure is nv1-binary-specific.

## How much

- **Ask Jonas** (hypothesis 1, above) — only remaining confirm step.
- ~~Harden fastCheck: add a cold-store iets eval leg~~ — **DONE
  2026-04-23** (grind.config.js: lock-touched-only `if` clause; passes
  on current lock, propagates IETS-0022/0025 if a future bump
  reintroduces cold-store IFD).

## Workarounds

`nix develop -c kin deploy` or `kin deploy --evaluator nix`.
