# flake.nix: kin.inputs.nix-skills.follows — dedupe lock

## What

`flake.lock` carries two `nix-skills` nodes at the **same rev**
(`03074fc5`): `nix-skills` (kin's) and `nix-skills_2` (root's). kin
adopted nix-skills as a direct input at the 98ac9b0 bump
(16a17db→f4433c1); home already had it.

home's `kin` input already follows `nixpkgs` and `iets` (flake.nix:6)
but not `nix-skills` — add it:

```nix
kin = { url = "git+ssh://git@github.com/assise/kin"; inputs.nixpkgs.follows = "nixpkgs"; inputs.iets.follows = "iets"; inputs.nix-skills.follows = "nix-skills"; };
```

Then `nix flake lock` to drop the duplicate node + its transitive
`blueprint` node (currently `blueprint.nixpkgs ->
["kin","nix-skills","nixpkgs"]`).

## Why

Consistency with the existing `nixpkgs`/`iets` follows on the same
line; one fewer pin for bumper to drift on; lock shrinks ~2 nodes/~40
lines (26→~24 nodes, 523→~480 LoC).

Do **not** drop home's `nix-skills` input outright —
`.claude/commands/grind.md:19` still builds `.#nix-skills-commands`,
and grind.md is denylisted (see `backlog/tried/adopt-nix-skills.md`).
The follows is the safe scope.

## How much

+1 token flake.nix:6. `nix flake lock` rewrites flake.lock. No eval
impact (same rev today; follows just prevents future divergence).

## Gate

```sh
nix flake lock
jq -r '.nodes | keys[] | select(test("nix-skills"))' flake.lock   # expect 1 line
kin gen --check
for h in nv1 web2 relay1; do nix build --dry-run .#nixosConfigurations.$h.config.system.build.toplevel; done
```

## Blockers

None. flake.nix one-word edit + relock.

---

## Sweep otherwise clean (re-audit since 33d4860)

- modules: 9/9 nixosModules + 2/2 homeModules + activitywatch.nix all
  reachable (nv1→desktop→common→{perlless,zimbatm}; web2→common;
  desktop→{ubuntu-light,pin-nixpkgs}; hm desktop→{../terminal,
  ./activitywatch})
- inputs: 10/10 referenced (nixvim→packages/nvim;
  nix-skills→flake.nix:48+grind.md:19; rest unchanged from 33d4860)
- packages: 5/5 consumed (core+ptt-dictate→hm/desktop;
  myvim+nvim+gitbutler-cli→hm/terminal; myvim also→zimbatm.nix)
- no zerotier/tailscale leftovers (grep -i: 0 hits)
- per-host dup: `wheelNeedsPassword=false` web2+relay1 unchanged —
  still wontfix (relay1 intentionally minimal-no-common, lifting=+file)
- services/ dir: gone (2a6ea95 dropped attest.nix; no orphan dir)
- 1100 LoC (was 1157 at 33d4860; −57 from attest.nix drop +
  pin-nixpkgs shrink + stateVersion lift, +37 ptt-dictate)
