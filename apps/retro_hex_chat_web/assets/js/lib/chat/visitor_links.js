/**
 * Which links a visitor — somebody reading the chat without an account — may
 * follow, and what the ones they may not would have opened.
 *
 * A visitor reads; everything else asks them to sign in, and a link is no
 * exception: a game, a call, a space, an attachment, a site somebody pasted.
 * The server gates every event, but a link is the browser's to follow, so the
 * hook that uses this holds each one back and asks the server to explain.
 *
 * What stays open is short and decided by the server: help, the language
 * switch, the public pages and the chat itself. It arrives as a list of paths
 * on the hook's element. Every other address — any other path of ours, any
 * other site — is held, however it was clicked: a modified click, a middle
 * click and the context menu's "open in new tab" all leave just the same.
 *
 * All of it is pure — an element, an origin, a list in, an answer out — so it is
 * tested without a browser or a LiveView.
 */

// The feature a path of ours belongs to, for the sentence the sign-in window
// shows. Anything else — another path, another site — is a link.
const FEATURES = [
  ["/play", "games"],
  ["/call/", "calls"],
  ["/space/", "space"],
  ["/p2p/", "p2p"],
  ["/lobby/", "p2p"],
];

/**
 * The open paths, from the JSON the server rendered. Unreadable means none are
 * open, which errs on the side the visitor can recover from: asking to sign in.
 *
 * @param {string|undefined} raw
 * @returns {string[]}
 */
export function parseAllow(raw) {
  if (typeof raw !== "string" || raw.trim() === "") return [];

  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((p) => typeof p === "string") : [];
  } catch {
    // Not a list the server wrote. Holding every link is the safe reading of a
    // broken allow-list, and the visitor sees the sign-in window, not an error.
    return [];
  }
}

/**
 * What a visitor's click on `target` would open and must not, or null when it
 * may go ahead.
 *
 * @param {EventTarget} target the event target
 * @param {string} origin this site's origin
 * @param {string[]} allow the open paths
 * @returns {{feature: string}|null}
 */
export function blockedLink(target, origin, allow) {
  const anchor = linkAnchor(target);
  if (!anchor) return null;

  const href = anchor.getAttribute("href");
  if (!href || href.startsWith("#")) return null;

  const url = absoluteUrl(href, origin);
  if (!url) return null;

  if (url.origin === origin && openPath(url.pathname, allow)) return null;

  return { feature: featureOf(url, origin) };
}

function linkAnchor(target) {
  if (!target || typeof target.closest !== "function") return null;
  return target.closest("a[href]");
}

/**
 * Whether a path of ours is open to a visitor. An entry ending in `/` opens
 * everything under it; any other opens exactly itself — so `/chat` opens the
 * chat and not its attachments. `/` is the home page, never everything.
 */
export function openPath(pathname, allow) {
  return allow.some((entry) => {
    if (entry !== "/" && entry.endsWith("/")) return pathname.startsWith(entry);
    return pathname === entry;
  });
}

function featureOf(url, origin) {
  if (url.origin !== origin) return "links";

  const match = FEATURES.find(([prefix]) => url.pathname.startsWith(prefix));
  return match ? match[1] : "links";
}

function absoluteUrl(href, origin) {
  try {
    return new URL(href, origin);
  } catch {
    // Not an address the browser can follow either, so there is nothing to hold.
    return null;
  }
}
