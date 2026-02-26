import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  createConnectionStateMachine,
  getBackoffDelay,
  DEFAULTS,
} from "../../../js/lib/connection/connection_state_machine.js";

describe("connection_state_machine", () => {
  describe("getBackoffDelay", () => {
    it("returns 1 for attempt 1", () => {
      expect(getBackoffDelay(1)).toBe(1);
    });

    it("returns 2 for attempt 2", () => {
      expect(getBackoffDelay(2)).toBe(2);
    });

    it("returns 4 for attempt 3", () => {
      expect(getBackoffDelay(3)).toBe(4);
    });

    it("returns 8 for attempt 4", () => {
      expect(getBackoffDelay(4)).toBe(8);
    });

    it("caps at default maxDelay (30)", () => {
      expect(getBackoffDelay(20)).toBe(30);
    });

    it("caps at custom maxDelay", () => {
      expect(getBackoffDelay(10, 10)).toBe(10);
    });
  });

  describe("DEFAULTS", () => {
    it("has expected values", () => {
      expect(DEFAULTS.maxAttempts).toBe(10);
      expect(DEFAULTS.maxDelay).toBe(30);
      expect(DEFAULTS.bannerDebounceMs).toBe(1000);
      expect(DEFAULTS.bannerToOverlayMs).toBe(2000);
      expect(DEFAULTS.reconnectedFadeMs).toBe(3000);
    });
  });

  describe("createConnectionStateMachine", () => {
    let sm;
    let stateChanges;
    let maxAttemptsExceeded;

    beforeEach(() => {
      vi.useFakeTimers();
      stateChanges = [];
      maxAttemptsExceeded = false;
      sm = createConnectionStateMachine({
        onStateChange: (state, data) => stateChanges.push({ state, data }),
        onMaxAttemptsExceeded: () => {
          maxAttemptsExceeded = true;
        },
      });
    });

    afterEach(() => {
      sm.destroy();
      vi.useRealTimers();
    });

    describe("initial state", () => {
      it("starts in connecting state", () => {
        expect(sm.getState()).toBe("connecting");
      });
    });

    describe("onMounted", () => {
      it("transitions to connected", () => {
        sm.onMounted();
        expect(sm.getState()).toBe("connected");
        expect(stateChanges).toEqual([{ state: "connected", data: undefined }]);
      });
    });

    describe("onDisconnect", () => {
      it("does nothing in connecting state", () => {
        sm.onDisconnect();
        vi.advanceTimersByTime(5000);
        expect(sm.getState()).toBe("connecting");
        expect(stateChanges).toEqual([]);
      });

      it("transitions to disconnected after debounce", () => {
        sm.onMounted();
        stateChanges = [];

        sm.onDisconnect();
        // Still connected during debounce
        expect(sm.getState()).toBe("connected");

        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);
        expect(sm.getState()).toBe("disconnected");
      });

      it("does not transition if reconnected during debounce", () => {
        sm.onMounted();
        stateChanges = [];

        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs / 2);
        sm.onReconnect();

        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);
        // Should be connected, not disconnected
        expect(sm.getState()).toBe("connected");
      });

      it("escalates to reconnecting after banner + overlay delay", () => {
        sm.onMounted();
        stateChanges = [];

        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);
        expect(sm.getState()).toBe("disconnected");

        vi.advanceTimersByTime(DEFAULTS.bannerToOverlayMs);
        expect(sm.getState()).toBe("reconnecting");

        const lastChange = stateChanges[stateChanges.length - 1];
        expect(lastChange.data.attempt).toBe(1);
        expect(lastChange.data.maxAttempts).toBe(DEFAULTS.maxAttempts);
        expect(lastChange.data.remaining).toBe(1); // first attempt: 2^0 = 1s
      });
    });

    describe("reconnecting countdown", () => {
      function enterReconnecting() {
        sm.onMounted();
        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);
        stateChanges = [];
      }

      it("counts down and advances to attempt 2", () => {
        enterReconnecting();
        // Attempt 1 has 1s countdown; after 1s it should advance to attempt 2
        vi.advanceTimersByTime(1000);
        expect(sm.getState()).toBe("reconnecting");

        const lastChange = stateChanges[stateChanges.length - 1];
        expect(lastChange.data.attempt).toBe(2);
        expect(lastChange.data.remaining).toBe(2); // 2^1 = 2s
      });

      it("updates remaining during countdown", () => {
        enterReconnecting();
        // Advance to attempt 2 (1s), then check countdown ticks
        vi.advanceTimersByTime(1000); // finish attempt 1 → start attempt 2 (2s)
        stateChanges = [];

        vi.advanceTimersByTime(1000); // 1 tick of attempt 2
        const tickChange = stateChanges[stateChanges.length - 1];
        expect(tickChange.data.attempt).toBe(2);
        expect(tickChange.data.remaining).toBe(1);
      });

      it("backoff delay doubles each attempt", () => {
        enterReconnecting();

        // Attempt 1: 1s, Attempt 2: 2s, Attempt 3: 4s
        vi.advanceTimersByTime(1000); // attempt 1 done
        const a2 = stateChanges[stateChanges.length - 1];
        expect(a2.data.attempt).toBe(2);
        expect(a2.data.remaining).toBe(2);

        vi.advanceTimersByTime(2000); // attempt 2 done
        const a3 = stateChanges[stateChanges.length - 1];
        expect(a3.data.attempt).toBe(3);
        expect(a3.data.remaining).toBe(4);
      });
    });

    describe("onReconnect", () => {
      it("from disconnected shows reconnected banner then connected", () => {
        sm.onMounted();
        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);
        expect(sm.getState()).toBe("disconnected");
        stateChanges = [];

        sm.onReconnect();
        expect(sm.getState()).toBe("reconnected");

        vi.advanceTimersByTime(DEFAULTS.reconnectedFadeMs);
        expect(sm.getState()).toBe("connected");
      });

      it("from reconnecting shows reconnected banner then connected", () => {
        sm.onMounted();
        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);
        expect(sm.getState()).toBe("reconnecting");
        stateChanges = [];

        sm.onReconnect();
        expect(sm.getState()).toBe("reconnected");

        vi.advanceTimersByTime(DEFAULTS.reconnectedFadeMs);
        expect(sm.getState()).toBe("connected");
      });

      it("goes directly to connected if reconnected during debounce", () => {
        sm.onMounted();
        sm.onDisconnect();
        vi.advanceTimersByTime(500); // within debounce
        stateChanges = [];

        sm.onReconnect();
        expect(sm.getState()).toBe("connected");
        expect(stateChanges).toEqual([{ state: "connected", data: undefined }]);
      });

      it("stops countdown timers on reconnect", () => {
        sm.onMounted();
        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);
        expect(sm.getState()).toBe("reconnecting");

        sm.onReconnect();
        vi.advanceTimersByTime(DEFAULTS.reconnectedFadeMs);
        expect(sm.getState()).toBe("connected");

        // Ensure no more state changes after settling
        stateChanges = [];
        vi.advanceTimersByTime(30000);
        expect(stateChanges).toEqual([]);
      });
    });

    describe("cancel", () => {
      it("transitions to cancelled from reconnecting", () => {
        sm.onMounted();
        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);
        expect(sm.getState()).toBe("reconnecting");
        stateChanges = [];

        sm.cancel();
        expect(sm.getState()).toBe("cancelled");
      });

      it("does nothing if not in reconnecting state", () => {
        sm.onMounted();
        stateChanges = [];

        sm.cancel();
        expect(sm.getState()).toBe("connected");
        expect(stateChanges).toEqual([]);
      });

      it("stops all timers after cancel", () => {
        sm.onMounted();
        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);
        sm.cancel();
        stateChanges = [];

        vi.advanceTimersByTime(60000);
        expect(stateChanges).toEqual([]);
      });
    });

    describe("max attempts exceeded", () => {
      it("calls onMaxAttemptsExceeded and transitions to failed", () => {
        // Use small maxAttempts for faster test
        sm.destroy();
        sm = createConnectionStateMachine(
          {
            onStateChange: (state, data) => stateChanges.push({ state, data }),
            onMaxAttemptsExceeded: () => {
              maxAttemptsExceeded = true;
            },
          },
          { maxAttempts: 2, maxDelay: 1 },
        );

        sm.onMounted();
        sm.onDisconnect();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);
        expect(sm.getState()).toBe("reconnecting");

        // Attempt 1: 1s countdown
        vi.advanceTimersByTime(1000);
        // Attempt 2: capped at 1s by maxDelay
        vi.advanceTimersByTime(1000);
        // Now attempt would be 3, exceeding maxAttempts=2

        expect(sm.getState()).toBe("failed");
        expect(maxAttemptsExceeded).toBe(true);
      });
    });

    describe("destroy", () => {
      it("clears all timers", () => {
        sm.onMounted();
        sm.onDisconnect();
        sm.destroy();
        stateChanges = [];

        vi.advanceTimersByTime(60000);
        expect(stateChanges).toEqual([]);
      });
    });

    describe("rapid disconnect/reconnect cycles", () => {
      it("handles multiple rapid cycles without leaking timers", () => {
        sm.onMounted();

        for (let i = 0; i < 5; i++) {
          sm.onDisconnect();
          vi.advanceTimersByTime(200);
          sm.onReconnect();
          vi.advanceTimersByTime(100);
        }

        // Should be back to connected
        expect(sm.getState()).toBe("connected");

        // Let all timers drain — no unexpected transitions
        stateChanges = [];
        vi.advanceTimersByTime(60000);
        expect(stateChanges).toEqual([]);
      });
    });
  });
});
