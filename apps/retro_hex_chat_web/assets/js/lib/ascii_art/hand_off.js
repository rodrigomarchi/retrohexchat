/**
 * Hex Paint opening ASCII Art on its drawing. The drawing is already in the
 * draft Hex Paint keeps; what ASCII Art needs is word to start from it — left
 * in this tab's storage for a window that is about to mount, and sent as an
 * event to one that is already open.
 *
 * @module ascii_art/hand_off
 */
import { log } from "../logger.js";

/** Word left for ASCII Art in this tab's storage; read once. */
export const FROM_PAINT_KEY = "retrohex.ascii.from_paint";

/** The event that tells an open ASCII Art window. */
export const FROM_PAINT_EVENT = "ascii:from-paint";

/** Leaves word for ASCII Art, then `open()`s its window. */
export function handToAsciiArt(doc, open) {
  try {
    doc.defaultView?.sessionStorage?.setItem(FROM_PAINT_KEY, "1");
  } catch (error) {
    log.debug("[HexPaint] ASCII Art could not be told to start from the drawing", error);
  }
  doc.dispatchEvent(new CustomEvent(FROM_PAINT_EVENT));
  open();
}
