/**
 * Hex Paint's window, in the browser: the drawing on its canvas, the press
 * that paints it, the tools, the two colours, undo and redo, and the draft
 * the browser keeps between visits.
 *
 * The drawing is a value (`document.js`) and every tool answers points
 * (`tools.js`), so this controller only turns presses into strokes and
 * strokes into history. A shape is shown while it is held and recorded once,
 * when it is let go; a pencil records once per stroke too, so one undo takes
 * back one stroke. The sixteen colours are read from the swatches the page
 * draws, so they are exactly the chat's.
 *
 * @module paint/paint_controller
 */
import { contains, toCanvasPoint } from "../games/core/pointer.js";
import { t } from "../i18n.js";
import { log } from "../logger.js";
import { colourAt, createDrawing, decode, encode } from "./document.js";
import { drawOnto, postedScale, toPng } from "./export.js";
import { createHistory, record, redo, undo } from "./history.js";
import { chooseSwatch, readPalette, showCurrent } from "./palette.js";
import { TOOLS, apply, shapeTool } from "./tools.js";

/** Where the browser keeps the drawing between visits; ASCII Art reads it too. */
export const DRAFT_KEY = "retrohex.paint.draft";

const MAX_ZOOM = 24;

const TOOL_NAMES = () => ({
  pencil: t("Pencil"),
  line: t("Line"),
  rect: t("Rectangle"),
  rect_fill: t("Filled rectangle"),
  ellipse: t("Ellipse"),
  ellipse_fill: t("Filled ellipse"),
  bucket: t("Fill"),
  eraser: t("Eraser"),
  picker: t("Pick colour"),
});

/** The tool a key chooses (`p`, `shift+r`…), or undefined. */
export function toolForKey(event) {
  const key = `${event.shiftKey ? "shift+" : ""}${String(event.key).toLowerCase()}`;
  return TOOLS.find((tool) => tool.key === key)?.id;
}

/** The largest whole zoom that fits a drawing of `size` in a box, at least 1. */
export const fittingZoom = (size, width, height) =>
  Math.max(1, Math.min(MAX_ZOOM, Math.floor(Math.min(width, height) / size)));

/**
 * @param {HTMLElement} el - the hook root: tools, swatches and the canvas inside it
 * @param {object} ports
 * @param {(name: string, text: string) => void} ports.status - writes a status field
 * @param {(file: File) => void} ports.post - hands the PNG to the window's upload
 * @param {(blob: Blob, name: string) => void} ports.download
 * @param {() => void} ports.openAscii - opens ASCII Art on this drawing
 * @param {() => Storage | null} [ports.storage] - read when used: it may throw
 * @param {(w: number, h: number) => HTMLCanvasElement} [ports.createCanvas]
 */
