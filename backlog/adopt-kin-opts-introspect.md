# adopt: fleet-local option introspection for agents

## What

[MCP-NixOS] gives AI assistants accurate *generic* nixpkgs option/package
lookup via MCP. Our angle on the same problem: a `kin-opts` CLI that
answers from *this fleet's evaluated module system*, not upstream docs —

```sh
kin-opts nv1 services.openssh        # merged value + definition locations
kin-opts nv1 --search 'ydotool'      # option paths matching pattern
kin-opts --hosts                     # nv1 web2 relay1
```

Thin wrapper over `nix eval .#nixosConfigurations.<host>.options.<path>`
with `{value, defined-in, type, description}` JSON output, plus a
`~/.claude/skills/kin-opts/SKILL.md` telling agents to query before
writing option paths.

## Why

Recurring grind failure mode: agent guesses a NixOS option path, eval
fails, round burns. MCP-NixOS solves this for stock nixpkgs, but home's
option surface is kin + maille + local modules — generic lookup misses
the parts that actually bite us. Querying the live evalled config also
shows *where a value came from* (which `configuration.nix` set it),
which generic docs can't.

## How much

~0.5r. `packages/kin-opts/default.nix` (writeShellApplication around
`nix eval --json` + `jq`), `SKILL.md`, wire into agentshell. No new
flake inputs.

## Falsifies

- Do grind eval-error rounds drop when agents can query the real option
  tree instead of guessing? (Count `error: The option .* does not exist`
  in gate logs before/after.)
- Should `kin` itself grow an `opts` subcommand? If this proves useful,
  file `../kin/backlog/feat-opts-subcommand.md` — the introspection
  belongs upstream, not in home.

## Blockers

None. `nix eval .#nixosConfigurations.<h>.options` already works; this
is packaging + skill glue.

[MCP-NixOS]: https://github.com/utensils/mcp-nixos
