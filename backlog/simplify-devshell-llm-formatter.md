# devShell: llm-agents.formatter likely redundant post-treefmt-nix

## What

`flake.nix:140` puts `inputs.llm-agents.packages.….formatter` into
`devShell.extraPackages`. Since f7eaa19 (`bump-add-treefmt-nix-input`)
the flake exposes its own `formatter` output + `checks.fmt` via
`treefmt-nix` with `programs.nixfmt.enable = true`.

llm-agents is numtide — its `formatter` package is almost certainly a
treefmt wrapper too. If so we ship two treefmt binaries in the devshell
and the llm-agents one formats by *llm-agents'* rules, not ours.

While here: `flake.nix:66` `overlays = [ ];` is a dead line in `pkgsFor`
(empty list is the nixpkgs default).

## How

1. `nix run --inputs-from . llm-agents#formatter -- --version` and
   `nix run .#formatter -- --version` — confirm both treefmt.
2. If yes: drop line 140. `nix develop -c which treefmt` should still
   resolve (kin's devShell or our own formatter output).
3. Drop `overlays = [ ];` (line 66).
4. `nix flake check` — fmt + 3 toplevels still pass.

If llm-agents.formatter turns out to be something else (zat? a
multi-lang wrapper we actually want), close this and note in `tried/`.

## How much

−2 lines flake.nix; −1 devshell closure dep. Keeps llm-agents input
(still used for `claudebox` + `pi` in modules/home/desktop, and as
follows-anchor for blueprint/systems dedupe).

## Blockers

None. Low risk — devshell-only, no host closure change.