export function createPaint(el, ports) {
  const canvas = el.querySelector("[data-paint-canvas]");
  const stage = el.querySelector("#hex-paint-stage") ?? canvas?.parentElement;
  const storage = ports.storage ?? (() => null);
  const createCanvas =
    ports.createCanvas ??
    ((width, height) => Object.assign(el.ownerDocument.createElement("canvas"), { width, height }));

  let history = createHistory(readDraft() ?? createDrawing());
  let palette = readPalette(el);
  let tool = "pencil";
  let colours = { fg: 1, bg: 0 };
  let zoom = 1;
  let grid = true;
  let mirror = false;
  let press = null;

  function readDraft() {
    try {
      return decode(storage()?.getItem(DRAFT_KEY));
    } catch (error) {
      log.debug("[HexPaint] the draft could not be read", error);
      return null;
    }
  }

  function keepDraft() {
    try {
      storage()?.setItem(DRAFT_KEY, encode(history.now));
    } catch (error) {
      log.debug("[HexPaint] the draft could not be kept", error);
    }
  }

  const drawing = () => press?.preview ?? history.now;

  function render() {
    if (!canvas) return;
    const shown = drawing();
    if (!drawOnto(canvas, shown, palette, zoom, createCanvas)) return;
    const ctx = canvas.getContext("2d");
    if (grid && zoom >= 6 && ctx) {
      ctx.strokeStyle = "rgba(128, 128, 128, 0.35)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      for (let i = 1; i < shown.size; i++) {
        ctx.moveTo(i * zoom + 0.5, 0);
        ctx.lineTo(i * zoom + 0.5, canvas.height);
        ctx.moveTo(0, i * zoom + 0.5);
        ctx.lineTo(canvas.width, i * zoom + 0.5);
      }
      ctx.stroke();
    }
  }

  function showStatus(at = null) {
    ports.status("size", `${history.now.size}×${history.now.size}`);
    ports.status("tool", TOOL_NAMES()[tool] ?? tool);
    ports.status("at", at ? `${at[0]}, ${at[1]}` : " ");
  }

  function showChoices() {
    // Drawn sunken by `features/hex-paint.css` from what assistive tech hears.
    for (const button of el.querySelectorAll("[data-paint-tool]")) {
      button.setAttribute("aria-pressed", String(button.dataset.paintTool === tool));
    }
    for (const button of el.querySelectorAll("[data-paint-toggle='mirror']")) {
      button.setAttribute("aria-pressed", String(mirror));
    }
    showCurrent(el, colours);
  }

  function commit(next) {
    const before = history;
    history = record(history, next);
    if (history !== before) keepDraft();
  }

  function fit() {
    const box = stage?.getBoundingClientRect();
    zoom = box ? fittingZoom(history.now.size, box.width - 8, box.height - 8) : 8;
  }

  function pointAt(event) {
    if (!canvas) return null;
    const size = history.now.size;
    const at = toCanvasPoint(
      canvas.getBoundingClientRect(),
      size,
      size,
      event.clientX,
      event.clientY,
      {
        clamp: false,
      },
    );
    return at && [at.x, at.y];
  }

  function onPointerDown(event) {
    if (event.button !== 0 && event.button !== 2) return;
    const at = pointAt(event);
    if (!at || !contains({ x: 0, y: 0, w: history.now.size, h: history.now.size }, at[0], at[1])) {
      return;
    }
    event.preventDefault();
    // The window's keys (undo, the tools) follow the press into it.
    el.focus({ preventScroll: true });
    canvas.setPointerCapture?.(event.pointerId);
    const which = event.button === 2 ? "bg" : "fg";
    if (tool === "picker") {
      colours = { ...colours, [which]: colourAt(history.now, at[0], at[1]) };
      showChoices();
      return;
    }
    press = { from: at, last: at, colour: colours[which], preview: null, painted: history.now };
    paintTo(at);
  }

  function paintTo(at) {
    const options = { tool, colour: press.colour, mirror, to: at };
    if (shapeTool(tool)) {
      press.preview = apply(history.now, { ...options, from: press.from });
    } else if (tool === "bucket") {
      press.preview = apply(history.now, { ...options, from: at });
    } else {
      press.painted = apply(press.painted, { ...options, from: press.last });
      press.preview = press.painted;
    }
    press.last = at;
    render();
  }

  function onPointerMove(event) {
    const at = pointAt(event);
    const size = history.now.size;
    const on = at && contains({ x: 0, y: 0, w: size, h: size }, at[0], at[1]);
    showStatus(on ? at : null);
    if (!press || !at) return;
    if (tool === "bucket") return;
    if (at[0] === press.last[0] && at[1] === press.last[1]) return;
    paintTo(at);
  }

  function onPointerUp() {
    if (!press) return;
    const next = press.preview ?? history.now;
    press = null;
    commit(next);
    render();
  }

  function onPointerCancel() {
    press = null;
    render();
  }

  function onSwatch(event) {
    const next = chooseSwatch(event, colours);
    if (!next) return;
    colours = next;
    showChoices();
  }

  function newDrawing(size) {
    commit(createDrawing(size));
    fit();
    render();
    showStatus();
  }

  async function picture() {
    const blob = await toPng(history.now, palette, postedScale(history.now), createCanvas);
    if (!blob) log.warn("[HexPaint] the page could not make a PNG");
    return blob;
  }

  const commands = {
    new: ({ size }) => newDrawing(Number(size) || history.now.size),
    undo: () => {
      history = undo(history);
      keepDraft();
      render();
    },
    redo: () => {
      history = redo(history);
      keepDraft();
      render();
    },
    clear: () => {
      commit(createDrawing(history.now.size));
      render();
    },
    grid: () => {
      grid = !grid;
      render();
    },
    zoom: ({ by }) => {
      zoom = Math.max(1, Math.min(MAX_ZOOM, zoom + Number(by) * (zoom >= 8 ? 2 : 1)));
      render();
    },
    tool: ({ tool: next }) => {
      if (TOOLS.some((known) => known.id === next)) tool = next;
      showChoices();
      showStatus();
    },
    mirror: () => {
      mirror = !mirror;
      showChoices();
    },
    save: async () => {
      const blob = await picture();
      if (blob) ports.download(blob, `hex-paint-${history.now.size}.png`);
    },
    post: async () => {
      const blob = await picture();
      if (blob) ports.post(new File([blob], `hex-paint-${Date.now()}.png`, { type: "image/png" }));
    },
    ascii: () => {
      keepDraft();
      ports.openAscii();
    },
  };

  function run(name, detail = {}) {
    const command = commands[name];
    if (!command) return;
    Promise.resolve(command(detail)).catch((error) =>
      log.error(`[HexPaint] ${name} failed`, error),
    );
  }

  function onCommand(event) {
    run(event.detail?.command, event.detail ?? {});
  }

  function onKey(event) {
    if (event.target.closest?.("input, textarea, select, [contenteditable='true']")) return;
    const key = String(event.key).toLowerCase();
    // A key the drawing takes stops here: the chat's own shortcuts listen on
    // the window, and Ctrl+Z there is not this undo.
    if ((event.ctrlKey || event.metaKey) && (key === "z" || key === "y")) {
      event.preventDefault();
      event.stopPropagation();
      run(key === "z" && !event.shiftKey ? "undo" : "redo");
      return;
    }
    if (event.ctrlKey || event.metaKey || event.altKey) return;
    const next = toolForKey(event);
    if (next) {
      event.preventDefault();
      event.stopPropagation();
      run("tool", { tool: next });
    }
  }

  const preventMenu = (event) => event.preventDefault();
  const onLeave = () => showStatus();
  const canvasListeners = [
    ["pointerdown", onPointerDown],
    ["pointermove", onPointerMove],
    ["pointerup", onPointerUp],
    ["pointercancel", onPointerCancel],
    ["pointerleave", onLeave],
    ["contextmenu", preventMenu],
  ];

  return {
    mount() {
      if (!canvas) return;
      for (const [type, listener] of canvasListeners) canvas.addEventListener(type, listener);
      el.addEventListener("click", onSwatch);
      el.addEventListener("contextmenu", onSwatch);
      el.addEventListener("paint:command", onCommand);
      el.addEventListener("keydown", onKey);
      fit();
      render();
      showChoices();
      showStatus();
    },
    /** The colours read again, after the page's theme changed. */
    refresh() {
      palette = readPalette(el);
      render();
    },
    /** The drawing now, for a test or another tool. */
    drawing: () => history.now,
    destroy() {
      for (const [type, listener] of canvasListeners) canvas?.removeEventListener(type, listener);
      el.removeEventListener("click", onSwatch);
      el.removeEventListener("contextmenu", onSwatch);
      el.removeEventListener("paint:command", onCommand);
      el.removeEventListener("keydown", onKey);
    },
  };
}
