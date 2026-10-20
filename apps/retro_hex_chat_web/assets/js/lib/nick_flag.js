/**
 * The language flag beside a nickname the browser draws itself.
 *
 * The server renders the same mark with `RetroHexChatWeb.Components.UI.NickFlag`;
 * a name written by JS (a conference tile) gets it from here, with the same
 * classes, tooltip and test hooks, so the two cannot be told apart. The server
 * sends what the mark needs — `{locale, language, href}`, `href` pointing into
 * the icon sprite — so this module never maps a locale to an icon itself.
 *
 * The flag sits immediately before the nickname element, never inside it: the
 * nickname's text is an address and is rewritten on its own.
 *
 * @module nick_flag
 */

const SVG_NS = "http://www.w3.org/2000/svg";

/**
 * Whether a payload describes a flag that can be drawn.
 *
 * @param {object|null|undefined} flag
 * @returns {boolean}
 */
export function drawableFlag(flag) {
  return (
    typeof flag?.locale === "string" &&
    typeof flag?.language === "string" &&
    typeof flag?.href === "string" &&
    flag.href !== ""
  );
}

/**
 * Build the flag element for a payload.
 *
 * @param {Document} doc
 * @param {{locale: string, language: string, href: string}} flag
 * @returns {HTMLSpanElement}
 */
export function buildNickFlag(doc, flag) {
  const span = doc.createElement("span");
  span.className = "rh-nick-flag";
  span.setAttribute("role", "img");
  span.dataset.testid = "nick-flag";
  span.dataset.nickFlag = "";
  applyFlag(span, flag);

  const svg = doc.createElementNS(SVG_NS, "svg");
  svg.setAttribute("class", "rh-nick-flag__icon");
  svg.setAttribute("aria-hidden", "true");
  const use = doc.createElementNS(SVG_NS, "use");
  use.setAttribute("href", flag.href);
  svg.appendChild(use);
  span.appendChild(svg);

  return span;
}

/**
 * Put the right flag before `nameEl`: add it, change it, or take it away.
 *
 * @param {Element|null} nameEl the element holding the nickname text
 * @param {object|null|undefined} flag the server's flag payload, or nothing
 */
export function syncNickFlag(nameEl, flag) {
  if (!nameEl?.parentNode) return;

  const previous = nameEl.previousElementSibling;
  const existing = previous?.matches?.("[data-nick-flag]") ? previous : null;

  if (!drawableFlag(flag)) {
    existing?.remove();
    return;
  }

  if (existing) {
    if (existing.dataset.locale === flag.locale) return;
    existing.remove();
  }

  nameEl.parentNode.insertBefore(buildNickFlag(nameEl.ownerDocument, flag), nameEl);
}

function applyFlag(span, flag) {
  span.dataset.locale = flag.locale;
  span.title = flag.language;
  span.setAttribute("aria-label", flag.language);
}
