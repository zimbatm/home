# feat: swap formatter nixfmt → `iets fmt`

iets fmt is at 256/256 nixpkgs-lib byte-equality with nixfmt-rfc-style
and ~30× faster. Swap this repo's formatter.

## Scope

- Bump iets input/pin ≥ `050b079a9` (post-5g: antiquote-comment +
  or-indent + blank-before-value parity fixes; 1986/2000 byte-eq on
  pkgs/by-name; collection-swap residuals closed).
- `formatter.${system}` (or treefmt `programs.nixfmt.enable`) →
  `iets fmt` wrapper. Keep `checks.fmt` as the idempotence guard.
- One reformat commit (`nix fmt` over the tree). If the diff is
  large, that's the swap landing — commit it; the byte-eq claim is
  about *new* code matching nixfmt going forward, not zero churn on
  the existing tree.
- **Comment-move gate**: if the reformat diff relocates any `# ` comment
  lines (reattaches to a different binding), stop — pick one example and
  route to needs-human/. Do not auto-commit comment moves. (Prior swap
  reverted on this class; fixed iets@050b079a9 but verify per-tree.)
- Divergence classes that look like iets bugs (not just style
  deltas): file back to `../iets/backlog/` with a 5-line minimal
  repro. Don't block the swap on them.

## Falsifier

`nix fmt && git diff --quiet` is idempotent (second run = no-op);
`checks.fmt` green; `nix fmt` wall-clock < prior nixfmt run on the
same tree (timing in commit msg).
