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

1. ~~Old kin/iets binary in nv1's PATH (from ba4514b9 deploy) evaluates
   differently~~ — **REFUTED on worker 2026-04-24.** Built both exact
   binaries and ran the failing eval cold:
   - kin@ba4514b9 (`nix build /tmp/kin-ba4514b9#kin`): `Iets.eval_attr`
     goes via `default.nix → lock's flake-shim@6862388 → kinOverlay with
     inputSrc` — confirmed by running ba4514b9's `evaluator.py` directly
     against this repo (`--store auto`, warm): kinManifest + nv1
     toplevel both OK.
   - iets@14e50511 (`nix build /tmp/iets-14e50511#iets` — nv1's deployed
     iets per home@ecada5bc lock): cold-store (`--store $(mktemp -d)`)
     `-A nixosConfigurations.nv1.config.systemd.services.kin-mesh
     .serviceConfig` → OK; `-A …pkgs.maille.inputSrc.outPath` →
     `xv8n1xwp` (fix present).
   - ba4514b9's argv shape (`--impure --allowed-path <root>
     --allowed-path /nix/store`) cold via `-A` form → OK on the failing
     attr + toplevel.drvPath.
   Neither old binary bypasses the lock; `inputSrc` is reachable under
   both. The Nix expression is deterministic — `maille.inputSrc or
   maille.src` resolves to `inputSrc` regardless of store state. The
   `69v9czd4` reference must come from `${pkgs.maille}` derivation
   instantiation (ExecStart string-interp → outPath → .drv inputSrcs
   include fileset.toSource'd `.src`), which is plain addToStore not
   IFD. **Untestable on worker:** old-iets `--store auto` (daemon) with
   `69v9czd4` absent — would need destructive GC of a shared store path.
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

- ~~Harden fastCheck: add a cold-store iets eval leg~~ — **DONE
  2026-04-23** (grind.config.js: lock-touched-only `if` clause; passes
  on current lock, propagates IETS-0022/0025 if a future bump
  reintroduces cold-store IFD).
- All worker-side falsification exhausted (both old binaries pass cold).
  **needs-human** — see Ask below.

## Ask

On nv1, at home@8c47c57 (or current main), with the **deployed** kin/
iets (NOT `nix develop`):

```sh
kin deploy nv1 --evaluator iets   # or bare `kin deploy` if iets is default
```

Does it still hit IETS-0022 on `69v9czd4`? Then:

```sh
nix develop -c kin deploy nv1
```

**If `nix develop -c` succeeds** → bootstrap-only; the deployed
iets@14e50511's `--store auto` daemon path mishandles
filterSource→addToStore for `pkgs.maille.src` as a derivation inputSrc
(worker can't repro: would need GC of `69v9czd4` from shared store).
Action: cross-file `../iets/backlog/bug-auto-store-filtersource-
inputsrc.md` with `iets@14e50511 --store auto` + a missing
fileset.toSource path repro; add a one-line note to
`../kin/docs/howto/` ("after `nix flake update kin`, first deploy via
`nix develop -c kin deploy` until the new iets lands"). Close this.

**If `nix develop -c` ALSO fails** → not the binaries. Capture: (a) is
the working tree clean (`git status -s`)? (b) does
`nix eval .#nixosConfigurations.nv1.pkgs.maille.inputSrc.outPath`
print `xv8n1xwp…` or fail? (c) `iets eval --store auto -E
'(import ./default.nix).nixosConfigurations.nv1.pkgs.maille ? inputSrc'`
→ true or false? If (c) is false the lock's kinOverlay isn't reaching
nv1's eval — inspect `default.nix` / a stale `flake.lock` / NIX_PATH
override on nv1.

## Workarounds

`nix develop -c kin deploy` or `kin deploy --evaluator nix`.
