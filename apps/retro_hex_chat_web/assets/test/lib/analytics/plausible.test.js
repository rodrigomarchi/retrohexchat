/**
 * @file Verifies the self-hosted Plausible tracker.
 *
 * Covers payload shape for pageviews and custom events, the sendBeacon
 * preferred path, the fetch fallback, the localhost short-circuit, and
 * the auto-tracking listeners for LiveView navigation and outbound clicks.
 */
import { createPlausibleTracker } from "../../../js/lib/analytics/plausible";

/**
 * Build a stub window object with a controllable location and an
 * EventTarget-backed addEventListener/removeEventListener pair.
 *
 * @param {string} href - Initial value of `location.href`.
 * @returns {{ win: any, dispatch: (type: string, detail?: any) => void }}
 */
function makeWin(href) {
  const url = new URL(href);
  const target = new EventTarget();
  const win = {
    location: {
      get href() {
        return url.href;
      },
      hostname: url.hostname,
      host: url.host,
      protocol: url.protocol,
    },
    addEventListener: target.addEventListener.bind(target),
    removeEventListener: target.removeEventListener.bind(target),
    _setHref(next) {
      const u = new URL(next);
      url.href = u.href;
    },
  };
  return {
    win,
    dispatch: (type, detail) => target.dispatchEvent(new CustomEvent(type, { detail })),
  };
}

/**
 * Build a stub document that records click handlers and exposes a
 * `dispatchClick` helper to simulate anchor clicks.
 *
 * @param {string} [referrer]
 * @returns {{ doc: any, dispatchClick: (href: string) => void }}
 */
function makeDoc(referrer = "") {
  const target = new EventTarget();
  const doc = {
    referrer,
    addEventListener: target.addEventListener.bind(target),
    removeEventListener: target.removeEventListener.bind(target),
  };
  return {
    doc,
    dispatchClick: (href) => {
      const anchor = document.createElement("a");
      anchor.href = href;
      const event = new Event("click");
      Object.defineProperty(event, "target", {
        value: anchor,
        configurable: true,
      });
      target.dispatchEvent(event);
    },
  };
}

describe("createPlausibleTracker", () => {
  it("requires a domain", () => {
    expect(() => createPlausibleTracker({ domain: "" })).toThrow(/domain/);
  });

  it("posts a pageview via sendBeacon with the configured domain", () => {
    const { win } = makeWin("https://moon.retrohexchat.app/v2/lobby");
    const { doc } = makeDoc("https://t.co/abc");
    const sendBeacon = vi.fn().mockReturnValue(true);

    const tracker = createPlausibleTracker({
      domain: "moon.retrohexchat.app",
      win,
      doc,
      sendBeacon,
    });

    tracker.trackPageview({ surface: "lobby" });

    expect(sendBeacon).toHaveBeenCalledTimes(1);
    const [url, blob] = sendBeacon.mock.calls[0];
    expect(url).toBe("/api/event");
    expect(blob.type).toBe("application/json");
  });

  it("falls back to fetch when sendBeacon is unavailable", async () => {
    const { win } = makeWin("https://moon.retrohexchat.app/");
    const { doc } = makeDoc();
    const fetchImpl = vi.fn().mockResolvedValue(new Response(null));

    const tracker = createPlausibleTracker({
      domain: "moon.retrohexchat.app",
      win,
      doc,
      sendBeacon: null,
      fetch: fetchImpl,
    });

    tracker.trackEvent("Room: Join", { room: "general" });

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [endpoint, init] = fetchImpl.mock.calls[0];
    expect(endpoint).toBe("/api/event");
    expect(init.method).toBe("POST");
    expect(init.keepalive).toBe(true);
    const body = JSON.parse(init.body);
    expect(body).toMatchObject({
      name: "Room: Join",
      domain: "moon.retrohexchat.app",
      url: "https://moon.retrohexchat.app/",
      props: { room: "general" },
    });
  });

  it("does not send when running on localhost", () => {
    const { win } = makeWin("http://localhost:4000/");
    const { doc } = makeDoc();
    const sendBeacon = vi.fn();
    const fetchImpl = vi.fn();

    const tracker = createPlausibleTracker({
      domain: "moon.retrohexchat.app",
      win,
      doc,
      sendBeacon,
      fetch: fetchImpl,
    });

    tracker.trackPageview();
    tracker.trackEvent("Room: Join");

    expect(sendBeacon).not.toHaveBeenCalled();
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it("attachAutoTracking fires pageviews on patch/redirect with URL change", () => {
    const { win, dispatch } = makeWin("https://moon.retrohexchat.app/");
    const { doc } = makeDoc();
    const sendBeacon = vi.fn().mockReturnValue(true);

    const tracker = createPlausibleTracker({
      domain: "moon.retrohexchat.app",
      win,
      doc,
      sendBeacon,
    });

    const detach = tracker.attachAutoTracking();
    expect(sendBeacon).toHaveBeenCalledTimes(1); // initial pageview

    // Same URL → dedup, no new pageview.
    dispatch("phx:page-loading-stop", { kind: "patch" });
    expect(sendBeacon).toHaveBeenCalledTimes(1);

    // Different URL → pageview.
    win._setHref("https://moon.retrohexchat.app/v2/lobby");
    dispatch("phx:page-loading-stop", { kind: "redirect" });
    expect(sendBeacon).toHaveBeenCalledTimes(2);

    // Non-tracked kind (initial mount) → ignored.
    win._setHref("https://moon.retrohexchat.app/v2/other");
    dispatch("phx:page-loading-stop", { kind: "initial" });
    expect(sendBeacon).toHaveBeenCalledTimes(2);

    detach();
  });

  it("attachAutoTracking emits Outbound Link: Click for cross-host anchors", () => {
    const { win } = makeWin("https://moon.retrohexchat.app/");
    const { doc, dispatchClick } = makeDoc();
    // Use the fetch fallback so we can inspect the body as a string without
    // Blob-text APIs that vary by jsdom version.
    const fetchImpl = vi.fn().mockResolvedValue(new Response(null));

    const tracker = createPlausibleTracker({
      domain: "moon.retrohexchat.app",
      win,
      doc,
      sendBeacon: null,
      fetch: fetchImpl,
    });

    const detach = tracker.attachAutoTracking();
    fetchImpl.mockClear(); // drop the initial pageview

    dispatchClick("https://github.com/rodrigomarchi");
    dispatchClick("https://moon.retrohexchat.app/internal"); // same host → ignored
    dispatchClick("mailto:hi@example.com"); // non-http → ignored

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [, init] = fetchImpl.mock.calls[0];
    const payload = JSON.parse(init.body);
    expect(payload.name).toBe("Outbound Link: Click");
    expect(payload.props.url).toBe("https://github.com/rodrigomarchi");
    detach();
  });
});
