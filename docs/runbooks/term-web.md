# Web terminal at https://agents.ztm.io/

ttyd behind nginx on the `agents` box. The vhost is gated by
oauth2-proxy → Pocket ID (`id.zimbatm.com`); once you're signed in
with a passkey, you reach ttyd. A clipboard bridge ferries image-paste
to Claude Code:

- A JS shim (`machines/agents/clip-shim.js`) is injected into ttyd's
  HTML via nginx `sub_filter`. On `Ctrl/Cmd+V` it calls
  `navigator.clipboard.read()`, POSTs any image blob to `/clip`, then
  writes `\x16` to ttyd's WebSocket so claude re-reads the clipboard.
- `clip-bridge.py` (systemd unit `clip-bridge`) receives `/clip` POSTs
  and writes the image to `/tmp/clip-latest.<ext>` (+ a timestamped
  archive copy).
- `/etc/term-paste/xclip` (sourced from `machines/agents/fake-xclip`)
  is prepended to interactive `$PATH`. When claude calls
  `xclip -selection clipboard -t image/png -o`, this shim returns the
  saved file. No real X server in the loop — `xclip`'s daemonization
  under systemd is too unreliable for one-shot writes.

**Use Chromium / Brave**, not Firefox: Firefox prompts a "Paste"
button on every `navigator.clipboard.read()` call with no remember
option; Chromium grants persistent permission after the first Allow.

## Sign in on a new device

1. Open https://id.zimbatm.com/ — register a passkey under your account.
2. Open https://agents.ztm.io/ — oauth2-proxy redirects you to Pocket
   ID, authenticate with the passkey, you land back in ttyd.

No per-device certificate to import. Cookies are scoped to `.ztm.io`
so the session is shared across future `*.ztm.io` SSO targets.

## Revoke access for a device or user

In the Pocket ID admin UI (`id.zimbatm.com`):
- Remove the passkey from your user, or
- Disable the user entirely (admin → Users → toggle Disabled).

There's no per-device session list yet in Pocket ID; if you suspect a
session token leaked, restart `oauth2-proxy.service` on `agents` to
invalidate the cookie signing secret (it's keyed by a stable agenix
secret — restarting alone won't rotate it; bump
`oauth2-proxy-agents-cookie.age` if you actually need rotation).

## Inside the session

The shell launched is `bash -l`, so the existing
`programs.bash.interactiveShellInit` on agents auto-execs herdr.
Detach: `Ctrl-b q` (default herdr binding). Closing the browser tab is
the same as detaching — reattach by reloading the page.

To bypass herdr for a session: `NO_HERDR=1` is honored, but you'd need
to invoke a wrapper that sets it — the ttyd entrypoint doesn't read it
from the URL. Easiest: just `exec bash` from inside herdr.
