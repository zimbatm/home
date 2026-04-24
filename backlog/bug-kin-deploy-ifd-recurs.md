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

## Hypotheses (unconfirmed)

1. Old kin/iets binary in nv1's PATH (from ba4514b9 deploy) evaluates
   `derivation // { inputSrc }` differently than current iets — `.inputSrc`
   lost. `nix develop -c kin deploy` (uses lock's kin/iets) would confirm.
2. mesh.nix:121's eval-scope `pkgs` ≠ `nixosConfigurations.<h>.pkgs` —
   kinOverlay applied to the latter (machine.nix:261) but maybe not the
   former under the shim path. Worker probe of nixosConfigurations.pkgs
   shows inputSrc present, but the eval-scope pkgs (lib/default.nix:146)
   wasn't directly probeable from outside mkFleet.

## How much

- Confirm: ask Jonas whether `nix develop -c kin deploy` works. If yes →
  bootstrap-only, file kin docs note. If no → kin fix incomplete,
  re-cross-file with mesh.nix:121 eval-scope-pkgs trace.
- Harden fastCheck: add a cold-store iets eval leg so this class can't
  pass the gate. `iets eval --store /tmp/cold-$$` on one host's toplevel
  (cold-store hit IETS-0025 on `w5ggxmq5` — different path, so it catches
  *something*). ~+40s cold per round; could gate on flake.lock-touched.

## Workarounds

`nix develop -c kin deploy` or `kin deploy --evaluator nix`.
