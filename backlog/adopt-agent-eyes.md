# adopt: agent-eyes — let the nv1 agent see the screen

## What

`packages/agent-eyes`: a tiny `peek` CLI for Wayland/GNOME that
captures the screen (or a region) to a temp PNG and prints the path,
plus a `.claude/skills/peek/SKILL.md` telling the agent to `peek` then
`Read` the resulting image. Wire into `agentshell` so any desktop host
gets it automatically.

Implementation: `writeShellApplication` wrapping `grim` (+ `slurp` for
region select) — both already in nixpkgs, both Wayland-native. No
daemon, no state.

## Why

Mic92 ships a `screenshot-cli` skill so his agent can inspect rendered
UI. Our angle: nv1 is the *desktop* testbed — the agent is currently
blind to pixels. Questions like "did the gnome extension load", "why
is this GTK dialog clipped", "what's the ptt-dictate notification
showing" need a screenshot, not a log grep. We build it GNOME-first
(grim works under mutter via xdg-desktop-portal) and ship it through
agentshell rather than a home-manager module — fits the kin shape.

## How much

~0.3r. `grim`+`slurp` are packaged; the wrapper is ~15 lines; the
skill file is ~10 lines. Gate: `peek` produces a readable PNG on nv1
under GNOME Wayland (verify post-deploy, needs-human for that step).

## Falsifies

Whether Claude's image-Read on a full 2880×1800 GNOME capture is
actually useful for UI debugging, or whether the downscale loses too
much. If it's lossy → fall back to region-select-only (`peek --region`
via slurp) and call the full-screen path dead.

## Blockers

None for the package. Runtime verification needs a logged-in Wayland
session → needs-human after dry-build passes.
