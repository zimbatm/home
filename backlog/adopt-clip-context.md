# adopt: clip-context — fold wl-clipboard selection into now-context

## What

Extend `packages/now-context` (not a new binary) with a `--clip` flag
that adds two fields to its JSON:

```json
{ "afk": false, "focused": {...}, "last_15m": [...],
  "selection": "<primary, ≤4 KiB, or null>",
  "clipboard": "<ctrl-c buffer, ≤4 KiB, or null>" }
```

Backed by `wl-paste -p -n` / `wl-paste -n` (`pkgs.wl-clipboard`, already
in nixpkgs). Hard byte cap + `--max-time` so it never blocks; opt-in
flag so the default `now-context` call stays side-channel-free. Update
`.claude/skills/now-context/SKILL.md`: "when the user says *this* /
*that* / *the selected …* without a referent, call `now-context --clip`
first."

## Why

External seed: Mic92's `mics-skills` keeps growing one CLI per ambient
source (`db-cli`, `gmaps-cli`, `n8n-cli`, …) — the pattern is "expose
what's already on the desk to the agent." **Our angle:** don't spawn N
CLIs; fold the highest-value ambient channel (what Jonas just
highlighted) into the single `now-context` probe we already ship. Pairs
with the voice loop: select code in nvim/firefox → say "fix this" via
`ptt-dictate` → agent resolves *this* from `now-context --clip` instead
of asking. Zero new daemons, zero new packages.

## How much

~0.2r. +`pkgs.wl-clipboard` to `runtimeInputs`, ~12 LoC in the existing
`writeShellApplication`, ~6 lines in SKILL.md. No flake input, no
module change (now-context is already in `home/desktop`).

## Falsifies

Does selection-as-referent cut prompt typing? Log `--clip` resolutions
to `$XDG_STATE_HOME/now-context/clip.jsonl` (timestamp + byte-len +
focused.app) for a week alongside `llm-router/decisions.jsonl`. If
<1 hit/day or the selection is empty >80 % of calls, the deictic-"this"
workflow isn't real and the flag gets dropped.

## Blockers

None. `wl-clipboard` works on GNOME/Mutter (unlike `grim` — checked);
nv1 is Wayland-only.
