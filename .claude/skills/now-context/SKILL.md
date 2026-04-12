---
name: now-context
description: Query what Jonas is doing right now — focused window, AFK state, last-15m app histogram — from the local ActivityWatch server. Use before proactive suggestions so they land in context.
---

Run `now-context` (no args). It prints one line of JSON:

```json
{"afk":false,
 "focused":{"app":"ghostty","title":"nvim — kin.nix","since_s":412},
 "last_15m":[{"app":"firefox","title":"NixOS Wiki — ...","s":220}, ...]}
```

If `afk` is true or `focused` is null, hold the suggestion. If `title` is
empty the Wayland compositor isn't exposing it — fall back to `app` only.
On `{"error":...}` ActivityWatch isn't running; skip context-aware behaviour.

When the user says *this* / *that* / *the selected …* without a referent in
the conversation, run `now-context --clip` first and resolve the deictic
from `selection` (primary, what's highlighted) before `clipboard` (last
Ctrl-C). Both are ≤4 KiB strings or `null`:

```json
{..., "selection":"fn parse(...) { ... }", "clipboard":null}
```
