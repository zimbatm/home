# adopt: tab-tap — read/act on the focused Firefox tab

## What

A tiny native-messaging bridge + Firefox extension exposing exactly two
ops over a unix socket:

- `tab-tap read` → `{url, title, text}` where `text` is the current
  tab run through Readability.js (reader-mode extract, not raw DOM)
- `tab-tap act <css-selector> [text]` → click the element, or type
  `text` into it if given

Wire into `now-context`: when the focused window is Firefox, extend the
JSON with a `tab` field so the agent's ambient context includes the page
text, not just the window title.

## Why

nv1's agent loop can already *see* (peek + moondream VLM), *know*
(now-context: focused window, AFK, clipboard), and *speak/hear* (the
voice stack). The missing act-surface is the browser: agent knows
"Firefox — GitHub PR #123" is focused but can't read the diff text or
click Approve. peek's VLM reads pixels, which is lossy and slow for
text-heavy pages.

Mic92/mics-skills ships `browser-cli` for the same gap — a Firefox
extension + native-messaging bridge that pipes **arbitrary JS** to the
page. Our angle: no JS REPL. Two verbs only (readable-text out, one
click/type in), so the security surface is `~/.mozilla` not `eval()`,
and the skill description fits in three lines instead of "here's the
WebExtensions API."

## How much

~0.6r. `packages/tab-tap/`: a ~40-line WebExtension (manifest +
background.js calling `tabs.executeScript` with a vendored
Readability.js), a ~30-line Python native-messaging host, a
writeShellApplication CLI wrapper. HM side: drop the native-messaging
manifest into `~/.mozilla/native-messaging-hosts/` via
`home.file`. The `now-context` integration is a follow-up `--tab` flag
(~15 lines, separate item).

No new flake inputs — Readability.js vendored as a single file, rest is
nixpkgs python3 + firefox already on nv1.

## Falsifies

- Whether two verbs (readable-text + one click) cover the 80% case, or
  agents immediately want arbitrary JS and we should have just used
  Mic92's eval bridge.
- Whether reader-mode text is enough, or agents need the full DOM
  (forms, aria labels, hidden state) — i.e. is Readability the right
  compression or does it throw away the actionable bits.
- Whether now-context's window-title → tab bridge holds when multiple
  Firefox windows are open (which tab is "current"?).

## Source

Mic92/mics-skills `browser-cli` (Firefox extension + native-messaging +
JS-stdin CLI, optionally headless via browsh). Surveyed 2026-04-12.
