const HASH_PREFIX = String.fromCharCode(35);

export function gameColor(token, element = null) {
  const cssColor = readCssGameColor(token, element);
  return cssColor || `${HASH_PREFIX}${token}`;
}

function readCssGameColor(token, element) {
  const target = element || defaultElement();
  if (!target) return "";

  const view = target.ownerDocument?.defaultView || globalThis;
  const getStyle = view.getComputedStyle || globalThis.getComputedStyle;
  if (typeof getStyle !== "function") return "";

  return getStyle(target).getPropertyValue(`--game-color-${token.toLowerCase()}`).trim();
}

function defaultElement() {
  return globalThis.document?.documentElement || null;
}

/**
 * A game's palette, read from the canvas's CSS custom properties.
 * @param {Element} canvas
 * @param {Record<string, [string, string]>} spec - palette key to
 *   `[custom property, fallback]`; a fallback is a palette token (`"0a0a1a"`)
 *   or a literal colour (`"rgba(0,255,204,0.2)"`).
 * @returns {Record<string, string>}
 */
export function readGameColors(canvas, spec) {
  const style = getComputedStyle(canvas);
  const colors = {};
  for (const [key, [property, fallback]] of Object.entries(spec)) {
    colors[key] =
      style.getPropertyValue(property).trim() ||
      (/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(fallback) ? gameColor(fallback) : fallback);
  }
  return colors;
}
