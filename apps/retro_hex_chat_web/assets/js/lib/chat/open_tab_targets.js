/**
 * What a click on a link is about to open, and whether it leaves this site.
 *
 * The hook that uses this does nothing but bind a listener and push what comes
 * back, so every decision lives here: which anchors are gated, what kind of
 * destination each one is, and the host to show the reader when it is somewhere
 * else. All of it is pure — an anchor, an origin, and a string out — so it is
 * tested without a browser or a LiveView.
 *
 * Two families of anchor are gated, and nothing else:
 *
 *   - `a[data-confirm-tab]` — a door the server marked. The attribute value is
 *     the kind, and the absence of the attribute is the allowlist: a link that
 *     carries none is a link that was decided not to warn (help, the project's
 *     own GitHub entries), and that reads as a decision rather than an
 *     oversight.
 *   - `a.chat-link[data-url]` — a link inside message content. Both server-side
 *     renderers already stamp this pair on every URL a message carries
 *     (`URLDetector` and the Markdown hardener), so message links need no
 *     marking of their own and the domain needed no change.
 *
 * A modified click is left alone deliberately. Ctrl/Cmd/Shift-click, and the
 * middle click that never fires a `click` event at all, are a reader explicitly
 * asking for a tab — warning them that they are about to get what they just
 * asked for is noise. So is a click the page already handled.
 */

const GATED_SELECTOR = "a[data-confirm-tab], a.chat-link[data-url]";
const KINDS = ["surface", "attachment", "external"];

/**
 * The anchor a click should be gated on, or null.
 *
 * @param {EventTarget} target the event target
 * @returns {HTMLAnchorElement|null}
 */
export function gatedAnchor(target) {
  if (!target || typeof target.closest !== "function") return null;
  return target.closest(GATED_SELECTOR);
}

/**
 * Whether this click carries a modifier that already means "open a tab".
 *
 * @param {MouseEvent} event
 * @returns {boolean}
 */
export function modifiedClick(event) {
  if (!event) return false;
  if (typeof event.button === "number" && event.button !== 0) return true;
  return Boolean(event.ctrlKey || event.metaKey || event.shiftKey || event.altKey);
}

/**
 * What the dialog needs to describe a destination, or null when there is
 * nothing openable here.
 *
 * `origin` is passed in rather than read from `window` so the classification can
 * be tested against a site other than the test runner's own.
 *
 * @param {HTMLAnchorElement} anchor the gated anchor
 * @param {string} origin the current site's origin
 * @returns {{url: string, kind: string, label: string|null, host: string|null}|null}
 */
export function describeTarget(anchor, origin) {
  if (!anchor) return null;

  const url = rawUrl(anchor);
  if (!url) return null;

  const absolute = absoluteUrl(url, origin);
  if (!absolute) return null;

  const offSite = isExternal(absolute, origin);
  const declared = declaredKind(anchor);

  return {
    url,
    // Off-site by address, or declared so by a door that knows something the
    // address does not: the arcade's own path is ours and redirects to the
    // static host the WASM bundle lives on, so the URL says "surface" about a
    // click that genuinely leaves.
    kind: offSite || declared === "external" ? "external" : declared || "surface",
    label: presence(anchor.dataset.confirmLabel),
    // Only ever the host we actually resolved. A declared-external link of ours
    // has none to give — where that redirect lands is a deployment detail — and
    // inventing one would be the dialog lying about the destination.
    host: offSite ? absolute.host : null,
    ...deferred(anchor),
  };
}

/**
 * The click the door was going to make, held back until the reader confirms.
 *
 * A door can be more than a link: the arcade's Start Game both follows an
 * address and tells the server a game began. Swallowing the first click would
 * swallow that too, and letting it through would start a game the reader then
 * cancelled. So the anchor declares it, the dialog replays it on confirm, and
 * cancelling leaves nothing behind.
 *
 * This grants nothing: a LiveView client can already push any event it likes
 * over its own socket, so naming one here is a convenience for the template, not
 * a new capability.
 */
function deferred(anchor) {
  const event = presence(anchor.dataset.confirmEvent);
  if (!event) return {};

  return { event, params: parseParams(anchor.dataset.confirmParams) };
}

function parseParams(raw) {
  if (!presence(raw)) return {};

  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  } catch {
    // A template wrote something that is not an object. The event still fires;
    // it fires without values, which is the same thing a missing
    // `phx-value-*` would have done.
    return {};
  }
}

/**
 * The address the anchor points at, as the markup spells it.
 *
 * `data-url` is preferred over `href` for a message link because it is the
 * value the server put there, untouched by the browser's own normalisation of
 * the `href` property.
 */
function rawUrl(anchor) {
  return presence(anchor.dataset.url) || presence(anchor.getAttribute("href"));
}

/**
 * The kind the door declared, or null when it declared nothing recognisable.
 *
 * A message link declares nothing, and an unknown value is treated the same way:
 * the caller settles on `surface`, the kind whose copy claims the least, so a
 * typo in a template cannot make a link announce itself as something it is not.
 */
function declaredKind(anchor) {
  const declared = anchor.dataset.confirmTab;
  return KINDS.includes(declared) ? declared : null;
}

/**
 * Whether an address leaves this site.
 *
 * Compared on the parsed origin and never on a prefix: `https://example.evil.com`
 * starts with the name of `https://example.com` and is not it. A relative URL
 * resolves against our own origin and is therefore never external.
 */
function isExternal(absolute, origin) {
  return absolute.origin !== origin;
}

function absoluteUrl(url, origin) {
  try {
    return new URL(url, origin);
  } catch {
    // Not an address the browser can parse, so there is nothing to warn about
    // and nothing to open. Silent on purpose: this is a click on markup, not an
    // operation that failed.
    return null;
  }
}

function presence(value) {
  return typeof value === "string" && value.trim() !== "" ? value : null;
}
