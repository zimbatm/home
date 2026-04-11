# adopt: nixq — evaluated-fleet introspection CLI for agents

## What

A tiny `nixq` CLI (shell wrapper over `nix eval`) that answers, against
*this flake's evaluated config*, the questions agents currently grep for:

```sh
nixq opt nv1 services.openssh.settings   # merged value + definition files:lines
nixq why nv1 ydotool                     # which module enabled programs.ydotool
nixq pkgs nv1 | grep openvino            # flat list of systemPackages closure
nixq diff nv1 web2 networking            # option-tree diff between hosts
```

Ship as `packages/nixq/` + a `.claude/skills/nixq/SKILL.md` so the agent
reaches for it instead of `grep -rn` across modules/.

## Why (our angle)

[utensils/mcp-nixos] gives agents an MCP server for *generic* nixpkgs +
home-manager option docs. Useful, but it answers "what does this option
mean upstream" — not "what is this option's value *on nv1 right now* and
which of our 9 modules set it". The latter is what drift/simplifier
specialists actually need; today they Read 4-5 module files and
mentally merge.

We already pay the eval cost every gate run. `nixq` is the same
`.#nixosConfigurations.<host>.config` / `.options` attrpath the gate
walks, just exposed as a query tool. No MCP daemon, no new flake input —
pure `nix eval --json` + `jq` + the `options.*.definitionsWithLocations`
attr NixOS already computes.

## How much

~60 lines of bash in `packages/nixq/nixq.sh`, `writeShellApplication`
wrapper, one SKILL.md. Add to `agentshell` buildEnv. Half a round.

## Falsifies

"Agents need full-module Reads to reason about merged NixOS config." If
nixq cuts simplifier-round Read-tool volume on modules/ by a visible
margin, the introspect-don't-grep pattern earns a place in assise. If
agents ignore it and keep grepping, the SKILL.md framing is wrong or the
eval latency makes it unusable — either way, a real signal.

## Blockers

None. `nix eval .#nixosConfigurations.nv1.options.<path>.definitionsWithLocations`
works today; verified shape exists since nixpkgs 23.11.

[utensils/mcp-nixos]: https://github.com/utensils/mcp-nixos
