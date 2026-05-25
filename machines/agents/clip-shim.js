// Image-paste bridge for the web terminal at agents.ztm.io.
//
// Two complications, addressed below:
//
// 1. Firefox doesn't fire `paste` events for image clipboard contents into
//    textareas (xterm.js's input target). We catch keydown(Ctrl/Cmd+V) and
//    pull the clipboard ourselves via navigator.clipboard.read(). The
//    keydown counts as the user gesture; Firefox shows a transient "Paste"
//    popup each time and there's no way to suppress it.
//
// 2. xterm forwards the keystroke to the PTY at the same time our async
//    upload starts, so claude's `xclip -t image/png -o` runs against an
//    empty clipboard before the image lands. We preventDefault on the
//    keydown to hold the keystroke, run the upload, and only then inject
//    Ctrl+V (\x16) directly into ttyd's WebSocket so claude re-checks the
//    clipboard with the image now in place.
//
// The WebSocket interception is the load-bearing hack: ttyd's protocol is
// client→server messages prefixed by '0' for raw input bytes. We capture
// the WS instance the first time ttyd sends anything, then reuse it for
// our post-upload injection.
(function () {
  console.log('[clip-shim] loaded');

  // Stash the ttyd WebSocket the first time it sends.
  let ttydWS = null;
  const realSend = WebSocket.prototype.send;
  WebSocket.prototype.send = function (data) {
    if (!ttydWS) {
      ttydWS = this;
      console.log('[clip-shim] captured ttyd WebSocket');
    }
    return realSend.call(this, data);
  };

  // Expose a helper for the Firefox extension to inject keystrokes into
  // the PTY without re-implementing WebSocket capture in extension land.
  window.__termClipInject = function (bytes) {
    if (!ttydWS) return false;
    ttydWS.send('0' + bytes);
    return true;
  };

  async function shipImage(blob) {
    console.log('[clip-shim] shipping', blob.type, blob.size, 'bytes');
    const r = await fetch('/clip', {
      method: 'POST',
      headers: { 'Content-Type': blob.type || 'image/png' },
      body: blob,
    });
    const text = await r.text();
    console.log('[clip-shim] /clip → HTTP', r.status, text.trim());
    return r.ok;
  }

  async function pullAndShip() {
    if (!navigator.clipboard || !navigator.clipboard.read) {
      console.warn('[clip-shim] navigator.clipboard.read unavailable');
      return false;
    }
    const items = await navigator.clipboard.read();
    for (const item of items) {
      for (const type of item.types) {
        if (type.indexOf('image/') === 0) {
          const blob = await item.getType(type);
          return await shipImage(blob);
        }
      }
    }
    console.log('[clip-shim] no image in clipboard; letting xterm handle text paste');
    return null;  // signal: not an image paste, fall through to normal text paste
  }

  document.addEventListener('keydown', async function (e) {
    const isPaste = (e.key === 'v' || e.key === 'V') && (e.ctrlKey || e.metaKey) && !e.altKey;
    if (!isPaste) return;
    // Hold the keystroke so xterm doesn't immediately forward it to claude.
    e.preventDefault();
    e.stopImmediatePropagation();
    try {
      const ok = await pullAndShip();
      if (ok === null) {
        // No image — replay the keystroke as a real paste so xterm reads text.
        // navigator.clipboard.readText() + send via WS as bracketed paste.
        try {
          const txt = await navigator.clipboard.readText();
          if (txt && ttydWS) {
            ttydWS.send('0' + '\x1b[200~' + txt + '\x1b[201~');
          }
        } catch (err) {
          console.error('[clip-shim] text paste fallback failed', err);
        }
        return;
      }
      if (!ok) {
        console.warn('[clip-shim] image ship failed; not triggering claude');
        return;
      }
      // Image is now on agents' xclip. Trigger claude's paste check by
      // injecting Ctrl+V (\x16) into the PTY via the captured WebSocket.
      if (!ttydWS) {
        console.error('[clip-shim] no ttyd WebSocket captured yet — cannot inject');
        return;
      }
      ttydWS.send('0' + '\x16');
      console.log('[clip-shim] injected Ctrl+V to PTY');
    } catch (err) {
      console.error('[clip-shim] paste flow failed', err);
    }
  }, true);
})();
