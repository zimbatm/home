# Drop hosts/no1 + hosts/p1 — fleet already shrunk, dirs left behind

**What:** Delete `hosts/no1/` and `hosts/p1/` plus everything only they
pull in.

`6a239bb` ("Drop no1/p1 (unused); fleet is nv1/web2/relay1") removed
them from `kin.nix` but left the host dirs. `nix eval
.#nixosConfigurations --apply builtins.attrNames` → `[ "nv1" "relay1"
"web2" ]` — they're never built, never deployed, never gated.

Cascade (only-referenced-by-no1/p1, dies with them):

- `modules/nixos/nix-remote-builders.nix` — only `hosts/no1:19`
  references it, *and* via `inputs.self.nixosModules.nix-remote-builders`
  which `flake.nix` doesn't even export. Broken + dead.
- `inputs.lanzaboote` (flake.nix:11) — only `hosts/p1:11` imports it.
- `hosts/no1/hardware-configuration{,-extra}.nix`,
  `hosts/p1/hardware-configuration.nix`
- `machines -> hosts` symlink can stay (kin convention).

**Why:** ~230 LoC of dead config that the gate doesn't even check. no1
references a nonexistent flake attr so it'd fail eval if it *were*
gated. Keeps the repo at "what's actually running".

**How much:** `git rm -r hosts/no1 hosts/p1
modules/nixos/nix-remote-builders.nix`, drop `lanzaboote` line from
flake.nix inputs, `nix flake lock`. Gate: all 3 hosts still eval+build.
~10 min.

**Blockers:** none. If p1 (the thinkpad) is coming back, say so and
move this to `wontfix/` — but `6a239bb` was explicit.
