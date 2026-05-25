// Firefox content script that mirrors Chromium's clipboard UX for the
// web terminal at https://agents.ztm.io/.
//
// Why it exists: Firefox prompts the user on every call to
// `navigator.clipboard.read()` in a page context — no remember option.
// This extension declares `clipboardRead` as a required manifest
// permission, granted once at install time, after which content scripts
// can call `navigator.clipboard.read()` without per-call prompts.
//
// The page-served shim (clip-shim.js) still runs for users without this
// extension. We intercept the keydown earlier (capture phase from
// document_start) and stopImmediatePropagation so the page shim never
// fires its own popup-triggering path. Once we've POSTed the image to
// /clip, we call the page shim's `__termClipInject` helper to inject
// Ctrl+V (\x16) into ttyd's WebSocket — that part stays in page-world
// because the WebSocket instance is a page-world object.
(function () {
  console.log('[term-clip-ext] loaded');

  async function shipFromClipboard() {
    const items = await navigator.clipboard.read();
    let blob = null;
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
    // Stop the page-served shim from also handling this paste.
    e.preventDefault();
    e.stopImmediatePropagation();
    try {
      const shipped = await shipFromClipboard();
      if (shipped) injectCtrlV();
    } catch (err) {
      console.error('[term-clip-ext] paste flow failed', err);
    }
  }, true);
})();
