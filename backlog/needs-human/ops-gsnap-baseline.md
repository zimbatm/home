# ops: capture nv1 gsnap baselines (per session)

**needs-human** — runs on the live nv1 sessions.

## What

After the compositor-aware `gsnap` lands on nv1 (next `kin deploy nv1`),
capture a reference screenshot from **each** session type and commit both:

```sh
# GNOME session — unlocked, desktop in its "normal" state
gsnap
cp /tmp/gsnap/last.png ~/src/home/machines/nv1/baseline-gnome.png

# log out, log into the Niri session, same drill
gsnap
cp /tmp/gsnap/last.png ~/src/home/machines/nv1/baseline-niri.png

cd ~/src/home
git add machines/nv1/baseline-gnome.png machines/nv1/baseline-niri.png
git commit -m "nv1: gsnap per-session baselines"
```

## Why

`gsnap --diff` now defaults to `machines/nv1/baseline-$desktop.png`
(`$desktop` derived from `$XDG_CURRENT_DESKTOP`), so each compositor
diffs against its own reference — GNOME and Niri look nothing alike at
the pixel level. The agent can't capture either: no unlocked graphical
session.

GNOME note: the first capture after deploy may need
`systemctl --user restart xdg-desktop-portal` for the PermissionStore
grant (applied by `home.activation.grantScreenshotPortal`) to take
effect.

## Done when

`machines/nv1/baseline-gnome.png` and `machines/nv1/baseline-niri.png`
exist on main and `gsnap --diff` on a quiet desktop reports <5% in each
session.
