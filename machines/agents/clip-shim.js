// Intercept paste-with-image and push the blob to the agents-side clipboard
// bridge. After this fires, claude-code's `xclip -t image/png -o` sees the
// image and the in-claude paste flow works the same as on a local machine.
(function () {
  function shipImage(blob) {
    return fetch('/clip', {
      method: 'POST',
      headers: { 'Content-Type': blob.type || 'image/png' },
      body: blob,
    });
  }
  window.addEventListener('paste', function (e) {
    var items = (e.clipboardData && e.clipboardData.items) || [];
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (it.kind === 'file' && it.type && it.type.indexOf('image/') === 0) {
        var blob = it.getAsFile();
        if (!blob) continue;
        // Don't preventDefault — let xterm.js paste its (empty) text part too;
        // claude only cares about the clipboard side once we've shipped the blob.
        shipImage(blob).catch(function (err) {
          console.error('clip-shim: shipImage failed', err);
        });
        return;
      }
    }
  }, true);
})();
