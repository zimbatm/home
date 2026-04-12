// tab-tap background: native port ↔ two fixed ops on the active tab.
// No eval surface — `read` runs vendored Readability, `act` runs a fixed
// querySelector+click/type snippet with the selector/text passed as strings.

const port = browser.runtime.connectNative("tab_tap");

async function activeTab() {
  const [t] = await browser.tabs.query({ active: true, currentWindow: true });
  if (!t) throw new Error("no active tab");
  return t;
}

async function read() {
  const t = await activeTab();
  await browser.tabs.executeScript(t.id, { file: "Readability.js" });
  const [r] = await browser.tabs.executeScript(t.id, {
    code: `(() => {
      try {
        const a = new Readability(document.cloneNode(true)).parse();
        return { ok: true, url: location.href, title: a?.title ?? document.title,
                 text: a?.textContent ?? document.body.innerText };
      } catch (e) { return { ok: false, error: String(e) }; }
    })()`,
  });
  return r;
}

async function act(sel, text) {
  const t = await activeTab();
  const [r] = await browser.tabs.executeScript(t.id, {
    code: `((sel, text) => {
      const el = document.querySelector(sel);
      if (!el) return { ok: false, error: "selector matched nothing: " + sel };
      if (text == null) { el.click(); return { ok: true, did: "click" }; }
      el.focus(); el.value = text;
      el.dispatchEvent(new Event("input", { bubbles: true }));
      el.dispatchEvent(new Event("change", { bubbles: true }));
      return { ok: true, did: "type" };
    })(${JSON.stringify(sel)}, ${JSON.stringify(text ?? null)})`,
  });
  return r;
}

port.onMessage.addListener(async (m) => {
  try {
    if (m.op === "read") port.postMessage({ id: m.id, ...(await read()) });
    else if (m.op === "act") port.postMessage({ id: m.id, ...(await act(m.selector, m.text)) });
    else port.postMessage({ id: m.id, ok: false, error: "unknown op: " + m.op });
  } catch (e) {
    port.postMessage({ id: m.id, ok: false, error: String(e) });
  }
});
port.onDisconnect.addListener(() => {});
