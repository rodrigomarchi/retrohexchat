/**
 * @file Verifies that the Faro SDK is fetched only when it will be used, and
 * only once the page is done with the network.
 *
 * The SDK is 262 KB (83 KB gzipped) — larger than the app bundle itself. It
 * used to be a static import in the RUM entrypoint, so it downloaded, parsed
 * and executed on every page view even when `faro-enabled` was `false`, and it
 * competed with `app.js` during the window that decides LCP. These cases pin
 * both halves of the fix: the gate runs before any import, and the import is
 * scheduled rather than immediate.
 */
import { scheduleRum, MAX_BUFFERED_ERRORS } from "../../../js/lib/telemetry/faro_gate";

/**
 * Build a stub document whose meta lookups resolve from a plain map.
 *
 * @param {Record<string, string>} metas - Meta name/content pairs.
 * @returns {{ querySelector: (selector: string) => ({ content: string } | null) }}
 */
function makeDoc(metas) {
  return {
    querySelector(selector) {
      const match = selector.match(/^meta\[name="(.+)"\]$/);
      if (!match) return null;
      const name = match[1];
      return name in metas ? { content: metas[name] } : null;
    },
  };
}

const ENABLED = {
  "faro-enabled": "true",
  "faro-collector-url": "/faro/collect",
  "faro-app-version": "0.1.0-abc1234",
};

/**
 * Build a stub window with a controllable location and event plumbing.
 *
 * @param {object} options
 * @param {string} [options.href] - Value backing `location`.
 * @param {boolean} [options.idle] - Whether `requestIdleCallback` exists.
 * @returns {object} A window-like object plus `fire` and `runIdle` helpers.
 */
function makeWin({ href = "https://retrohexchat.app/chat", idle = true } = {}) {
  const url = new URL(href);
  const listeners = {};
  let idleCallback = null;
  let timeoutCallback = null;

  const win = {
    location: { hostname: url.hostname, protocol: url.protocol },
    addEventListener: (name, fn) => {
      (listeners[name] ||= []).push(fn);
    },
    removeEventListener: (name, fn) => {
      listeners[name] = (listeners[name] || []).filter((entry) => entry !== fn);
    },
    setTimeout: (fn) => {
      timeoutCallback = fn;
      return 1;
    },
    clearTimeout: () => {},
    fire: (name, event) => (listeners[name] || []).forEach((fn) => fn(event)),
    listenerCount: (name) => (listeners[name] || []).length,
    runIdle: () => idleCallback?.(),
    runTimeout: () => timeoutCallback?.(),
  };

  if (idle) {
    win.requestIdleCallback = (fn) => {
      idleCallback = fn;
      return 1;
    };
  }

  return win;
}

describe("scheduleRum", () => {
  it("never reaches for the SDK when RUM is disabled", async () => {
    const load = vi.fn();
    const win = makeWin();

    const result = scheduleRum({ win, doc: makeDoc({ "faro-enabled": "false" }), load });
    win.runIdle();

    expect(result.scheduled).toBe(false);
    expect(load).not.toHaveBeenCalled();
  });

  it("never reaches for the SDK on localhost", async () => {
    const load = vi.fn();
    const win = makeWin({ href: "http://localhost:4000/chat" });

    const result = scheduleRum({ win, doc: makeDoc(ENABLED), load });
    win.runIdle();

    expect(result.scheduled).toBe(false);
    expect(load).not.toHaveBeenCalled();
  });

  it("never reaches for the SDK without a collector", async () => {
    const load = vi.fn();
    const win = makeWin();
    const doc = makeDoc({ "faro-enabled": "true" });

    expect(scheduleRum({ win, doc, load }).scheduled).toBe(false);
    expect(load).not.toHaveBeenCalled();
  });

  it("attaches no error listeners when it will not start", () => {
    const win = makeWin();

    scheduleRum({ win, doc: makeDoc({ "faro-enabled": "false" }), load: vi.fn() });

    expect(win.listenerCount("error")).toBe(0);
    expect(win.listenerCount("unhandledrejection")).toBe(0);
  });

  it("waits for idle before importing the SDK", async () => {
    const load = vi.fn().mockResolvedValue(null);
    const win = makeWin();

    const result = scheduleRum({ win, doc: makeDoc(ENABLED), load });

    expect(result.scheduled).toBe(true);
    expect(load).not.toHaveBeenCalled();

    win.runIdle();
    expect(load).toHaveBeenCalledTimes(1);
  });

  it("falls back to a timeout where requestIdleCallback is missing", async () => {
    const load = vi.fn().mockResolvedValue(null);
    const win = makeWin({ idle: false });

    scheduleRum({ win, doc: makeDoc(ENABLED), load });
    expect(load).not.toHaveBeenCalled();

    win.runTimeout();
    expect(load).toHaveBeenCalledTimes(1);
  });

  it("imports the SDK only once, however it is woken", async () => {
    const load = vi.fn().mockResolvedValue(null);
    const win = makeWin();

    scheduleRum({ win, doc: makeDoc(ENABLED), load });
    win.runIdle();
    win.runIdle();
    win.runTimeout();

    expect(load).toHaveBeenCalledTimes(1);
  });
});

describe("errors thrown before the SDK arrives", () => {
  it("are buffered and handed over once it does", async () => {
    const pushError = vi.fn();
    const load = vi.fn().mockResolvedValue({ api: { pushError } });
    const win = makeWin();

    scheduleRum({ win, doc: makeDoc(ENABLED), load });

    const early = new Error("thrown while the SDK was still downloading");
    win.fire("error", { error: early });
    win.fire("unhandledrejection", { reason: early });

    expect(pushError).not.toHaveBeenCalled();

    await win.runIdle();

    expect(pushError).toHaveBeenCalledTimes(2);
    expect(pushError).toHaveBeenCalledWith(early);
  });

  it("stop being buffered once the SDK owns the handlers", async () => {
    const pushError = vi.fn();
    const load = vi.fn().mockResolvedValue({ api: { pushError } });
    const win = makeWin();

    scheduleRum({ win, doc: makeDoc(ENABLED), load });
    await win.runIdle();

    expect(win.listenerCount("error")).toBe(0);
    expect(win.listenerCount("unhandledrejection")).toBe(0);
  });

  it("are dropped loudly, not silently, past the buffer cap", async () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const pushError = vi.fn();
    const load = vi.fn().mockResolvedValue({ api: { pushError } });
    const win = makeWin();

    scheduleRum({ win, doc: makeDoc(ENABLED), load });

    for (let i = 0; i < MAX_BUFFERED_ERRORS + 5; i++) {
      win.fire("error", { error: new Error(`boom ${i}`) });
    }
    await win.runIdle();

    expect(pushError).toHaveBeenCalledTimes(MAX_BUFFERED_ERRORS);
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
  });

  it("survive an SDK that fails to load, and say so", async () => {
    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const load = vi.fn().mockRejectedValue(new Error("chunk 404"));
    const win = makeWin();

    scheduleRum({ win, doc: makeDoc(ENABLED), load });
    await win.runIdle();

    expect(error).toHaveBeenCalled();
    error.mockRestore();
  });
});
