# harness: fastCheck → nix flake check

## What

Now that `checks.${system}` exists (fmt + 3 host toplevels), switch
`.claude/grind.config.js` fastCheck from the hand-rolled
eval+per-host-dry-build loop to `nix flake check --no-build` (or full
`nix flake check` if build cost is acceptable).

## Why

Single canonical gate. Current fastCheck and `checks.${system}` now
duplicate the host list.

## How much

~3 lines in grind.config.js. Verify `nix flake check` runtime is
comparable to current fastCheck before swapping.

## Blockers

None — bump-add-treefmt-nix-input landed.
