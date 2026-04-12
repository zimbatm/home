# adopt: niri-session — Niri alongside GNOME via GDM picker

## What

Add `crops-demo` as a flake input and enable Niri as a *second* login
session on nv1, leaving GNOME untouched:

- `flake.nix`: new input `crops-demo` (`git+ssh://git@github.com/assise/crops-demo`,
  `inputs.nixpkgs.follows = "nixpkgs"`).
- New `modules/nixos/niri.nix`:
  ```nix
  { pkgs, inputs, ... }: {
    programs.niri.enable = true;
    environment.systemPackages = with pkgs; [ noctalia-shell waybar foot fuzzel ];
    environment.etc."xdg/niri/config.kdl".text = ''…'';  # ours, not crops-demo's
  }
  ```
- `flake.nix` nixosModules: register `niri = ./modules/nixos/niri.nix` (ADR-0006).
- `machines/nv1/configuration.nix`: `imports += [ inputs.self.nixosModules.niri ]`.

GDM (already enabled via `gnome.nix`) picks up the niri wayland-session
file automatically — gear icon at login switches between GNOME and Niri.
Do **not** import `crops-demo/nix/desktop.nix` directly; it enables
greetd which conflicts with GDM.

The `config.kdl` is ours: start from crops-demo's
(`../crops-demo/nix/desktop.nix:164`) but drop the `crops`-user paths,
messaging-daemon spawns, and auto-login. Keep keybinds + noctalia spawn
+ foot terminal so it's usable day-one.

## Why (seed → our angle)

**Seed:** crops-demo ships Niri as its showcase compositor. nv1 is the
reference RTX 4060 Max-Q vfio host that crops-demo's `run-vm` defaults
to — the daily driver should be able to *run the demo desktop natively*,
not just host its VM.

**Our angle:** instead of swapping GNOME→Niri (daily-driver blast
radius), run both. GDM session picker gives a one-click fallback; the
generation menu gives a one-reboot fallback. We write our own
`config.kdl` rather than importing crops-demo's wholesale — theirs
assumes a `crops` user, messaging-daemon, and demo-specific spawns.

## Falsifies

- **GDM↔Niri coexist**: does `programs.niri.enable` cleanly add a
  session entry under GDM, or does it pull in conflicting portal/dbus
  config that breaks the GNOME session? Check
  `ls /run/current-system/sw/share/wayland-sessions/` post-deploy.
- **noctalia-shell under GNOME's dbus**: does noctalia start cleanly
  when gnome-shell isn't the running compositor but its services
  (gcr-ssh-agent, gnome-keyring) are still on the session bus?

## How much

~0.3r. One flake input, one ~40-line module, one nv1 import line, one
flake.nix nixosModules entry. The `config.kdl` is the only real
authoring (crib structure from crops-demo, write our own binds).

## Blockers

None for eval+dry-build. Deploy is human-gated (this touches
`machines/nv1`). After deploy, gsnap baseline needs a separate Niri
capture or it'll false-positive on every desktop diff.
