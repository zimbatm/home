# Firefox clipboard-bridge extension

Optional Firefox WebExtension that gives `agents.ztm.io` the same
"prompt-once, remember forever" image-paste UX Chromium has natively.
Only useful if you want to stay in Firefox for the web terminal —
Chromium already works without this.

## How it changes things

Without the extension, Firefox shows a contextual "Paste" button on
every `navigator.clipboard.read()` call (per-paste permission, no
remember). With the extension, you grant `clipboardRead` **once at
install time**, after which the content script reads the clipboard
silently — equivalent UX to Chromium's "Allow always".

The page-served shim (`clip-shim.js`) still runs; this extension just
intercepts the keydown a beat earlier with extension-level privilege.

## Loading it (temporary, per browser restart)

1. `about:debugging#/runtime/this-firefox`
2. Click **Load Temporary Add-on**
3. Pick `manifest.json` from this directory
4. Visit https://agents.ztm.io/ — the first paste should now use
   Firefox's native permission prompt (with remember).

Survives until the browser restarts.

## Loading it (permanent)

Firefox requires signed extensions for non-temporary installs. Two
paths:

- **Submit to AMO for self-distribution signing.** Sign in to
  https://addons.mozilla.org/developers/, choose "On your own" when
  uploading, get back a signed `.xpi` (usually within minutes for
  small extensions). Install once per device.
- **Firefox Developer Edition / Nightly**: set
  `xpinstall.signatures.required = false` in `about:config` and install
  any `.xpi` directly. Doesn't work in stable Firefox.

## Updating

Bump `version` in `manifest.json`, reload the temporary add-on (or
re-submit to AMO). Content-script changes pick up on the next page
load after reload.
