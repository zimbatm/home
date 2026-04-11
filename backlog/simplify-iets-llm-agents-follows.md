# simplify: iets.inputs.llm-agents.follows

**what**: Add `inputs.llm-agents.follows = "llm-agents"` to the `iets` input in flake.nix.

**why**: iets bump 28809de7→11d1e715 added `llm-agents` as a transitive dep of iets. We already have `llm-agents` as a direct top-level input. Without a follows, the lock grew 26→33 nodes (blueprint_4, bun2nix_2, flake-parts_3, llm-agents_2, systems_5, treefmt-nix_2, import-tree_2 chain). Same pattern as the existing `simplify-kin-nix-skills-follows` item.

**how-much**: One-line edit in flake.nix line 7, then `nix flake lock`. Expect −7 lock nodes.

```nix
iets = { url = "git+ssh://git@github.com/jonasc-ant/iets"; inputs.nixpkgs.follows = "nixpkgs"; inputs.llm-agents.follows = "llm-agents"; };
```

**blockers**: none. Gate as usual (nv1/relay1/web2 eval+dry-build).
