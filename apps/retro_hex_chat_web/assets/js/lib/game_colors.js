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
