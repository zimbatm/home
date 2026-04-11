---
name: peek
description: Capture the current Wayland desktop (or a region) to a PNG and inspect it. Use when debugging GTK/GNOME UI, extensions, notifications — anything that needs pixels, not logs.
---

Run `peek` to capture the full screen, or `peek --region` to interactively
select a rectangle (requires the user to drag on the physical display). The
command prints a PNG path under `$XDG_RUNTIME_DIR` — Read that path as an
image to see what's on screen.

Full-screen captures on a HiDPI panel may downscale on Read; prefer
`--region` when inspecting small UI elements.
