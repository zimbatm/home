# bug: gsnap fails with AccessDenied — Shell.Screenshot is sender-restricted

## What

`gsnap` on nv1 (GNOME) fails:
```
gsnap: portal call failed (locked screen / no GNOME session?): Error: GDBus.Error:org.freedesktop.DBus.Error.AccessDenied: Screenshot is not allowed
```

`packages/gsnap/default.nix:27` calls `org.gnome.Shell.Screenshot` over the
session bus. Since GNOME 41, Shell restricts this interface to allowlisted
sender app-ids (`org.gnome.Screenshot`, the Shell's own UI). CLI scripts
get AccessDenied unconditionally — there is no way to allowlist a shell
script.

## Fix

Make gsnap compositor-aware (nv1 now runs GNOME *and* Niri sessions):

```sh
case "$XDG_CURRENT_DESKTOP" in
  niri|sway|*wlroots*)
    grim "$raw"  # Niri implements wlr-screencopy
    ;;
  GNOME|*)
    # xdg-desktop-portal Screenshot — async Request/Response over dbus.
    # Non-interactive needs PermissionStore grant for app_id "" (host apps).
    gdbus call --session --dest org.freedesktop.portal.Desktop \
      --object-path /org/freedesktop/portal/desktop/screenshot …
    ;;
esac
```

Ship the one-time permission grant as a home-manager activation snippet
in `modules/home/desktop/default.nix` so it survives rebuilds:
```nix
home.activation.grantScreenshotPortal = lib.hm.dag.entryAfter ["writeBoundary"] ''
  ${pkgs.glib}/bin/gdbus call --session \
    --dest org.freedesktop.impl.portal.PermissionStore \
    --object-path /org/freedesktop/impl/portal/PermissionStore \
    --method org.freedesktop.impl.portal.PermissionStore.SetPermission \
    screenshot true screenshot "" '["yes"]' 2>/dev/null || true
'';
```

While here: switch baseline lookup to `machines/nv1/baseline-$desktop.png`
(where `desktop=$(echo "$XDG_CURRENT_DESKTOP" | tr A-Z a-z | cut -d: -f1)`)
so GNOME and Niri each diff against their own reference. Update
`.claude/skills/gsnap/SKILL.md` and `backlog/needs-human/ops-gsnap-baseline.md`
to capture both.

## How much

~0.4r. The xdg-portal path is the bulk (async Request → wait for Response
signal → extract file URI; ~25 lines of gdbus). grim path is 1 line.
runtimeInputs += `grim`.

## Blockers

None. Testable headless: `nix build .#gsnap` + shellcheck. Runtime test
needs the live nv1 session (post-deploy).
