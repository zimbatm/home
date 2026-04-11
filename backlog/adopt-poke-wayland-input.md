# adopt: poke — Wayland input injection, agent-eyes' other half

## What

Mic92's `mics-skills` ships `pexpect-cli` (drive PTY TUIs) and
`browser-cli` (drive a browser) so the agent can *act*, not just read.
We have `agent-eyes`/`peek` (grim screenshot → agent reads the PNG)
but no act-side. Close the loop with `poke`:

    poke key ctrl+shift+t        # ydotool key
    poke type "nix flake check"  # ydotool type
    poke click 840 612           # ydotool mousemove + click

Thin `writeShellApplication` over ydotool, mirroring `peek`'s shape
(~40 lines, no daemon, no state). Ship as `packages/agent-eyes`
sibling binary so peek+poke install together.

## Why

nv1 already has `programs.ydotool.enable = true` (for ptt-dictate) —
the uinput socket and group are live, zero new system surface. peek+poke
gives the agent a general Wayland see/act pair: more reach than pexpect
(any GUI, not just terminals) and no Chromium dep like browser-cli.

## How much

~0.3r. One writeShellApplication, add to agent-eyes' output set, wire
into modules/home/desktop alongside peek.

## Falsifies

Whether screenshot+ydotool is a tight enough loop for an agent to
actually drive a GUI (latency, coordinate stability across redraws), or
whether we need AT-SPI/accessibility-tree introspection instead. Cheap
to find out.

## Source

Mic92/dotfiles `home-manager/modules/ai.nix` @ mics-skills
`pexpect-cli` + `screenshot-cli` + `browser-cli` — their pattern,
our Wayland-native implementation.
