# adopt: sel-act — wayland selection → local-LLM transform

## What

`packages/sel-act`: grab the wayland **primary selection** (or clipboard
on `--clip`), pipe it through `ask-local` with a named transform
prompt, then either `wl-copy` the result or `ydotool type` it over the
selection. A small dispatch table (translate / tighten / explain /
shellify) lives in `~/.config/sel-act/prompts.toml`, same shape as
`ptt-dictate --intent`'s table. Bind two GNOME/Niri chords:
`sel-act tighten` and `sel-act ask` (free-form, prompt comes from a
`zenity --entry`).

## Why

nv1 has the **voice** loop closed (ptt-dictate → ask-local →
say-back/ydotool) but no **text** equivalent — to use the local model
on text you already see, you copy → terminal → paste → run → copy
back. Mic92's `mics-skills` ships per-domain CLIs (browser-cli,
calendar-cli) but nothing for the universal "any selected text in any
app" case either. This is the cheapest possible "LLM everywhere" UX:
no per-app integration, works in Firefox, foot, nvim, GTK fields alike.

## How much

~0.4r. `wl-clipboard` + `ydotool` already on nv1;
`ask-local` already does one-shot completion. ~40 LoC shellApplication
+ a default prompts.toml + two `custom-keybindings` entries in
`modules/home/desktop` next to the ptt-dictate ones.

## Falsifies

Is Phi-3-mini on the Arc iGPU fast and good enough for *interactive*
text transforms (<2s for a paragraph), or does latency/quality make it
unusable? `agent-meter --line` already surfaces Arc-busy %; this gives
it a real interactive workload to measure instead of batch infer-queue
jobs. If it's too slow, that's a concrete signal to either route
`sel-act` through `llm-router` (size-gated remote fallback) or revisit
the vfio-reserved RTX 4060 for host-side use.
