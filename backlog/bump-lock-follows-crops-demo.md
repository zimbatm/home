# bump: follows-dedupe crops-demo transitives — lock 33→~25 nodes

## What

`flake.lock` grew 19→33 nodes since 6f87665 (last dedupe). The +14 is
almost entirely the `crops-demo` input added at d4e1fea: it brings 6
direct transitives (blueprint, disko, messaging-daemon, noctalia-plugins,
tng, voxterm-src) and `tng` brings 5 more (blueprint_2, crane, disko_2,
srvos, treefmt-nix). Current dups (`jq` over lock):

```
3× systems   3× blueprint   2× treefmt-nix   2× srvos   2× flake-parts   2× disko
```

Add `follows` lines under `inputs.crops-demo` in `flake.nix`, relock,
gate on 3-host eval+dry-build.

## Why

Lock size is the canary for "too many evaluators in play". 33 nodes
re-crosses the threshold that prompted the original dedupe. Each dup
node is a separate fetch + a separate eval of the same code at a
different rev; `srvos` and `treefmt-nix` in particular are already
direct inputs here — crops-demo→tng pulling its own copies is pure
waste.

## How much

~6 follows lines in flake.nix + `nix flake lock`. Candidates (verified
against current lock graph):

```nix
crops-demo.inputs.blueprint.follows = "llm-agents/blueprint";
crops-demo.inputs.tng.inputs.blueprint.follows = "llm-agents/blueprint";
crops-demo.inputs.tng.inputs.disko.follows = "crops-demo/disko";
crops-demo.inputs.tng.inputs.srvos.follows = "srvos";
crops-demo.inputs.tng.inputs.treefmt-nix.follows = "treefmt-nix";
nixvim.inputs.flake-parts.follows = "llm-agents/flake-parts";
```

Est -8 nodes (each blueprint drags a `systems`). messaging-daemon /
noctalia-plugins / voxterm-src / crane have no root-side peer to
follow — leave them.

## Blockers

None. This is **bumper** territory per `tried/simplify-lock-follows-dedupe.md`
— touching `flake.lock` is denylisted for simplifier; 6f87665 shows the
precedent (bumper landed the prior dedupe under a `bump:` prefix).
Gate: `kin gen --check` + 3-host eval+dry-build after relock; crops-demo
modules (`vfio-host`, `cp.*` packages) must still resolve.
