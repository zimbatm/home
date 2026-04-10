# drift-web2

## what
web2 deployed closure ≠ declared (origin/main@3018848).

`kin --evaluator nix status --json` @ 2026-04-10T22:25Z:
```
have: /nix/store/x7w6wv2zj8asmn0ig49nzjka0h44mi3q-nixos-system-web2-26.05.20260409.4c1018d
want: /nix/store/qn03583jxm4j2fbb1ngc2x28p6yh7inw-nixos-system-web2-26.05.20260409.4c1018d
health: running   secrets: active   failed: -   uptime: 2d13h20m
```

## why
aa336d3 (kin 031dcf5→4dac27e, +152; transitive maille 95cfbfe→3d88172)
landed after last deploy. Same nixpkgs (4c1018d).

`nix store diff-closures` have→want:
```
maille: 1.3 MiB
plain.age: ε → ∅
```

## reconcile
Just deploy: `kin deploy web2` (human-gated). Low risk — health
green, no failed units.

## blockers
None. ops-* (needs human to run deploy).
