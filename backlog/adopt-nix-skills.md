# adopt: nix-skills via flake input (curated subset)

## What

Add `inputs.nix-skills.url = "github:assise/nix-skills"` (follows
nixpkgs). In `.claude/commands/grind.md` launch step, link:

```sh
NS=$(nix build --no-link --print-out-paths inputs.nix-skills#nix-skills-commands 2>/dev/null) \
  && ln -sf "$NS"/share/nix-skills/nix-{module,deploy,debug,hardware,secret}.md .claude/commands/ 2>/dev/null
```

Subset: `nix-module nix-deploy nix-debug nix-hardware nix-secret` —
home is a fleet repo (kin.nix module config, deploy workflows,
nv1/web2/relay1 hardware profiles, age secrets).

Gitignore `.claude/commands/nix-*.md`.

## Why

Grind agents re-derive Nix idioms from existing code each round; the
nix-skills knowledge base has them canonically. Locked input = updates
via bumper + fastCheck, not a mutable glob.

## How much

~0.2r.

## Blockers

None — `packages.nix-skills-commands` shipped nix-skills@47149f2.

## Falsifies

If the adopter/reconcile specialists with `/nix-debug` available
diagnose a deploy failure faster than without (compare backlog/tried/
abandon-reason quality before/after).
