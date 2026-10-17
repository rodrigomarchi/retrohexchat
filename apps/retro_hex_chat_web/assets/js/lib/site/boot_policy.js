/**
 * When the desktop's LiveSocket starts.
 *
 * The page in front is server-rendered and complete, so a reader of a page of
 * the site — and a crawler, which never interacts — has everything it came for
 * from the first bundle. The chat behind it (and the socket it needs) starts:
 *
 *   - at once when the address is the chat's own, or a window that does nothing
 *     without it — a channel, sign-in, an invitation, a member's desktop
 *     (`<html data-boot="now">`, decided by the server);
 *   - at once for a reader of the home, whose chat is what the home shows
 *     (`<html data-boot="reader">`) — but a crawler there indexes the home's
 *     own words, not the conversation, so it waits like on any other page;
 *   - otherwise on the reader's first interaction, or when the browser is idle
 *     after load, whichever comes first;
 *   - never while the tab is hidden: a background tab waits until it is shown;
 *   - never by itself for a crawler: one renders the page to index it, and what
 *     it indexes is the page, not the conversation going on behind it.
 *
 * Pure apart from the `win`/`doc` it is handed, so it is tested without a page.
 */

export const INTERACTIONS = ["pointerdown", "keydown", "focusin", "touchstart", "wheel"];
export const IDLE_TIMEOUT_MS = 2000;

const CRAWLER = /bot|crawl|spider|slurp|bingpreview|facebookexternalhit/i;

/**
 * "now", "deferred", or "interaction" — from the server's hint on <html>, and
 * for a crawler on a page of the site, only when somebody actually acts.
 */
export function bootMode(html, userAgent = "") {
  const hint = html?.dataset?.boot;
  if (hint === "now") return "now";
  if (CRAWLER.test(userAgent)) return "interaction";
  return hint === "reader" ? "now" : "deferred";
}

/**
 * Calls `boot` once, at the moment the policy above picks. Returns a function
 * that cancels whatever is still pending.
 */
export function scheduleBoot({ mode, boot, win = window, doc = document }) {
  let done = false;
  const cleanups = [];

  const fire = () => {
    if (done) return;
    if (doc.visibilityState === "hidden") return waitUntilVisible();
    done = true;
    cancel();
    boot();
  };

  const waitUntilVisible = () => {
    const onVisible = () => {
      if (doc.visibilityState !== "hidden") fire();
    };
    doc.addEventListener("visibilitychange", onVisible);
    cleanups.push(() => doc.removeEventListener("visibilitychange", onVisible));
  };

  const cancel = () => cleanups.splice(0).forEach((cleanup) => cleanup());

  if (mode === "now") {
    fire();
    return cancel;
  }

  for (const type of INTERACTIONS) {
    win.addEventListener(type, fire, { capture: true, passive: true, once: true });
    cleanups.push(() => win.removeEventListener(type, fire, { capture: true }));
  }

  const whenIdle = () => {
    if (typeof win.requestIdleCallback === "function") {
      const handle = win.requestIdleCallback(fire, { timeout: IDLE_TIMEOUT_MS });
      cleanups.push(() => win.cancelIdleCallback?.(handle));
    } else {
      const handle = win.setTimeout(fire, IDLE_TIMEOUT_MS);
      cleanups.push(() => win.clearTimeout(handle));
    }
  };

  if (mode === "interaction") return cancel;

  if (doc.readyState === "complete") {
    whenIdle();
  } else {
    win.addEventListener("load", whenIdle, { once: true });
    cleanups.push(() => win.removeEventListener("load", whenIdle));
  }

  return cancel;
}
