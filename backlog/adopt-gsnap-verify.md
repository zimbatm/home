# adopt: gsnap — Wayland screenshot skill as a desktop-config visual gate

## What

A `gsnap` skill on nv1: one command captures the GNOME/Wayland session
to a downscaled PNG the agent can Read cheaply.

```sh
gsnap                       # full screen → /tmp/gsnap/last.png (~800px wide)
gsnap --window firefox      # focused-app via xdg-desktop-portal
gsnap --diff baseline.png   # perceptual diff vs a stored reference
```

Ship as `packages/gsnap/` (wraps `dbus-send` to
`org.gnome.Shell.Screenshot` + `imagemagick -resize 800x`) and a
`.claude/skills/gsnap/SKILL.md`. nv1-only via the existing
`homeModules.desktop` import.

## Why (our angle)

Mic92's [screenshot-cli] gives agents cross-platform capture so they can
*see* what they changed. We don't want a generic screenshot tool — we
want a **second gate** for desktop config. Today the grind gate is
eval+dry-build: it proves the config *evaluates*, not that the GTK
theme, panel extensions, or font rendering actually look right after a
home-manager bump. nv1 is the one host where "looks right" matters and
where a Wayland session is running to ask.

`gsnap --diff` against a committed `machines/nv1/baseline.png` turns
"Jonas eyeballs it post-deploy" into "agent flags a 30%-pixel-delta
before deploy". The portal call works headless-to-the-agent because the
session is already logged in on nv1.

## How much

~40 lines bash + imagemagick (already in closure via GNOME). One
SKILL.md. One `ops-` follow-up for Jonas to capture the first baseline
post-deploy. One round.

## Falsifies

"eval+dry-build is a sufficient gate for desktop hosts." If gsnap-diff
catches even one HM-bump regression (font fallback, theme breakage,
extension crash → blank panel) before deploy that eval missed, the
visual-gate idea graduates to assise inventory. If every diff is noise
(clock pixels, wallpaper), the perceptual-diff threshold is wrong or
desktop drift just isn't a real failure mode here — file the null result
in tried/.

## Blockers

Needs the nv1 session unlocked when the agent runs (portal refuses on a
locked screen). Acceptable: nv1 is the daily-driver, usually unlocked
during work hours; skill should fail gracefully otherwise.

[screenshot-cli]: https://github.com/Mic92/mics-skills/tree/main/screenshot-cli
