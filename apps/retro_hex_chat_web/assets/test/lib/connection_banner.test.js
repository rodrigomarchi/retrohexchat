import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { createBannerStateMachine, DEBOUNCE_MS, FADE_MS } from "../../js/lib/connection_banner.js";

describe("connection_banner", () => {
  let sm;

  beforeEach(() => {
    vi.useFakeTimers();
    sm = createBannerStateMachine();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe("initial state", () => {
    it("starts in hidden state", () => {
      expect(sm.getState()).toBe("hidden");
    });

    it("wasConnected is false initially", () => {
      expect(sm.wasConnected).toBe(false);
    });
  });

  describe("onDisconnect", () => {
    it("does nothing if wasConnected is false (initial load)", () => {
      sm.onDisconnect();
      vi.advanceTimersByTime(DEBOUNCE_MS + 100);
      expect(sm.getState()).toBe("hidden");
    });

    it("starts debounce when wasConnected is true", () => {
      sm.wasConnected = true;
      sm.onDisconnect();
      // Still hidden during debounce
      expect(sm.getState()).toBe("hidden");
    });

    it("transitions to disconnected after debounce completes", () => {
      sm.wasConnected = true;
      sm.onDisconnect();
      vi.advanceTimersByTime(DEBOUNCE_MS);
      expect(sm.getState()).toBe("disconnected");
    });
  });

  describe("onReconnect", () => {
    it("sets wasConnected to true", () => {
      sm.onReconnect();
      expect(sm.wasConnected).toBe(true);
    });

    it("cancels debounce and stays hidden if reconnected during debounce", () => {
      sm.wasConnected = true;
      sm.onDisconnect();
      vi.advanceTimersByTime(DEBOUNCE_MS / 2);
      sm.onReconnect();
      vi.advanceTimersByTime(DEBOUNCE_MS);
      expect(sm.getState()).toBe("hidden");
    });

    it("transitions to reconnected from disconnected", () => {
      sm.wasConnected = true;
      sm.onDisconnect();
      vi.advanceTimersByTime(DEBOUNCE_MS);
      expect(sm.getState()).toBe("disconnected");
      sm.onReconnect();
      expect(sm.getState()).toBe("reconnected");
    });

    it("auto-transitions to hidden after FADE_MS", () => {
      sm.wasConnected = true;
      sm.onDisconnect();
      vi.advanceTimersByTime(DEBOUNCE_MS);
      sm.onReconnect();
      expect(sm.getState()).toBe("reconnected");
      vi.advanceTimersByTime(FADE_MS);
      expect(sm.getState()).toBe("hidden");
    });
  });

  describe("onOverlayVisible", () => {
    it("forces state to hidden", () => {
      sm.wasConnected = true;
      sm.onDisconnect();
      vi.advanceTimersByTime(DEBOUNCE_MS);
      expect(sm.getState()).toBe("disconnected");
      sm.onOverlayVisible();
      expect(sm.getState()).toBe("hidden");
    });
  });

  describe("constants", () => {
    it("DEBOUNCE_MS is 1000", () => {
      expect(DEBOUNCE_MS).toBe(1000);
    });

    it("FADE_MS is 3000", () => {
      expect(FADE_MS).toBe(3000);
    });
  });

  describe("destroy", () => {
    it("clears all timers", () => {
      sm.wasConnected = true;
      sm.onDisconnect();
      sm.destroy();
      vi.advanceTimersByTime(DEBOUNCE_MS + 1000);
      // Should stay hidden because timers were cleared
      expect(sm.getState()).toBe("hidden");
    });
  });
});
