/**
 * @file Decides whether — and when — to fetch the Grafana Faro SDK.
 *
 * The SDK is 262 KB (83 KB gzipped), larger than the app bundle. Importing it
 * statically meant every page view downloaded, parsed and ran it even with
 * `faro-enabled` set to `false`, and it competed for bandwidth with `app.js`
 * during exactly the window that decides LCP — 2201 ms for `app.js` alone in
 * the 2026-08-20 load test, against an element_render_delay of 2182 ms.
 *
 * So the gate runs first, on config alone, and the import only happens after
 * it passes and the page has gone idle. Nothing is lost by waiting: web-vitals
 * and document-load both read buffered `PerformanceObserver` entries, which
 * survive a late boot. Errors do not, so they are buffered here and handed
 * over when the SDK arrives.
 */
import { rumEligible } from "./faro";

/**
 * How many pre-boot errors to keep. Enough for a page that breaks on load,
 * bounded so a crash loop cannot grow the buffer without limit.
 */
export const MAX_BUFFERED_ERRORS = 20;

/** How long to wait for idle before loading anyway. */
const IDLE_TIMEOUT_MS = 4000;

/**
 * Arrange for the Faro SDK to load, if this page should have RUM at all.
 *
 * @param {object} options
 * @param {Window} options.win - Window-like object.
 * @param {Document} options.doc - Document-like object.
 * @param {() => Promise<{ api?: { pushError?: (error: Error) => void } } | null>} options.load
 *   Imports and boots the SDK. Called at most once, and only if the gate passes.
 * @returns {{ scheduled: boolean }} Whether the SDK will be fetched.
 */
export function scheduleRum({ win, doc, load }) {
  if (!rumEligible(win, doc)) return { scheduled: false };

  const buffer = [];
  let overflowed = 0;
  let woken = false;

  const capture = (error) => {
    if (!error) return;

    if (buffer.length >= MAX_BUFFERED_ERRORS) {
      overflowed += 1;
      return;
    }

    buffer.push(error);
  };

  const onError = (event) => capture(event?.error ?? event);
  const onRejection = (event) => capture(event?.reason ?? event);

  win.addEventListener("error", onError);
  win.addEventListener("unhandledrejection", onRejection);

  const wake = async () => {
    if (woken) return;
    woken = true;

    win.removeEventListener("error", onError);
    win.removeEventListener("unhandledrejection", onRejection);

    try {
      const faro = await load();
      drain(faro, buffer, overflowed);
    } catch (error) {
      console.error("[faro] SDK failed to load; this page has no RUM", error);
    }
  };

  scheduleWake(win, wake);

  return { scheduled: true };
}

/**
 * Hand the buffered errors to the SDK, and account for any that were dropped.
 *
 * @param {{ api?: { pushError?: (error: Error) => void } } | null} faro - Booted SDK, if it started.
 * @param {Error[]} buffer - Errors captured before the SDK arrived.
 * @param {number} overflowed - How many were dropped past the cap.
 */
function drain(faro, buffer, overflowed) {
  const pushError = faro?.api?.pushError;

  if (overflowed > 0) {
    console.warn(`[faro] dropped ${overflowed} error(s) captured before the SDK loaded`);
  }

  if (typeof pushError !== "function") {
    if (buffer.length > 0) {
      console.warn(`[faro] ${buffer.length} early error(s) went unreported: RUM did not start`);
    }

    return;
  }

  buffer.forEach((error) => pushError.call(faro.api, error));
  buffer.length = 0;
}

/**
 * Run `wake` once the page has nothing better to do.
 *
 * @param {Window} win - Window-like object.
 * @param {() => void} wake - Callback to run.
 */
function scheduleWake(win, wake) {
  if (typeof win.requestIdleCallback === "function") {
    win.requestIdleCallback(wake, { timeout: IDLE_TIMEOUT_MS });
    return;
  }

  // Safari has no requestIdleCallback. `load` is the closest honest signal
  // that the critical resources are in, and the timeout covers a page that
  // never fires it.
  win.addEventListener("load", wake, { once: true });
  win.setTimeout(wake, IDLE_TIMEOUT_MS);
}
