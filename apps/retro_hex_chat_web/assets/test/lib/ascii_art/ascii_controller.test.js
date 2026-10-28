import { afterEach, describe, expect, it, vi } from "vitest";
import { createAsciiArt, renderCells } from "../../../js/lib/ascii_art/ascii_controller.js";
import { FROM_PAINT_EVENT, FROM_PAINT_KEY } from "../../../js/lib/ascii_art/hand_off.js";
import { cell } from "../../../js/lib/ascii_art/cells.js";
import { createDrawing, encode, paint } from "../../../js/lib/paint/document.js";
import { DRAFT_KEY } from "../../../js/lib/paint/paint_controller.js";

function memoryStorage(initial = {}) {
  const items = new Map(Object.entries(initial));
  return {
    getItem: (key) => (items.has(key) ? items.get(key) : null),
    setItem: (key, value) => items.set(key, String(value)),
    removeItem: (key) => items.delete(key),
  };
}

// The window's controls as the server draws them.
function mountArt({ storage = memoryStorage(), session = memoryStorage() } = {}) {
  document.body.innerHTML = `
    <div id="ascii-art-root">
      <button class="tabs-trigger" data-target="text"></button>
      <button class="tabs-trigger" data-target="paint"></button>
      <textarea name="ascii-text"></textarea>
      <label><input type="radio" name="ascii-style" value="block" checked /></label>
      <label><input type="radio" name="ascii-style" value="hash" /></label>
      <label><input type="radio" name="ascii-scheme" value="single" checked /></label>
      <label><input type="radio" name="f" value="9" /><span data-irc-colour="9"></span></label>
      <span data-irc-current="fg"></span>
      <div data-ascii-preview></div>
    </div>`;
  // A tab, opened, says so the way the server's tab commands do.
  for (const tab of document.querySelectorAll(".tabs-trigger")) {
    tab.addEventListener("click", () =>
      tab
        .closest("#ascii-art-root")
        .dispatchEvent(new CustomEvent("ascii:source", { detail: { source: tab.dataset.target } })),
    );
  }
  const el = document.getElementById("ascii-art-root");
  const status = {};
  const ports = {
    storage: () => storage,
    session: () => session,
    status: (name, text) => (status[name] = text),
    post: vi.fn(),
    copy: vi.fn(() => Promise.resolve()),
  };
  const art = createAsciiArt(el, ports);
  art.mount();
  return { el, art, ports, status, session };
}

const type = (el, text) => {
  const area = el.querySelector("[name='ascii-text']");
  area.value = text;
  area.dispatchEvent(new Event("input", { bubbles: true }));
};

const command = (el, name) =>
  el.dispatchEvent(new CustomEvent("ascii:command", { detail: { command: name } }));

afterEach(() => {
  document.body.innerHTML = "";
});

describe("ASCII Art's window", () => {
  it("draws typed text as a banner, in the colour chosen, and posts it as one message", () => {
    const { el, art, ports, status } = mountArt();
    el.querySelector("[data-irc-colour='9']").closest("label").click();
    type(el, "HI");

    expect(el.querySelector("[data-ascii-preview] pre.irc-art .irc-fg-9")).not.toBeNull();
    expect(status.size).toBe("16×5");
    expect(el.querySelector("[data-irc-current='fg']").classList.contains("irc-bg-9")).toBe(true);

    command(el, "post");
    expect(ports.post).toHaveBeenCalledWith(art.message());
    expect(art.message().split("\n")).toHaveLength(5);
    expect(art.message().startsWith("\x0309█")).toBe(true);
  });

  it("starts from the Hex Paint drawing when Hex Paint left word, and only once", () => {
    const drawing = paint(createDrawing(32), [[0, 0]], 4);
    const session = memoryStorage({ [FROM_PAINT_KEY]: "1" });
    const { el, status } = mountArt({
      storage: memoryStorage({ [DRAFT_KEY]: encode(drawing) }),
      session,
    });

    expect(el.querySelector("[data-ascii-preview] pre .irc-fg-4")).not.toBeNull();
    expect(status.size).toBe("32×16");
    expect(session.getItem(FROM_PAINT_KEY)).toBeNull();
  });

  it("turns to the drawing when Hex Paint asks while it is open", () => {
    const drawing = paint(createDrawing(32), [[0, 0]], 4);
    const { el } = mountArt({ storage: memoryStorage({ [DRAFT_KEY]: encode(drawing) }) });
    expect(el.querySelector("[data-ascii-preview] pre .irc-fg-4")).toBeNull();
    document.dispatchEvent(new CustomEvent(FROM_PAINT_EVENT));
    expect(el.querySelector("[data-ascii-preview] pre .irc-fg-4")).not.toBeNull();
  });

  it("has nothing to post or copy before there is art", () => {
    const { el, ports } = mountArt();
    command(el, "post");
    command(el, "copy");
    expect(ports.post).not.toHaveBeenCalled();
    expect(ports.copy).not.toHaveBeenCalled();
  });
});

describe("the preview", () => {
  it("draws cells as the chat does: plain text bare, colours as spans", () => {
    const pre = renderCells(document, [[cell("a"), cell("█", 4, 2)], [cell("b")]]);
    expect(pre.outerHTML).toBe(
      '<pre class="irc-art">a<span class="irc-fg-4 irc-bg-2">█</span>\nb</pre>',
    );
  });
});
