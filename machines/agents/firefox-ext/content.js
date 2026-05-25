// Firefox content script that mirrors Chromium's clipboard UX for the
// web terminal at https://agents.ztm.io/.
//
// Why it exists: Firefox prompts the user on every call to
// `navigator.clipboard.read()` in a page context — no remember option.
// Extensions can request the `clipboardRead` host permission via
// `browser.permissions.request()`, which uses Firefox's *native*
// permission UI that does have a remember toggle. So on first paste the
// user sees one familiar prompt; after Allow it's silent.
//
// The page-served shim (clip-shim.js) still runs for users without this
// extension. We intercept the keydown earlier (capture phase from
// document_start) and stopImmediatePropagation so the page shim never
// fires its own popup-triggering path. Once we've POSTed the image to
// /clip, we call the page shim's exposed `__termClipInject` helper to
// inject Ctrl+V (\x16) into ttyd's WebSocket — that part stays in the
// page world because the WS instance is a page-world object.
(function () {
  console.log('[term-clip-ext] loaded');

  async function ensurePermission() {
    const has = await browser.permissions.contains({ permissions: ['clipboardRead'] });
    if (has) return true;
    return await browser.permissions.request({ permissions: ['clipboardRead'] });
  }

  async function shipFromClipboard() {
    let blob = null;
    const items = await navigator.clipboard.read();
    for (const item of items) {
      for (const type of item.types) {
        if (type.indexOf('image/') === 0) {
          blob = await item.getType(type);
          break;
        }
      }
      if (blob) break;
    }
    if (!blob) {
      console.log('[term-clip-ext] no image in clipboard');
      return false;
    }
    console.log('[term-clip-ext] shipping', blob.type, blob.size, 'bytes');
    const r = await fetch('/clip', {
      method: 'POST',
      headers: { 'Content-Type': blob.type || 'image/png' },
      body: blob,
    });
    const text = await r.text();
    console.log('[term-clip-ext] /clip → HTTP', r.status, text.trim());
    return r.ok;
  }

  function injectCtrlV() {
    // The page-served shim exposes this on window. We reach into the page
    // world via wrappedJSObject (Firefox content-script idiom).
    const pageWin = window.wrappedJSObject;
    if (pageWin && typeof pageWin.__termClipInject === 'function') {
      pageWin.__termClipInject('\x16');
      console.log('[term-clip-ext] injected Ctrl+V to PTY');
    } else {
      console.warn('[term-clip-ext] page shim injector not found; reload page');
    }
  }

  document.addEventListener('keydown', async function (e) {
    const isPaste = (e.key === 'v' || e.key === 'V') && (e.ctrlKey || e.metaKey) && !e.altKey;
    if (!isPaste) return;
    // Take over from the page shim: stop both immediate propagation and the
    // browser's native paste so we control the whole sequence.
    e.preventDefault();
    e.stopImmediatePropagation();
    try {
      const ok = await ensurePermission();
      if (!ok) {
        console.warn('[term-clip-ext] clipboardRead permission refused');
        return;
      }
      const shipped = await shipFromClipboard();
      if (shipped) injectCtrlV();
    } catch (err) {
      console.error('[term-clip-ext] paste flow failed', err);
    }
  }, true);  // capture: true → runs before any bubble-phase handler
})();
