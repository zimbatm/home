# adopt: niri-session — Niri alongside GNOME via GDM picker (nixpkgs-only)

## What

Enable Niri as a *second* login session on nv1 from nixpkgs alone,
leaving GNOME untouched. **No new flake input** — crib config.kdl
structure from `/root/src/crops-demo/nix/desktop.nix:164` at authoring
time, don't depend on it.

- New `modules/nixos/niri.nix`:
  ```nix
  { pkgs, ... }: {
    programs.niri.enable = true;
    environment.systemPackages = with pkgs; [ waybar foot fuzzel ];
    environment.etc."xdg/niri/config.kdl".text = ''…'';  # ours
  }
  ```
- `flake.nix` nixosModules: register `niri = ./modules/nixos/niri.nix` (ADR-0006).
- `machines/nv1/configuration.nix`: `imports += [ inputs.self.nixosModules.niri ]`.

GDM (already enabled via `gnome.nix`) picks up the niri wayland-session
file automatically — gear icon at login switches between GNOME and Niri.

The `config.kdl` is ours: read crops-demo's as reference, drop the
`crops`-user paths, messaging-daemon spawns, auto-login, and
noctalia-shell (not in nixpkgs — use waybar alone, or skip the bar
entirely for v1). Keep keybinds + foot terminal so it's usable day-one.

## Why (seed → our angle)

**Seed:** crops-demo ships Niri as its showcase compositor. nv1 is the
reference vfio host — the daily driver should be able to run the demo
desktop natively, not just host its VM.

**Our angle:** run both via GDM session picker (one-click fallback) +
generation menu (one-reboot fallback). Write our own minimal config.kdl
rather than importing crops-demo's module — theirs assumes a `crops`
user, greetd (conflicts with GDM), and demo-specific spawns.

**Re-scope note:** original spec added crops-demo as a flake input,
which hit the flake.lock denylist (tried/ r14). The input was never
actually consumed by the module — config.kdl was always
authored-by-reading. Dropping the input loses nothing.

## Falsifies

- **GDM↔Niri coexist**: does `programs.niri.enable` cleanly add a
  session entry under GDM without conflicting portal/dbus config?
  Check `nix eval .#nixosConfigurations.nv1.config.services.displayManager.sessionPackages`.
- **Minimal config.kdl viable**: foot + fuzzel + waybar enough for a
  usable session, or does niri need a full bar/notification stack?

## How much

~0.3r. One ~40-line module, one nv1 import line, one flake.nix
nixosModules entry. config.kdl is the only real authoring. **Touches
flake.nix (module registration) + machines/nv1 — NOT flake.lock.**

## Blockers

None for eval+dry-build. Deploy is human-gated (touches `machines/nv1`).
After deploy, gsnap baseline needs a separate Niri capture or it'll
false-positive on every desktop diff.
