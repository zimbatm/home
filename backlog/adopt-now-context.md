# adopt: now-context — ambient desktop state from activitywatch for agents

## What

`packages/now-context`: a stateless CLI that queries the local
ActivityWatch REST API (`127.0.0.1:5600`, already running on nv1 via
`modules/home/desktop/activitywatch.nix`) and prints compact JSON:

```json
{ "afk": false,
  "focused": {"app": "ghostty", "title": "nvim — kin.nix", "since_s": 412},
  "last_15m": [{"app": "firefox", "title": "...", "s": 220}, ...] }
```

Ship alongside a `.claude/skills/now-context/SKILL.md` so the agent
calls it before proactive suggestions ("you've been in kin.nix for 7
min — want me to dry-build?").

## Why

Surveyed: Mic92's `mics-skills` gives his agent personal context via N
point integrations (`calendar-cli`, `browser-cli`, `gmaps-cli`, …) —
each its own auth, its own API. **Our angle:** nv1 already runs
aw-watcher-window-wayland + aw-watcher-afk capturing exactly "what is
Jonas doing right now" into a local bucket store. One read-only query
against data we already collect beats five bespoke integrations, and
it's strictly local — no cloud calendar tokens in the agent's reach.

## How much

~0.3r. writeShellApplication wrapping `curl -s localhost:5600/api/0/...`
+ `jq`. AW's query API takes a time range and bucket id; both watchers'
bucket names are deterministic. SKILL.md is ~10 lines.

## Falsifies

"Ambient activity context the machine already records is enough for
useful proactive agent behaviour — no per-service integrations needed."
If the window-title stream is too noisy/generic to act on (e.g. just
"Firefox" with no page title), the premise fails and per-service
integrations were right after all.

## Blockers

Verify aw-watcher-window-wayland actually populates `title` under
GNOME/Wayland (some compositors strip it). One `curl` on nv1 settles it
— if empty, scope shrinks to afk + app-name only.
