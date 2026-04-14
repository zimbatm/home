---
name: gsnap
description: Capture the live nv1 desktop (GNOME or Niri) and perceptually diff it against a per-session committed baseline. Use as a second gate (after eval+dry-build) when a change touches modules/home/desktop, GTK theme, fonts, GNOME extensions, or the Niri layout — flag visual regressions before deploy instead of after.
---

`gsnap` is compositor-aware: on Niri/sway/wlroots it uses `grim`
(wlr-screencopy); on GNOME it goes through xdg-desktop-portal's async
Screenshot Request/Response (the direct `org.gnome.Shell.Screenshot` bus
API is sender-restricted since GNOME 41 and rejects CLI callers). Output
is downscaled to ~800px so the PNG is cheap to Read.

```sh
gsnap                    # full screen → /tmp/gsnap/last.png; prints path
gsnap --diff             # diff against machines/nv1/baseline-$desktop.png
gsnap --diff PATH        # diff against explicit baseline
                         # prints "pixel-delta: N.N%"; exit 1 if >5%
```

`$desktop` is `$XDG_CURRENT_DESKTOP` lowercased, first colon-field — so
the GNOME session diffs against `baseline-gnome.png` and the Niri session
against `baseline-niri.png`.

**Second-gate workflow** (nv1 only — runs *on the host*, not in the build VM):

1. eval+dry-build passes → ssh nv1, `cd ~/src/home && gsnap --diff`.
2. Non-zero → Read `/tmp/gsnap/last.png` and the matching baseline,
   eyeball what moved. Clock/notification noise is expected (<5% with the
   fuzz); a blank panel, missing tray, or wrong font is a real regression.
3. Intentional visual change → file an `ops-` item to recapture that
   session's baseline post-deploy; don't overwrite it from the agent.

**GNOME prerequisite:** non-interactive portal screenshots need a one-time
PermissionStore grant for app_id `""` (host/unsandboxed apps). Shipped as
`home.activation.grantScreenshotPortal` in `modules/home/desktop/default.nix`
so it survives rebuilds. If gsnap reports "portal denied", the grant hasn't
reached this session yet — `systemctl --user restart xdg-desktop-portal`
or re-login.

Fails gracefully with a clear message if the screen is locked or no
session bus is reachable — treat that as "gate skipped", not "gate red".
