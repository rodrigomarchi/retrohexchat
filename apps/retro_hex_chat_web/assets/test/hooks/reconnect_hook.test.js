import { mountHook, simulateEvent, cleanupDOM, mockLocalStorage } from "../helpers/hook_helper.js";
import ReconnectHook from "../../js/hooks/reconnect_hook.js";

describe("ReconnectHook", () => {
  let hook;
  let storage;

  beforeEach(() => {
    storage = mockLocalStorage();
    // Create a mock LiveView container for the observer
    const liveRoot = document.createElement("div");
    liveRoot.setAttribute("data-phx-main", "true");
    document.body.appendChild(liveRoot);

    hook = mountHook(ReconnectHook);
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
    storage.restore();
    vi.useRealTimers();
  });

  // ── backoff ────────────────────────────────────────────

  describe("getBackoffDelay", () => {
    it("returns 1s for attempt 1", () => {
      expect(hook.getBackoffDelay(1)).toBe(1);
    });

    it("returns 2s for attempt 2", () => {
      expect(hook.getBackoffDelay(2)).toBe(2);
    });

    it("returns 4s for attempt 3", () => {
      expect(hook.getBackoffDelay(3)).toBe(4);
    });

    it("caps at maxDelay", () => {
      hook.maxDelay = 10;
      expect(hook.getBackoffDelay(10)).toBe(10);
    });

    it("uses default maxDelay of 30", () => {
      expect(hook.getBackoffDelay(20)).toBe(30);
    });
  });

  // ── disconnect handling ────────────────────────────────

  describe("disconnect cycle", () => {
    it("starts reconnect cycle on disconnect", () => {
      const spy = vi.spyOn(hook, "showCountdownOverlay");
      hook.handleDisconnect();
      expect(hook.wasDisconnected).toBe(true);
      expect(hook.attempt).toBe(1);
      expect(spy).toHaveBeenCalledWith(1);
    });

    it("does not start reconnect if disabled", () => {
      hook.enabled = false;
      hook.handleDisconnect();
      expect(hook.wasDisconnected).toBe(false);
    });
  });

  // ── cancel ─────────────────────────────────────────────

  describe("cancel", () => {
    it("sets cancelled flag and shows cancel overlay", () => {
      hook.handleCancel();
      expect(hook.cancelled).toBe(true);
      expect(document.querySelector(".reconnect-overlay")).not.toBeNull();
      expect(document.querySelector(".reconnect-overlay").textContent).toContain("cancelled");
    });
  });

  // ── intentional disconnect ─────────────────────────────

  describe("intentional disconnect", () => {
    it("skips reconnect when intentional disconnect flag is set", () => {
      storage.store["rhc_intentional_disconnect"] = "true";
      hook.handleDisconnect();
      expect(hook.wasDisconnected).toBe(false);
    });

    it("removes rhc_reconnect_state on intentional_disconnect event", () => {
      storage.store["rhc_reconnect_state"] = JSON.stringify({ channels: ["#test"] });
      simulateEvent(hook, "intentional_disconnect", {});
      expect(storage.store["rhc_reconnect_state"]).toBeUndefined();
    });
  });

  // ── max attempts ───────────────────────────────────────

  describe("max attempts", () => {
    it("shows failed overlay after exceeding max attempts", () => {
      const spy = vi.spyOn(hook, "showFailedOverlay");
      hook.wasDisconnected = true;
      hook.attempt = hook.maxAttempts;
      hook.startReconnectCycle();
      expect(spy).toHaveBeenCalled();
    });
  });

  // ── reconnect_config event ─────────────────────────────

  describe("reconnect_config", () => {
    it("updates config from server event", () => {
      simulateEvent(hook, "reconnect_config", {
        enabled: false,
        max_attempts: 5,
        max_delay: 15,
      });
      expect(hook.enabled).toBe(false);
      expect(hook.maxAttempts).toBe(5);
      expect(hook.maxDelay).toBe(15);
    });
  });
});
