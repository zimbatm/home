# drift-relay1

## what
relay1 deployed closure ≠ declared (origin/main@4afab0d).

`kin --evaluator nix status --json` @ 2026-04-10T22:52Z:
```
have: /nix/store/yiwx1dyzgjlk1bwr00i6axdc20ynva97-nixos-system-relay1-26.05.20260409.4c1018d
want: /nix/store/sw8pg8jqg9ni044za4j8kq6qpn6w7ixd-nixos-system-relay1-26.05.20260409.4c1018d
health: running   secrets: active   failed: -   uptime: 2d10h57m
```
Last deploy: system-6-link @ Apr 10 20:41 (yiwx1dyz).

## why
aa336d3 (kin 031dcf5→4dac27e, +152 commits; transitive maille
95cfbfe→3d88172) landed after last deploy. Same nixpkgs (4c1018d) so
drift is purely the kin/maille bump.

Re-checked at 4afab0d: fbe5687 (kin 4dac27e→d28f09f, +14) did NOT move
the want closure — those commits are CLI/gen-layer only (files.env
shorthand, svcGen defaults, cli-gen-guard). Diff below still current.

`nix store diff-closures` have→want:
```
maille: 1.3 MiB
plain.age: ε → ∅
```
Deployed has a `plain.age` derivation that declared drops — kin bump
removed it. No deployed-only config state detected (no failed units,
secrets active).

## reconcile
Just deploy: `kin deploy relay1` (human-gated). Low risk — health
green, diff is the reviewed kin bump.

## blockers
None. ops-* (needs human to run deploy).

## note
`kin status` default (iets) evaluator currently fails IETS-0018 on
nv1 — use `--evaluator nix`. Cross-filed: ../iets/backlog/bug-nixos-systemd-unit-escape-divergence.md
