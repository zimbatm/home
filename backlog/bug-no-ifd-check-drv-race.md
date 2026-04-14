# bug: checks.no-ifd transient "path .drv is not valid" under flake check --no-build

**what** — `checks.x86_64-linux.no-ifd` (flake.nix:181) is
`writeText "no-ifd" (concatLines [... "${toplevel.drvPath}" ...])`. Under
`nix flake check --no-build --no-allow-import-from-derivation` it can fail
with `error: path '/nix/store/….drv' is not valid` when the referenced
host toplevel .drv hasn't been instantiated yet at the point nix resolves
the writeText derivation's input context. Re-running passes (drv now on
disk from the prior partial eval). Hit during bumper round a603e7c on the
home-manager 8a423e4→3c7524c bump — first run red, direct
`nix eval .#nixosConfigurations.nv1...drvPath` green, immediate re-run
of flake check green.

**why** — false-red gate wastes a bumper phase (revert→investigate→retry)
and will recur on any bump that changes a host toplevel hash. The no-ifd
check's *intent* (force IFD to surface under the CLI flag) is sound; the
*mechanism* (writeText with drvPath context) is the fragile bit.

**how-much** — small. Options:
- Replace writeText with `runCommand` that `echo`s
  `builtins.unsafeDiscardStringContext drvPath` after a `builtins.seq`
  on the real drvPath — forces instantiation, drops the context dep.
- Or: drop no-ifd entirely since `checks.{nv1,relay1,web2}` already eval
  toplevel under `--no-allow-import-from-derivation` — no-ifd is
  redundant with the per-host checks (verify this is true first; the
  comment at flake.nix:177 cites the dacd1ec crops→tng→crane regression
  as motivation, check whether per-host checks alone would have caught it).
- Or: add `--option eval-cache false` to fastCheck part 1 (heavier).

**blockers** — none. Pick after confirming redundancy with per-host checks.
