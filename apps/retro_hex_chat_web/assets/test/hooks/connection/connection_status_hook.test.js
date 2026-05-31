import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  mountHook,
  simulateEvent,
  cleanupDOM,
  mockLocalStorage,
  getPushEvents,
} from "../../helpers/hook_helper.js";
import ConnectionStatusHook from "../../../js/hooks/connection/connection_status_hook.js";
import { DEFAULTS } from "../../../js/lib/connection/connection_state_machine.js";

/** Build the DOM structure that the Elixir component renders. */
function buildConnectionStatusHTML() {
  return `
    <div class="connection-banner" data-role="banner">
      <span data-role="banner-text"></span>
    </div>
    <div class="reconnect-overlay" data-role="overlay">
      <div class="window">
        <div class="title-bar">
          <div class="title-bar-text">Connection Lost</div>
        </div>
        <div class="window-body">
          <p data-role="overlay-info" class="attempt-info"></p>
          <p data-role="overlay-countdown" class="countdown"></p>
          <div class="u-mt-12">
            <button data-role="overlay-action" class="btn-icon"></button>
          </div>
        </div>
      </div>
    </div>
  `;
}

describe("ConnectionStatusHook", () => {
  let hook;
  let storage;

  beforeEach(() => {
    vi.useFakeTimers();
    storage = mockLocalStorage();

    // Create status bar element for status bar updates
    const statusEl = document.createElement("span");
    statusEl.setAttribute("data-testid", "status-connection");
    statusEl.className = "status-bar-connection--connected";
    statusEl.textContent = "● On";
    document.body.appendChild(statusEl);

    hook = mountHook(ConnectionStatusHook, {
      html: buildConnectionStatusHTML(),
      attrs: { id: "connection-status" },
    });
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
    storage.restore();
    vi.useRealTimers();
  });

  // ── mount ─────────────────────────────────────────────

  describe("mounted", () => {
    it("transitions to connected state on mount", () => {
      // After mount, status bar should show connected
      const statusEl = document.querySelector('[data-testid="status-connection"]');
      expect(statusEl.textContent).toBe("● On");
    });

    it("pushes restore_session if reconnect state exists in localStorage", () => {
      // Clean up previous mount
      hook.destroyed();
      cleanupDOM();

      const stateData = { nickname: "rod", channels: ["#test"] };
      storage.store["rhc_reconnect_state"] = JSON.stringify(stateData);

      const statusEl = document.createElement("span");
      statusEl.setAttribute("data-testid", "status-connection");
      document.body.appendChild(statusEl);

      hook = mountHook(ConnectionStatusHook, {
        html: buildConnectionStatusHTML(),
        attrs: { id: "connection-status" },
      });

      const events = getPushEvents(hook, "restore_session");
      expect(events).toHaveLength(1);
      expect(events[0]).toEqual(stateData);
      expect(storage.store["rhc_reconnect_state"]).toBeUndefined();
    });

    it("does not push restore_session if no state in localStorage", () => {
      const events = getPushEvents(hook, "restore_session");
      expect(events).toHaveLength(0);
    });
  });

  // ── disconnect → banner ────────────────────────────────

  describe("disconnected", () => {
    it("shows banner after debounce", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);

      const banner = hook.el.querySelector('[data-role="banner"]');
      expect(banner.classList.contains("connection-banner--visible")).toBe(true);
      expect(banner.classList.contains("connection-banner--disconnected")).toBe(true);

      const text = hook.el.querySelector('[data-role="banner-text"]');
      expect(text.textContent).toContain("Disconnected");
    });

    it("updates status bar to Off", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);

      const statusEl = document.querySelector('[data-testid="status-connection"]');
      expect(statusEl.className).toBe("status-bar-connection--disconnected");
      expect(statusEl.textContent).toBe("● Off");
    });

    it("skips disconnect when intentional_disconnect flag is set", () => {
      storage.store["rhc_intentional_disconnect"] = "true";
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs + 5000);

      const banner = hook.el.querySelector('[data-role="banner"]');
      expect(banner.classList.contains("connection-banner--visible")).toBe(false);
      expect(storage.store["rhc_intentional_disconnect"]).toBeUndefined();
    });
  });

  // ── disconnect → overlay (reconnecting) ────────────────

  describe("reconnecting overlay", () => {
    it("escalates to overlay after debounce + overlay delay", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);

      const overlay = hook.el.querySelector('[data-role="overlay"]');
      expect(overlay.classList.contains("reconnect-overlay--visible")).toBe(true);

      const info = hook.el.querySelector('[data-role="overlay-info"]');
      expect(info.textContent).toContain("attempt 1 of 10");

      const countdown = hook.el.querySelector('[data-role="overlay-countdown"]');
      expect(countdown.textContent).toContain("1s");

      // Banner should be hidden when overlay shows
      const banner = hook.el.querySelector('[data-role="banner"]');
      expect(banner.classList.contains("connection-banner--visible")).toBe(false);
    });

    it("updates status bar to reconnecting", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);

      const statusEl = document.querySelector('[data-testid="status-connection"]');
      expect(statusEl.className).toBe("status-bar-connection--reconnecting");
    });

    it("cancel button transitions to cancelled state", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);

      const actionBtn = hook.el.querySelector('[data-role="overlay-action"]');
      actionBtn.click();

      const countdown = hook.el.querySelector('[data-role="overlay-countdown"]');
      expect(countdown.textContent).toContain("cancelled");

      expect(actionBtn.textContent).toBe("Refresh");
    });
  });

  // ── reconnected ────────────────────────────────────────

  describe("reconnected", () => {
    it("shows green banner when reconnecting from disconnected", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);
      hook.reconnected();

      const banner = hook.el.querySelector('[data-role="banner"]');
      expect(banner.classList.contains("connection-banner--visible")).toBe(true);
      expect(banner.classList.contains("connection-banner--reconnected")).toBe(true);

      const text = hook.el.querySelector('[data-role="banner-text"]');
      expect(text.textContent).toContain("Reconnected");
    });

    it("green banner fades after reconnectedFadeMs", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);
      hook.reconnected();

      vi.advanceTimersByTime(DEFAULTS.reconnectedFadeMs);

      const banner = hook.el.querySelector('[data-role="banner"]');
      expect(banner.classList.contains("connection-banner--visible")).toBe(false);
    });

    it("hides overlay when reconnecting from overlay state", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs);

      hook.reconnected();

      const overlay = hook.el.querySelector('[data-role="overlay"]');
      expect(overlay.classList.contains("reconnect-overlay--visible")).toBe(false);

      const banner = hook.el.querySelector('[data-role="banner"]');
      expect(banner.classList.contains("connection-banner--reconnected")).toBe(true);
    });

    it("restores status bar to connected", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);
      hook.reconnected();

      // reconnected maps to connected in status bar
      const statusEl = document.querySelector('[data-testid="status-connection"]');
      expect(statusEl.className).toBe("status-bar-connection--connected");
      expect(statusEl.textContent).toBe("● On");
    });

    it("pushes restore_session if reconnect state exists", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);

      storage.store["rhc_reconnect_state"] = JSON.stringify({ nickname: "rod", channels: ["#a"] });
      hook.reconnected();

      const events = getPushEvents(hook, "restore_session");
      expect(events).toHaveLength(1);
      expect(events[0].nickname).toBe("rod");
    });
  });

  // ── server events ──────────────────────────────────────

  describe("server events", () => {
    it("intentional_disconnect sets localStorage flag and removes state", () => {
      storage.store["rhc_reconnect_state"] = JSON.stringify({ channels: ["#a"] });
      simulateEvent(hook, "intentional_disconnect", {});
      expect(storage.store["rhc_intentional_disconnect"]).toBe("true");
      expect(storage.store["rhc_reconnect_state"]).toBeUndefined();
    });

    it("save_reconnect_state persists to localStorage", () => {
      const data = { nickname: "rod", channels: ["#a", "#b"] };
      simulateEvent(hook, "save_reconnect_state", data);
      expect(JSON.parse(storage.store["rhc_reconnect_state"])).toEqual(data);
    });

    it("clear_client_state removes all rhc_ keys", () => {
      storage.store["rhc_foo"] = "bar";
      storage.store["rhc_baz"] = "qux";
      storage.store["other_key"] = "keep";

      // Mock Object.keys to read from store
      const origKeys = Object.keys;
      vi.spyOn(Object, "keys").mockImplementation((obj) => {
        if (obj === localStorage) return origKeys.call(Object, storage.store);
        return origKeys.call(Object, obj);
      });

      simulateEvent(hook, "clear_client_state", {});

      expect(storage.store["rhc_foo"]).toBeUndefined();
      expect(storage.store["rhc_baz"]).toBeUndefined();
      expect(storage.store["other_key"]).toBe("keep");

      vi.restoreAllMocks();
    });
  });
});
