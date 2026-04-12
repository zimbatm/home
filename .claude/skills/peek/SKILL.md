---
name: peek
description: Capture the current Wayland desktop (or a region) to a PNG and inspect it. Use when debugging GTK/GNOME UI, extensions, notifications — anything that needs pixels, not logs.
---

Run `peek` to capture the full screen, or `peek --region` to interactively
select a rectangle (requires the user to drag on the physical display). The
command prints a PNG path under `$XDG_RUNTIME_DIR` — Read that path as an
image to see what's on screen.

For quick boolean/triage reads ("is there an error dialog?", "did the dark
theme apply?", "which pane is focused?"), prefer `peek --ask "<question>"`:
the capture is fed to a tiny local VLM (moondream2 on the Arc iGPU) and the
short answer comes back on stdout — no PNG ships upstream. Reach for the
plain PNG path only when the local answer is inconclusive or you need to
show the user pixels.

Full-screen captures on a HiDPI panel may downscale on Read; prefer
`--region` when inspecting small UI elements.
