/**
 * The `<head>` of the one desktop, kept in step with the window in front.
 *
 * Moving between pages of the site is a LiveView patch, and a patch never
 * re-renders the root layout — so the description, canonical address and
 * robots a page names would stay those of the page the reader arrived at. A
 * crawler always loads an address whole and never sees this; a reader sharing
 * or bookmarking the page they moved to does, and this is for them.
 */

/** Rewrite the head's description, canonical link and robots to `head`. */
export function applyHead(doc, head) {
  if (!doc || !head) return;

  setMeta(doc, 'meta[name="description"]', head.description);
  setMeta(doc, 'meta[property="og:description"]', head.description);
  setMeta(doc, 'meta[name="twitter:description"]', head.description);
  setMeta(doc, 'meta[name="robots"]', head.robots);
  setMeta(doc, 'meta[property="og:url"]', head.canonical);

  const canonical = doc.querySelector('link[rel="canonical"]');
  if (canonical && typeof head.canonical === "string") {
    canonical.setAttribute("href", head.canonical);
  }
}

function setMeta(doc, selector, value) {
  const el = doc.querySelector(selector);
  if (el && typeof value === "string") el.setAttribute("content", value);
}
