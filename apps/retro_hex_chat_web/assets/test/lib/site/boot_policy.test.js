import { describe, expect, it, vi } from "vitest";
import {
  IDLE_TIMEOUT_MS,
  INTERACTIONS,
  bootMode,
  scheduleBoot,
} from "../../../js/lib/site/boot_policy.js";

function fakeWindow() {
  const listeners = new Map();
  return {
    listeners,
    addEventListener: vi.fn((type, fn) => listeners.set(type, fn)),
    removeEventListener: vi.fn((type) => listeners.delete(type)),
    setTimeout: vi.fn(() => 1),
    clearTimeout: vi.fn(),
    dispatch(type) {
      listeners.get(type)?.();
    },
  };
}

function fakeDocument({ visibilityState = "visible", readyState = "complete" } = {}) {
  const listeners = new Map();
  return {
    visibilityState,
    readyState,
    addEventListener: vi.fn((type, fn) => listeners.set(type, fn)),
    removeEventListener: vi.fn((type) => listeners.delete(type)),
    show() {
      this.visibilityState = "visible";
      listeners.get("visibilitychange")?.();
    },
  };
}

describe("bootMode", () => {
  it("boots at once where the server says the address needs the chat", () => {
    expect(bootMode({ dataset: { boot: "now" } }, "Googlebot/2.1")).toBe("now");
  });

  it("defers on a page of the site", () => {
    expect(bootMode({ dataset: { boot: "deferred" } }, "Mozilla/5.0 Chrome/130")).toBe("deferred");
    expect(bootMode(null)).toBe("deferred");
  });

  it("leaves a crawler on the page, never starting the chat behind it", () => {
    for (const ua of ["Mozilla/5.0 (compatible; Googlebot/2.1)", "bingbot/2.0", "Baiduspider"]) {
      expect(bootMode({ dataset: { boot: "deferred" } }, ua)).toBe("interaction");
    }
  });
});

describe("scheduleBoot", () => {
  it("boots immediately in now mode", () => {
    const boot = vi.fn();
    scheduleBoot({ mode: "now", boot, win: fakeWindow(), doc: fakeDocument() });
    expect(boot).toHaveBeenCalledTimes(1);
  });

  it("boots on the first interaction, once", () => {
    const boot = vi.fn();
    const win = fakeWindow();
    scheduleBoot({ mode: "deferred", boot, win, doc: fakeDocument() });

    expect(boot).not.toHaveBeenCalled();
    win.dispatch(INTERACTIONS[0]);
    win.dispatch(INTERACTIONS[1]);
    expect(boot).toHaveBeenCalledTimes(1);
  });

  it("boots when the browser is idle after load", () => {
    const boot = vi.fn();
    const win = fakeWindow();
    scheduleBoot({ mode: "deferred", boot, win, doc: fakeDocument() });

    expect(win.setTimeout).toHaveBeenCalledWith(expect.any(Function), IDLE_TIMEOUT_MS);
    win.setTimeout.mock.calls[0][0]();
    expect(boot).toHaveBeenCalledTimes(1);
  });

  it("waits for load before counting idle time", () => {
    const boot = vi.fn();
    const win = fakeWindow();
    scheduleBoot({ mode: "deferred", boot, win, doc: fakeDocument({ readyState: "loading" }) });

    expect(win.setTimeout).not.toHaveBeenCalled();
    win.dispatch("load");
    expect(win.setTimeout).toHaveBeenCalled();
  });

  it("never boots by itself in interaction mode", () => {
    const boot = vi.fn();
    const win = fakeWindow();
    scheduleBoot({ mode: "interaction", boot, win, doc: fakeDocument() });

    expect(win.setTimeout).not.toHaveBeenCalled();
    win.dispatch("pointerdown");
    expect(boot).toHaveBeenCalledTimes(1);
  });

  it("waits for a hidden tab to be shown", () => {
    const boot = vi.fn();
    const doc = fakeDocument({ visibilityState: "hidden" });
    scheduleBoot({ mode: "now", boot, win: fakeWindow(), doc });

    expect(boot).not.toHaveBeenCalled();
    doc.show();
    expect(boot).toHaveBeenCalledTimes(1);
  });

  it("cancels what is still pending", () => {
    const boot = vi.fn();
    const win = fakeWindow();
    const cancel = scheduleBoot({ mode: "deferred", boot, win, doc: fakeDocument() });

    cancel();
    win.dispatch("pointerdown");
    expect(boot).not.toHaveBeenCalled();
    expect(win.clearTimeout).toHaveBeenCalled();
  });
});
