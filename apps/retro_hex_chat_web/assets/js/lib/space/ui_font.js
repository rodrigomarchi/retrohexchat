/**
 * Makes sure the glyphs the canvas is about to draw are loaded.
 *
 * Canvas `fillText` draws with whatever font faces are loaded but, unlike the
 * DOM, never asks for one. The pixel font is cut into faces by script
 * (`unicode-range`), so a bubble in a script nobody has typed yet would draw in
 * the fallback for good. Asking `document.fonts` for the text fetches the face
 * that holds it; the render loop redraws every frame, so the bubble turns pixel
 * the moment it lands. Nothing ever waits on it.
 * @module space/ui_font
 */
import { log } from "../logger.js";

/**
 * @param {FontFaceSet|null|undefined} fonts usually `document.fonts`
 * @param {string} font a CSS font shorthand, e.g. "12px RH Pixel"
 * @returns {{ensure: (text: string) => void}}
 */
export function createGlyphLoader(fonts, font) {
  const asked = new Set();
  return {
    ensure(text) {
      if (!fonts?.load || typeof text !== "string" || !text) return;
      const missing = [...new Set(text)].filter((ch) => !asked.has(ch)).join("");
      if (!missing) return;
      for (const ch of missing) asked.add(ch);
      if (fonts.check?.(font, missing)) return;
      fonts.load(font, missing).catch((error) => {
        log.warn("space: pixel font glyphs did not load", { error: String(error) });
      });
    },
  };
}
