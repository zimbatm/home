# bug: bumper-reported toplevel hashes ≠ drift flake-eval bisect

## What

Drift @ 8f7f2db flagged: bumper commit 1d32ccb reports
`nv1 l05iw1sz→jjd1z1z3, web2 qzc3adw1→3ybvppf2`, but drift's
flake-eval bisect of the same commit gives `nv1→av9v7mmc,
web2→z78zi5y7`. The pre-bump hashes also disagree
(l05iw1sz vs b5cn8gij at the parent).

Drift annotated "⚠ likely iets-eval divergence" but did not
cross-file — root cause unconfirmed.

## Why

If bumper computes via `iets eval` (fastCheck step) and drift via
`nix eval .#…toplevel.outPath`, and they disagree on the same
locked tree, that's either:

- an iets correctness bug (cross-file `../iets/backlog/` —
  possibly an instance of `correctness-compat-no-iets-extensions.md`
  if nixpkgs feature-detects via `builtins ? X`), or
- a home tooling skew (bumper using PATH-iets at a version ≠
  flake.lock iets; or computing drvPath vs outPath; or dirty-tree).

Either way the bumper's commit-message hashes are unreliable for
bisect, which undermines drift's per-commit closure attribution.

## Repro

```sh
git checkout 1d32ccb
nix eval --raw .#nixosConfigurations.nv1.config.system.build.toplevel.outPath | cut -c12-19
# expect av9v7mmc per drift; if jjd1z1z3 → drift was wrong, close this
nix develop -c iets eval -A nixosConfigurations.nv1.config.system.build.toplevel.outPath | cut -c12-19
# if differs from nix eval → iets divergence, cross-file ../iets/
# if matches nix eval → bumper used a different path; grep grind bumper for hash source
```

(META @ 8f7f2db tried repro; `iets` not in PATH and agentshell
build skipped — needs `nix develop` shell.)

## How much

~0.2 round. One checkout, two evals, compare. Then either
cross-file or fix bumper's hash-reporting.
