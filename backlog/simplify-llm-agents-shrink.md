# Shrink `llm-agents` dependency — zat upstreamed, audit the rest

zat landed in nixpkgs at `8d2c5bc26aa3` (2026-04). home doesn't pull zat
directly, but it's the reason iets has an `llm-agents` input — and home
threads `inputs.llm-agents.follows = "llm-agents"` into iets at flake.nix:7.

## Immediate (once iets drops its input)

- `flake.nix:7` — remove `inputs.llm-agents.follows = "llm-agents"` from the
  iets input line. iets will no longer have that input to follow.

## Remaining direct consumers (blocking full removal)

| pkg | where | nixpkgs? | action |
|---|---|---|---|
| `formatter` | flake.nix:74 | no | keep — llm-agents-specific treefmt wrapper |
| `crush` | desktop:11,16 (overrideAttrs goModules) | **yes** 0.55.0 | swap to `pkgs.crush`; check if the GOPROXY override (comment @ :8) is still needed upstream |
| `claude-code` | desktop:75 | **yes** 2.1.92 | swap to `pkgs.claude-code` |
| `claudebox` | desktop:76 | no | keep |
| `codex` | desktop:77 | **yes** 0.118.0 | swap to `pkgs.codex` |
| `opencode` | desktop:79 | **yes** 1.4.3 | swap to `pkgs.opencode` |
| `pi` | desktop:80 | no | keep |

4/7 can move to nixpkgs now. After: llm-agents stays for `formatter` +
`claudebox` + `pi` only. Full drop blocked on those three upstreaming.

## Net

After swap: -4 packages from llm-agents, no input change yet. Lock dedup
(blueprint_2 via llm-agents+nix-skills) unchanged until full removal.

## Gate

`nix eval .#nixosConfigurations --apply builtins.attrNames --accept-flake-config`;
`home-manager build` on nv1 if reachable.
