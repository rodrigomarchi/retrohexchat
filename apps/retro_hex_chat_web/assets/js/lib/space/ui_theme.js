/**
 * The colours and font the canvas draws its UI text with, read from the CSS.
 *
 * The space's pixel-art kit keeps its palette in `features/space-ui.css`, as
 * custom properties on `.space-ui`; the canvas cannot inherit them the way the
 * DOM does, so it reads them once from the element it draws in. A value the
 * page does not define (a test, a page outside the kit) keeps the caller's
 * fallback.
 * @module space/ui_theme
 */

const PROPERTIES = Object.freeze({
  bubbleInk: "--space-ui-bubble-ink",
  labelInk: "--space-ui-label-ink",
  signInk: "--space-ui-sign-ink",
  damage: "--space-ui-damage",
  damageKo: "--space-ui-damage-ko",
  damageOutline: "--space-ui-damage-outline",
  hologramInk: "--space-ui-hologram-ink",
});

// The pixel font is drawn at its design size, one font pixel per canvas pixel.
export const UI_FONT_PX = 12;

/**
 * @param {Element|null|undefined} el an element inside the `.space-ui` page
 * @param {Record<string, string>} fallback a colour per theme key, and `family`
 * @returns {{font: string, family: string} & Record<string, string>}
 */
export function readUiTheme(el, fallback) {
  // A stand-in canvas (a test, a detached element) has no style to read.
  const isElement = typeof Element !== "undefined" && el instanceof Element;
  const style = isElement ? getComputedStyle(el) : null;
  const read = (prop) => style?.getPropertyValue(prop)?.trim() || "";
  const theme = {};
  for (const [key, prop] of Object.entries(PROPERTIES)) {
    theme[key] = read(prop) || fallback[key];
  }
  theme.family = read("font-family") || fallback.family;
  theme.font = `${UI_FONT_PX}px ${theme.family}`;
  return theme;
}
