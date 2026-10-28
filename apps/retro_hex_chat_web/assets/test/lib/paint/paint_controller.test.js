import { afterEach, describe, expect, it, vi } from "vitest";
import { CLEAR, colourAt, createDrawing, encode, paint } from "../../../js/lib/paint/document.js";
import {
  DRAFT_KEY,
  createPaint,
  fittingZoom,
  toolForKey,
} from "../../../js/lib/paint/paint_controller.js";

function memoryStorage(initial = {}) {
  const items = new Map(Object.entries(initial));
  return {
    getItem: (key) => (items.has(key) ? items.get(key) : null),
    setItem: (key, value) => items.set(key, String(value)),
  };
}

// The window's body as the server draws it: two swatches, a tool, the canvas.
function mountPaint({ storage = memoryStorage() } = {}) {
  document.body.innerHTML = `
    <div id="hex-paint" tabindex="0">
      <button data-paint-tool="pencil"></button>
      <button data-paint-tool="line"></button>
      <label><input type="radio" name="fg" value="0" /><span data-irc-colour="0" style="background-color: rgb(255, 255, 255)"></span></label>
      <label><input type="radio" name="fg" value="4" /><span data-irc-colour="4" style="background-color: rgb(255, 0, 0)"></span></label>
      <span data-irc-current="fg" class="irc-bg-1"></span>
      <div id="hex-paint-stage"><canvas data-paint-canvas></canvas></div>
    </div>`;
  const el = document.getElementById("hex-paint");
  const canvas = el.querySelector("canvas");
  // A 32-pixel drawing shown at 10 screen pixels a pixel.
  canvas.getBoundingClientRect = () => ({ left: 0, top: 0, width: 320, height: 320 });
  const status = {};
  const ports = {
    storage: () => storage,
    status: (name, text) => (status[name] = text),
    post: vi.fn(),
    download: vi.fn(),
    openAscii: vi.fn(),
  };
  const controller = createPaint(el, ports);
  controller.mount();
  return { el, canvas, controller, ports, status, storage };
}

const pointer = (canvas, type, x, y, button = 0) =>
  canvas.dispatchEvent(
    new MouseEvent(type, { clientX: x * 10 + 5, clientY: y * 10 + 5, button, bubbles: true }),
  );

const command = (el, name, detail = {}) =>
  el.dispatchEvent(new CustomEvent("paint:command", { detail: { command: name, ...detail } }));

afterEach(() => {
  document.body.innerHTML = "";
});

describe("Hex Paint's window", () => {
  it("paints a stroke with the left button's colour and takes it back with one undo", () => {
    const { el, canvas, controller } = mountPaint();
    el.querySelector("[data-irc-colour='4']").closest("label").click();
    expect(el.querySelector("[data-irc-current='fg']").classList.contains("irc-bg-4")).toBe(true);
    pointer(canvas, "pointerdown", 1, 1);
    pointer(canvas, "pointermove", 4, 1);
    pointer(canvas, "pointerup", 4, 1);
    expect(colourAt(controller.drawing(), 1, 1)).toBe(4);
    expect(colourAt(controller.drawing(), 3, 1)).toBe(4);

    command(el, "undo");
    expect(colourAt(controller.drawing(), 3, 1)).toBe(CLEAR);
    command(el, "redo");
    expect(colourAt(controller.drawing(), 3, 1)).toBe(4);
  });

  it("keeps the drawing as a draft and opens on it the next time", () => {
    const storage = memoryStorage();
    const first = mountPaint({ storage });
    pointer(first.canvas, "pointerdown", 2, 2);
    pointer(first.canvas, "pointerup", 2, 2);
    first.controller.destroy();

    const again = mountPaint({ storage });
    expect(colourAt(again.controller.drawing(), 2, 2)).toBe(1);
  });

  it("opens on a draft kept before, and starts a new size from the File menu", () => {
    const kept = paint(createDrawing(64), [[10, 10]], 9);
    const { el, controller, status } = mountPaint({
      storage: memoryStorage({ [DRAFT_KEY]: encode(kept) }),
    });
    expect(controller.drawing().size).toBe(64);
    expect(status.size).toBe("64×64");

    command(el, "new", { size: 128 });
    expect(controller.drawing().size).toBe(128);
    command(el, "undo");
    expect(colourAt(controller.drawing(), 10, 10)).toBe(9);
  });

  it("chooses a tool by key and says so, pressed and in the status line", () => {
    const { el, status } = mountPaint();
    el.dispatchEvent(new KeyboardEvent("keydown", { key: "l", bubbles: true }));
    expect(status.tool).toBe("Line");
    expect(el.querySelector("[data-paint-tool='line']").getAttribute("aria-pressed")).toBe("true");
    expect(el.querySelector("[data-paint-tool='pencil']").getAttribute("aria-pressed")).toBe(
      "false",
    );
  });

  it("hands ASCII Art the drawing, kept first", () => {
    const { el, ports, storage } = mountPaint();
    command(el, "ascii");
    expect(ports.openAscii).toHaveBeenCalled();
    expect(storage.getItem(DRAFT_KEY)).toMatch(/^32:/);
  });
});

describe("its helpers", () => {
  it("reads the tool a key names, Shift for the filled shapes", () => {
    expect(toolForKey({ key: "R", shiftKey: true })).toBe("rect_fill");
    expect(toolForKey({ key: "b", shiftKey: false })).toBe("bucket");
    expect(toolForKey({ key: "q", shiftKey: false })).toBeUndefined();
  });

  it("zooms a drawing to the largest whole size that fits", () => {
    expect(fittingZoom(32, 400, 300)).toBe(9);
    expect(fittingZoom(128, 100, 100)).toBe(1);
  });
});
