import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import ArcadeTimerHook from "../../../js/hooks/games/arcade_timer_hook";

describe("ArcadeTimerHook", () => {
  let hook;

  beforeEach(() => {
    vi.useFakeTimers();

    hook = {
      ...ArcadeTimerHook,
      el: {
        dataset: { startedAt: new Date(Date.now() - 65000).toISOString() },
        textContent: "",
      },
    };
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("displays elapsed time on mount", () => {
    hook.mounted();

    // 65 seconds = 1:05
    expect(hook.el.textContent).toBe("1:05");
  });

  it("updates every second", () => {
    hook.el.dataset.startedAt = new Date(Date.now() - 3000).toISOString();
    hook.mounted();

    expect(hook.el.textContent).toBe("0:03");

    vi.advanceTimersByTime(2000);
    expect(hook.el.textContent).toBe("0:05");
  });

  it("clears interval on destroyed", () => {
    hook.mounted();
    hook.destroyed();

    const frozenText = hook.el.textContent;
    vi.advanceTimersByTime(5000);
    expect(hook.el.textContent).toBe(frozenText);
  });

  describe("formatting", () => {
    it("formats 0 seconds as 0:00", () => {
      hook.el.dataset.startedAt = new Date(Date.now()).toISOString();
      hook.mounted();

      expect(hook.el.textContent).toBe("0:00");
    });

    it("formats 59 seconds as 0:59", () => {
      hook.el.dataset.startedAt = new Date(Date.now() - 59000).toISOString();
      hook.mounted();

      expect(hook.el.textContent).toBe("0:59");
    });

    it("formats 60 seconds as 1:00", () => {
      hook.el.dataset.startedAt = new Date(Date.now() - 60000).toISOString();
      hook.mounted();

      expect(hook.el.textContent).toBe("1:00");
    });

    it("formats 3599 seconds as 59:59", () => {
      hook.el.dataset.startedAt = new Date(Date.now() - 3599000).toISOString();
      hook.mounted();

      expect(hook.el.textContent).toBe("59:59");
    });

    it("formats 3600 seconds as 1:00:00", () => {
      hook.el.dataset.startedAt = new Date(Date.now() - 3600000).toISOString();
      hook.mounted();

      expect(hook.el.textContent).toBe("1:00:00");
    });

    it("formats 7384 seconds as 2:03:04", () => {
      hook.el.dataset.startedAt = new Date(Date.now() - 7384000).toISOString();
      hook.mounted();

      expect(hook.el.textContent).toBe("2:03:04");
    });

    it("handles negative elapsed (clock skew) as 0:00", () => {
      hook.el.dataset.startedAt = new Date(Date.now() + 10000).toISOString();
      hook.mounted();

      expect(hook.el.textContent).toBe("0:00");
    });
  });
});
