import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { mountHook, simulateEvent, cleanupDOM, getPushEvents } from "../../helpers/hook_helper.js";
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
  let restoreLocalStorage;

  beforeEach(() => {
    vi.useFakeTimers();
    restoreLocalStorage = forbidLocalStorage();

    hook = mountHook(ConnectionStatusHook, {
      html: buildConnectionStatusHTML(),
      attrs: { id: "connection-status" },
    });
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
    restoreLocalStorage();
    vi.useRealTimers();
  });

  // ── mount ─────────────────────────────────────────────

  describe("mounted", () => {
    it("mounts with nothing on screen", () => {
      const banner = hook.el.querySelector('[data-role="banner"]');
      const overlay = hook.el.querySelector('[data-role="overlay"]');

      expect(banner.classList.contains("connection-banner--visible")).toBe(false);
      expect(overlay.classList.contains("reconnect-overlay--visible")).toBe(false);
    });

    it("does not push restore_session on mount without an in-memory snapshot", () => {
      const events = getPushEvents(hook, "restore_session");
      expect(events).toHaveLength(0);
    });

    // The hook only hears about the network *changing*. A drop that happened
    // while it was mounting would otherwise never be mentioned again, and the
    // banner would stay down for the rest of the session.
    it("shows the banner when it mounts while already offline", () => {
      const onLine = Object.getOwnPropertyDescriptor(Navigator.prototype, "onLine");
      Object.defineProperty(navigator, "onLine", {
        configurable: true,
        get: () => false,
      });

      try {
        const offlineHook = mountHook(ConnectionStatusHook, {
          html: buildConnectionStatusHTML(),
          attrs: { id: "connection-status-offline" },
        });
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);

        const banner = offlineHook.el.querySelector('[data-role="banner"]');
        expect(banner.classList.contains("connection-banner--visible")).toBe(true);

        if (offlineHook.destroyed) offlineHook.destroyed();
      } finally {
        if (onLine) Object.defineProperty(Navigator.prototype, "onLine", onLine);
        else delete navigator.onLine;
      }
    });
  });

  // ── offline shell ─────────────────────────────────────

  describe("shell while offline", () => {
    // The labels are translated. Reading them to decide which menus to gray out
    // recognised the English ones and silently left every other locale's menu
    // bar fully usable while the socket was down — so the markup says which
    // menus these are, and the label here is deliberately not English.
    it("disables the menus marked in the markup, whatever they are called", () => {
      const menuBar = document.createElement("nav");
      menuBar.setAttribute("data-testid", "menu-bar");
      menuBar.innerHTML = `
        <button data-menubar-trigger data-offline-disabled="true"
                data-disabled="false" aria-disabled="false">
          <span><svg></svg></span><span data-menubar-label>Ferramentas</span>
        </button>
        <button data-menubar-trigger data-offline-disabled="false"
                data-disabled="false" aria-disabled="false">
          <span><svg></svg></span><span data-menubar-label>Ajuda</span>
        </button>
      `;
      document.body.appendChild(menuBar);

      try {
        hook.disconnected();
        vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);

        const [marked, unmarked] = menuBar.querySelectorAll("[data-menubar-trigger]");
        expect(marked.getAttribute("aria-disabled")).toBe("true");
        expect(unmarked.getAttribute("aria-disabled")).toBe("false");
      } finally {
        menuBar.remove();
      }
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

    it("skips one disconnect after intentional_disconnect event", () => {
      simulateEvent(hook, "intentional_disconnect", {});
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs + DEFAULTS.bannerToOverlayMs + 5000);

      const banner = hook.el.querySelector('[data-role="banner"]');
      expect(banner.classList.contains("connection-banner--visible")).toBe(false);
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

    it("pushes restore_session once if an in-memory reconnect state exists", () => {
      hook.disconnected();
      vi.advanceTimersByTime(DEFAULTS.bannerDebounceMs);

      simulateEvent(hook, "save_reconnect_state", { nickname: "rod", channels: ["#a"] });
      hook.reconnected();

      const events = getPushEvents(hook, "restore_session");
      expect(events).toHaveLength(1);
      expect(events[0].nickname).toBe("rod");

      hook.reconnected();
      expect(getPushEvents(hook, "restore_session")).toHaveLength(1);
    });
  });

  // ── server events ──────────────────────────────────────

  describe("server events", () => {
    it("intentional_disconnect clears the in-memory reconnect state", () => {
      simulateEvent(hook, "save_reconnect_state", { channels: ["#a"] });
      simulateEvent(hook, "intentional_disconnect", {});

      hook.reconnected();
      expect(getPushEvents(hook, "restore_session")).toHaveLength(0);
    });

    it("save_reconnect_state remembers a valid object in memory", () => {
      const data = { nickname: "rod", channels: ["#a", "#b"] };
      simulateEvent(hook, "save_reconnect_state", data);

      hook.reconnected();
      expect(getPushEvents(hook, "restore_session")).toEqual([data]);
    });

    it("save_reconnect_state ignores malformed payloads", () => {
      simulateEvent(hook, "save_reconnect_state", "bad");
      hook.reconnected();
      expect(getPushEvents(hook, "restore_session")).toHaveLength(0);
    });

    it("clear_client_state clears in-memory state only", () => {
      simulateEvent(hook, "save_reconnect_state", { channels: ["#a"] });
      simulateEvent(hook, "clear_client_state", {});

      hook.reconnected();
      expect(getPushEvents(hook, "restore_session")).toHaveLength(0);
    });
  });
});

function forbidLocalStorage() {
  const original = globalThis.localStorage;

  const forbidden = {
    getItem: vi.fn(() => {
      throw new Error("localStorage must not be used by ConnectionStatusHook");
    }),
    setItem: vi.fn(() => {
      throw new Error("localStorage must not be used by ConnectionStatusHook");
    }),
    removeItem: vi.fn(() => {
      throw new Error("localStorage must not be used by ConnectionStatusHook");
    }),
    clear: vi.fn(() => {
      throw new Error("localStorage must not be used by ConnectionStatusHook");
    }),
    key: vi.fn(() => null),
    get length() {
      throw new Error("localStorage must not be used by ConnectionStatusHook");
    },
  };

  Object.defineProperty(globalThis, "localStorage", {
    value: forbidden,
    writable: true,
    configurable: true,
  });

  return () => {
    Object.defineProperty(globalThis, "localStorage", {
      value: original,
      writable: true,
      configurable: true,
    });
  };
}
