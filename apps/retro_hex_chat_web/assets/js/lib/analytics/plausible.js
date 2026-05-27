/**
 * @file Self-hosted Plausible analytics tracker.
 *
 * POSTs page-view and custom events to a same-origin `/api/event` path that
 * Nginx proxies to the self-hosted Plausible Community Edition instance.
 * The tracker is dependency-injected so it can be exercised under Vitest +
 * jsdom without touching the real network.
 */

const DEFAULT_ENDPOINT = "/api/event";

/**
 * Build a Plausible tracker bound to a specific site domain.
 *
 * Skips sending when running on localhost/127.0.0.1/file:// so dev traffic
 * does not pollute production stats. Prefers `navigator.sendBeacon` and
 * falls back to `fetch` with `keepalive: true`.
 *
 * @param {object} options - Tracker configuration.
 * @param {string} options.domain - Site domain registered in Plausible.
 * @param {Record<string, unknown>} [options.defaultProps] - Props merged into every event (e.g. `{ env: "prod" }`).
 * @param {string} [options.endpoint] - Events endpoint path or full URL.
 * @param {Window} [options.win] - Window-like object (DI for tests).
 * @param {Document} [options.doc] - Document-like object (DI for tests).
 * @param {((url: string, body: BodyInit) => boolean) | null} [options.sendBeacon] - Beacon sender override.
 * @param {typeof fetch | null} [options.fetch] - Fetch implementation override.
 * @returns {{trackPageview: (props?: Record<string, unknown>) => void, trackEvent: (name: string, props?: Record<string, unknown>) => void, attachAutoTracking: () => () => void}} Tracker API.
 */
export function createPlausibleTracker({
  domain,
  defaultProps = {},
  endpoint = DEFAULT_ENDPOINT,
  win = typeof window === "undefined" ? undefined : window,
  doc = typeof document === "undefined" ? undefined : document,
  sendBeacon = typeof navigator !== "undefined" && navigator.sendBeacon
    ? navigator.sendBeacon.bind(navigator)
    : null,
  fetch: fetchImpl = typeof fetch === "undefined" ? null : fetch,
}) {
  if (!domain) throw new Error("createPlausibleTracker: `domain` is required");
  if (!win || !doc) {
    throw new Error("createPlausibleTracker: window/document not available");
  }

  const { location } = win;
  const isLocal =
    location.hostname === "localhost" ||
    location.hostname === "127.0.0.1" ||
    location.protocol === "file:";

  /**
   * Send a single event payload to the configured endpoint.
   *
   * @param {Record<string, unknown>} payload - JSON-serialisable event body.
   * @returns {void}
   */
  function send(payload) {
    if (isLocal) return;
    const body = JSON.stringify(payload);
    if (sendBeacon) {
      sendBeacon(endpoint, new Blob([body], { type: "application/json" }));
      return;
    }
    if (fetchImpl) {
      fetchImpl(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body,
        keepalive: true,
      }).catch(() => {});
    }
  }

  /**
   * Track a pageview for the current location.
   *
   * @param {Record<string, unknown>} [props] - Optional custom props.
   * @returns {void}
   */
  function trackPageview(props = {}) {
    send({
      name: "pageview",
      url: location.href,
      domain,
      referrer: doc.referrer || null,
      props: { ...defaultProps, ...props },
    });
  }

  /**
   * Track a custom event by name.
   *
   * @param {string} name - Event name (matches a Plausible goal).
   * @param {Record<string, unknown>} [props] - Optional custom props.
   * @returns {void}
   */
  function trackEvent(name, props = {}) {
    send({
      name,
      url: location.href,
      domain,
      props: { ...defaultProps, ...props },
    });
  }

  /**
   * Wire automatic pageview + outbound-link tracking to live LiveView events.
   *
   * Fires an initial pageview, re-fires on `phx:page-loading-stop` for patch
   * or redirect navigations when the URL actually changed (dedup), and emits
   * `"Outbound Link: Click"` events for clicks on cross-host anchors.
   *
   * @returns {() => void} Cleanup function that detaches all listeners.
   */
  function attachAutoTracking() {
    trackPageview();

    let lastTrackedHref = location.href;

    const onPageLoadingStop = (info) => {
      const kind = info && info.detail && info.detail.kind;
      if ((kind === "patch" || kind === "redirect") && location.href !== lastTrackedHref) {
        lastTrackedHref = location.href;
        trackPageview();
      }
    };

    const onClick = (event) => {
      const link = event.target.closest && event.target.closest("a");
      if (!link || !link.href) return;
      try {
        const url = new URL(link.href);
        if (
          url.host &&
          url.host !== location.host &&
          (url.protocol === "http:" || url.protocol === "https:")
        ) {
          trackEvent("Outbound Link: Click", { url: link.href });
        }
      } catch {
        // ignore malformed URLs
      }
    };

    win.addEventListener("phx:page-loading-stop", onPageLoadingStop);
    doc.addEventListener("click", onClick);

    return () => {
      win.removeEventListener("phx:page-loading-stop", onPageLoadingStop);
      doc.removeEventListener("click", onClick);
    };
  }

  return { trackPageview, trackEvent, attachAutoTracking };
}
