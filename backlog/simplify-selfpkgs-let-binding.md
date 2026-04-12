# modules/home/desktop: 12× `inputs.self.packages.${pkgs.stdenv.hostPlatform.system}` — bind once

## What

`modules/home/desktop/default.nix` repeats the 53-char prefix
`inputs.self.packages.${pkgs.stdenv.hostPlatform.system}` **12 times**
(10 in `home.packages`, 2 for `wake-listen` — list + systemd ExecStart).
`modules/home/terminal/default.nix` has 3 more.

Prior simplifier (091403a, f0981d9) marked this *considered-kept at ×10,
no growth*. Since then `adopt-wake-listen` (325a1bc) added 2 → threshold
crossed. The repo grew 1687→2149 LoC this cycle; this is the cheapest
~500-char cut that also makes the next `adopt-*` a one-liner.

## How

Top of the existing `let` in `modules/home/desktop/default.nix`:

```nix
self' = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
```

then `self'.core`, `self'.ptt-dictate`, …, and
`ExecStart = "${self'.wake-listen}/bin/wake-listen";`.

Same pattern in `modules/home/terminal/default.nix` (3 refs:
gitbutler-cli, myvim, nvim).

Leave `machines/nv1/configuration.nix:96` and
`modules/nixos/zimbatm.nix:7` alone — single occurrence each, a binding
adds noise.

## How much

~15 lines net shrink (desktop −11, terminal −2, +2 let lines). Future
`adopt-*` items append `self'.foo` instead of the full path.

## Blockers

None. Gate: all 3 hosts eval + dry-build (touches nv1 closure only).
Run `gsnap --diff` post since modules/home/desktop is touched — should
be pixel-identical (pure refactor).
