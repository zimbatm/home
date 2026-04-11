---
name: gsnap
description: Capture the live GNOME session on nv1 and perceptually diff it against a committed baseline. Use as a second gate (after eval+dry-build) when a change touches modules/home/desktop, GTK theme, fonts, or GNOME extensions — flag visual regressions before deploy instead of after.
---

`gsnap` talks to `org.gnome.Shell.Screenshot` over the session bus (works
on Mutter; `peek`/grim does not) and downscales to ~800px so the PNG is
cheap to Read.

```sh
gsnap                              # full screen → /tmp/gsnap/last.png; prints path
gsnap --window                     # focused window only
gsnap --diff machines/nv1/baseline.png
                                   # prints "pixel-delta: N.N%"; exit 1 if >5%
```

**Second-gate workflow** (nv1 only — runs *on the host*, not in the build VM):

1. eval+dry-build passes → ssh nv1, `gsnap --diff machines/nv1/baseline.png`.
2. Non-zero → Read `/tmp/gsnap/last.png` and the baseline, eyeball what
   moved. Clock/notification noise is expected (<5% with the fuzz); a
   blank panel, missing tray, or wrong font is a real regression.
3. Intentional visual change → file an `ops-` item to recapture the
   baseline post-deploy; don't overwrite it from the agent.

Fails gracefully with a clear message if the screen is locked or no
session bus is reachable — treat that as "gate skipped", not "gate red".
