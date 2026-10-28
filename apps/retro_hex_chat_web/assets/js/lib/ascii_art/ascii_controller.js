/**
 * ASCII Art's window, in the browser: what the art is made from (text, a
 * picture, or the Hex Paint drawing), the preview drawn in the chat's own
 * colours, and the message it becomes.
 *
 * The controls are the page's; this reads them whenever one changes, makes
 * the cells again and draws them. A picture is read here and never leaves
 * the browser: only the text art made from it is posted.
 *
 * @module ascii_art/ascii_controller
 */
import { log } from "../logger.js";
import { CLEAR, decode } from "../paint/document.js";
import { DRAFT_KEY } from "../paint/paint_controller.js";
import { chooseSwatch, readPalette, showCurrent } from "../paint/palette.js";
import { banner } from "./banner.js";
import { width } from "./cells.js";
import { encode } from "./encode.js";
import { FROM_PAINT_EVENT, FROM_PAINT_KEY } from "./hand_off.js";
import { fromDrawing, fromImage } from "./image.js";

// A picture is shrunk to this many pixels across before it is read: plenty
// for a hundred columns, and quick to read on a phone.
const READ_WIDTH = 200;

/** Cells drawn as the chat draws a block of art: a `pre` of coloured spans. */
export function renderCells(doc, rows) {
  const pre = doc.createElement("pre");
  pre.className = "irc-art";
  rows.forEach((row, r) => {
    if (r > 0) pre.append("\n");
    for (const c of row) {
      if (c.fg === null && c.bg === null) {
        pre.append(c.ch);
        continue;
      }
      const span = doc.createElement("span");
      if (c.fg !== null) span.classList.add(`irc-fg-${c.fg}`);
      if (c.bg !== null) span.classList.add(`irc-bg-${c.bg}`);
      span.textContent = c.ch;
      pre.append(span);
    }
  });
  return pre;
}

/**
 * A picture file's pixels, shrunk to `READ_WIDTH` across, or null.
 * @returns {Promise<{ data: Uint8ClampedArray, width: number, height: number } | null>}
 */
export async function readPicture(doc, file) {
  const view = doc.defaultView;
  const bitmap = await view.createImageBitmap(file);
  const scale = Math.min(1, READ_WIDTH / bitmap.width);
  const canvas = doc.createElement("canvas");
  canvas.width = Math.max(1, Math.round(bitmap.width * scale));
  canvas.height = Math.max(1, Math.round(bitmap.height * scale));
  const ctx = canvas.getContext("2d");
  if (!ctx) return null;
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close?.();
  const { data } = ctx.getImageData(0, 0, canvas.width, canvas.height);
  return { data, width: canvas.width, height: canvas.height };
}

/**
 * The controls are read by name — `ascii-text`, `ascii-style`, `ascii-scheme`,
 * `ascii-mode` (the chosen option of each select), `ascii-columns`, `ascii-file`
 * — and the tab that opens says what the art is made from (`ascii:source`).
 *
 * @param {HTMLElement} el - the hook root, with the controls and the preview inside
 * @param {object} ports
 * @param {(name: string, text: string) => void} ports.status
 * @param {(art: string) => void} ports.post - hands the message to the window's island
 * @param {(text: string) => Promise<void>} ports.copy
 * @param {() => Storage | null} [ports.storage] - local, where Hex Paint keeps its draft
 * @param {() => Storage | null} [ports.session] - per tab, where Hex Paint leaves word
 * @param {(file: File) => Promise<object | null>} [ports.readPicture]
 */
export function createAsciiArt(el, ports) {
  const doc = el.ownerDocument;
  const preview = el.querySelector("[data-ascii-preview]");
  const read = ports.readPicture ?? ((file) => readPicture(doc, file));
  let picture = null;
  let colours = { fg: 4, bg: 1 };
  let source = "text";
  let rows = [];

  const field = (name) => el.querySelector(`[name='ascii-${name}']`);
  // A select's choice is its checked option; any other control is its value.
  const value = (name) =>
    el.querySelector(`[name='ascii-${name}']:checked`)?.value ?? field(name)?.value ?? "";

  function stored(port, key, remove = false) {
    try {
      const storage = port?.();
      const kept = storage?.getItem(key) ?? null;
      if (remove) storage?.removeItem(key);
      return kept;
    } catch (error) {
      log.debug(`[AsciiArt] ${key} could not be read`, error);
      return null;
    }
  }

  function make() {
    switch (source) {
      case "image":
        return picture
          ? fromImage(picture, {
              columns: Number(value("columns")) || 60,
              mode: value("mode") === "ramp" ? "ramp" : "colour",
              palette: readPalette(el),
            })
          : [];
      case "paint": {
        const drawing = decode(stored(ports.storage, DRAFT_KEY));
        return drawing ? fromDrawing(drawing, CLEAR) : [];
      }
      default:
        return banner(value("text"), {
          style: value("style") || "block",
          scheme: value("scheme") || "single",
          fg: colours.fg,
          bg: colours.bg,
        });
    }
  }

  const blank = "\u00a0";

  function update() {
    rows = make();
    preview?.replaceChildren(renderCells(doc, rows));
    ports.status("size", rows.length === 0 ? blank : `${width(rows)}×${rows.length}`);
    showCurrent(el, colours);
  }

  function onSource(event) {
    source = event.detail?.source ?? "text";
    update();
  }

  // Opening the tab runs its own commands: the tab shown, then `ascii:source`.
  function choose(name) {
    const tab = el.querySelector(`.tabs-trigger[data-target='${name}']`);
    if (tab) tab.click();
    else onSource({ detail: { source: name } });
  }

  async function onChange(event) {
    if (event.target.matches?.("[name='ascii-file']")) {
      const file = event.target.files?.[0];
      try {
        picture = file ? await read(file) : null;
      } catch (error) {
        log.warn("[AsciiArt] the picture could not be read", error);
        picture = null;
        ports.status("size", " ");
      }
    }
    update();
  }

  function onSwatch(event) {
    const next = chooseSwatch(event, colours);
    if (!next) return;
    colours = next;
    update();
  }

  const commands = {
    post: () => rows.length && ports.post(encode(rows)),
    copy: () => rows.length && ports.copy(encode(rows)),
    clear: () => {
      const text = field("text");
      if (text) text.value = "";
      picture = null;
      const file = field("file");
      if (file) file.value = "";
      update();
    },
  };

  function onCommand(event) {
    const name = event.detail?.command;
    Promise.resolve(commands[name]?.()).catch((error) =>
      log.error(`[AsciiArt] ${name} failed`, error),
    );
  }

  const onFromPaint = () => choose("paint");

  return {
    mount() {
      el.addEventListener("input", onChange);
      el.addEventListener("change", onChange);
      el.addEventListener("click", onSwatch);
      el.addEventListener("contextmenu", onSwatch);
      el.addEventListener("ascii:command", onCommand);
      el.addEventListener("ascii:source", onSource);
      doc.addEventListener(FROM_PAINT_EVENT, onFromPaint);
      if (stored(ports.session, FROM_PAINT_KEY, true)) choose("paint");
      else update();
    },
    /** The message the art makes now, for a test. */
    message: () => encode(rows),
    destroy() {
      el.removeEventListener("input", onChange);
      el.removeEventListener("change", onChange);
      el.removeEventListener("click", onSwatch);
      el.removeEventListener("contextmenu", onSwatch);
      el.removeEventListener("ascii:command", onCommand);
      el.removeEventListener("ascii:source", onSource);
      doc.removeEventListener(FROM_PAINT_EVENT, onFromPaint);
    },
  };
}
