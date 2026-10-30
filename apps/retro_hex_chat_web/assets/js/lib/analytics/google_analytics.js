/**
 * @file Google Analytics: the tag, and what the server reports.
 *
 * Addresses need nothing from here. LiveView navigates with `pushState`, and
 * GA4's enhanced measurement reports every history change as a page view.
 */
import { log } from "../logger";

/** Where an event sent as the page is left waits for the next page. */
export const NEXT_PAGE_KEY = "rhc-analytics-next-page";

/**
 * The measurement id, unless this is somebody's development machine.
 *
 * @param {Window} win - Window-like object.
 * @param {Document} doc - Document-like object.
 * @returns {string | null} The id, or null.
 */
export function measurementId(win, doc) {
  const id = doc.querySelector('meta[name="ga-measurement-id"]')?.content;
  const { hostname, protocol } = win.location;
  const local = hostname === "localhost" || hostname === "127.0.0.1" || protocol === "file:";

  return id && !local ? id : null;
}

/**
 * @param {Window} win - Window-like object.
 * @returns {object[]} Events the last page left for this one.
 */
function takeNextPageEvents(win) {
  try {
    const events = JSON.parse(win.sessionStorage.getItem(NEXT_PAGE_KEY) ?? "[]");
    win.sessionStorage.removeItem(NEXT_PAGE_KEY);
    return events;
  } catch (error) {
    log.warn("analytics: could not read the waiting events", error);
    return [];
  }
}

/**
 * @param {Window} win - Window-like object.
 * @param {object} event - `{ name, params }`.
 * @returns {void}
 */
function leaveForNextPage(win, event) {
  try {
    const waiting = JSON.parse(win.sessionStorage.getItem(NEXT_PAGE_KEY) ?? "[]");
    win.sessionStorage.setItem(NEXT_PAGE_KEY, JSON.stringify([...waiting, event]));
  } catch (error) {
    log.warn("analytics: could not keep an event for the next page", error);
  }
}

/**
 * Start measuring this page, if it should be.
 *
 * @param {object} [options]
 * @param {Window} [options.win] - Window-like object.
 * @param {Document} [options.doc] - Document-like object.
 * @returns {boolean} Whether the page is measured.
 */
export function installAnalytics({ win = window, doc = document } = {}) {
  const id = measurementId(win, doc);
  if (!id) return false;

  win.dataLayer = win.dataLayer ?? [];
  // gtag.js reads an `arguments` object from the queue; an array is ignored.
  win.gtag = function gtag() {
    // eslint-disable-next-line prefer-rest-params
    win.dataLayer.push(arguments);
  };

  win.gtag("js", new Date());
  win.gtag("config", id);

  takeNextPageEvents(win).forEach(({ name, params }) => win.gtag("event", name, params));

  win.addEventListener("phx:analytics", ({ detail: { name, params, next_page: nextPage } }) => {
    if (nextPage) leaveForNextPage(win, { name, params });
    else win.gtag("event", name, params);
  });

  win.addEventListener("phx:analytics_user", ({ detail: { member, user_id: userId } }) => {
    if (userId) win.gtag("set", { user_id: String(userId) });
    win.gtag("set", "user_properties", { member });
  });

  const script = doc.createElement("script");
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(id)}`;
  doc.head.appendChild(script);

  return true;
}
