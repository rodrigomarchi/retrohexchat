/**
 * Unified connection status hook.
 *
 * Replaces ReconnectHook + ConnectionBannerHook with a single hook.
 * Uses ConnectionStatusHook state machine for logic, renders to pre-built DOM.
 * Updates the status bar connection indicator directly (server can't know about WS drops).
 */
import { createConnectionStateMachine } from "../../lib/connection/connection_state_machine.js";

/** @type {Record<string, {indicator: string, text: string, css: string}>} */
const STATUS_BAR_MAP = {
  connecting: { indicator: "◌", text: "...", css: "connecting" },
  connected: { indicator: "●", text: "On", css: "connected" },
  disconnected: { indicator: "●", text: "Off", css: "disconnected" },
  reconnecting: { indicator: "↻", text: "...", css: "reconnecting" },
  reconnected: { indicator: "●", text: "On", css: "connected" },
  cancelled: { indicator: "●", text: "Off", css: "disconnected" },
  failed: { indicator: "●", text: "Off", css: "disconnected" },
};

const ConnectionStatusHook = {
  mounted() {
    this._banner = this.el.querySelector('[data-role="banner"]');
    this._bannerText = this.el.querySelector('[data-role="banner-text"]');
    this._overlay = this.el.querySelector('[data-role="overlay"]');
    this._overlayInfo = this.el.querySelector('[data-role="overlay-info"]');
    this._overlayCountdown = this.el.querySelector('[data-role="overlay-countdown"]');
    this._overlayAction = this.el.querySelector('[data-role="overlay-action"]');
    this._draftValue = "";

    this._overlayAction.addEventListener("click", () => this._handleActionClick());

    this._sm = createConnectionStateMachine({
      onStateChange: (state, data) => this._render(state, data),
      onMaxAttemptsExceeded: () => {
        window.location.href = "/connect?reason=expired";
      },
    });

    this._onBrowserOffline = () => this._handleConnectionLost();
    this._onBrowserOnline = () => this._handleConnectionRestored();
    window.addEventListener("offline", this._onBrowserOffline);
    window.addEventListener("online", this._onBrowserOnline);

    this.handleEvent("intentional_disconnect", () => {
      localStorage.setItem("rhc_intentional_disconnect", "true");
      localStorage.removeItem("rhc_reconnect_state");
    });

    this.handleEvent("save_reconnect_state", (data) => {
      localStorage.setItem("rhc_reconnect_state", JSON.stringify(data));
    });

    this.handleEvent("clear_client_state", () => {
      Object.keys(localStorage)
        .filter((k) => k.startsWith("rhc_"))
        .forEach((k) => localStorage.removeItem(k));
    });

    this._maybePushRestoreSession();
    this._sm.onMounted();
  },

  disconnected() {
    if (localStorage.getItem("rhc_intentional_disconnect") === "true") {
      localStorage.removeItem("rhc_intentional_disconnect");
      return;
    }
    this._handleConnectionLost();
  },

  reconnected() {
    this._handleConnectionRestored();
  },

  destroyed() {
    window.removeEventListener("offline", this._onBrowserOffline);
    window.removeEventListener("online", this._onBrowserOnline);
    this._sm.destroy();
  },

  _handleActionClick() {
    const state = this._sm.getState();
    if (state === "reconnecting") {
      this._sm.cancel();
    } else if (state === "cancelled") {
      window.location.reload();
    }
  },

  _render(state, data) {
    // Banner
    this._banner.classList.remove(
      "connection-banner--visible",
      "connection-banner--disconnected",
      "connection-banner--reconnected",
    );

    // Overlay
    this._overlay.classList.remove("reconnect-overlay--visible");

    switch (state) {
      case "disconnected":
        this._bannerText.textContent = "⚠️ Desconectado — Reconectando...";
        this._banner.classList.add("connection-banner--visible", "connection-banner--disconnected");
        break;

      case "reconnected":
        this._bannerText.textContent = "✓ Reconectado!";
        this._banner.classList.add("connection-banner--visible", "connection-banner--reconnected");
        break;

      case "reconnecting":
        this._overlay.classList.add("reconnect-overlay--visible");
        this._overlayInfo.textContent = `Reconnection attempt ${data.attempt} of ${data.maxAttempts}`;
        this._overlayCountdown.textContent = `Reconnecting in ${data.remaining}s...`;
        this._overlayAction.textContent = "Cancel";
        break;

      case "cancelled":
        this._overlay.classList.add("reconnect-overlay--visible");
        this._overlayInfo.textContent = "";
        this._overlayCountdown.textContent = "Reconnection cancelled. Refresh to try again.";
        this._overlayAction.textContent = "Refresh";
        break;

      // connected, connecting, failed — nothing visible
    }

    // Update status bar
    this._updateStatusBar(state);
    this._updateChatInputDisabled(
      state === "disconnected" ||
        state === "reconnecting" ||
        state === "cancelled" ||
        state === "failed",
    );
    this._updateShellDisabled(
      state === "disconnected" ||
        state === "reconnecting" ||
        state === "cancelled" ||
        state === "failed",
    );
  },

  _updateStatusBar(state) {
    const el = document.querySelector('[data-testid="status-connection"]');
    if (!el) return;

    const info = STATUS_BAR_MAP[state] || STATUS_BAR_MAP.connected;
    el.className = `status-bar-connection--${info.css}`;
    el.textContent = `${info.indicator} ${info.text}`;
  },

  _updateChatInputDisabled(disabled) {
    const input = document.querySelector('[data-testid="chat-input-field"]');
    const send = document.querySelector('[data-testid="chat-input-send"]');

    if (disabled && input) this._draftValue = input.value;
    if (!disabled) this._restoreDraftIfNeeded(input);

    if (input) input.disabled = disabled;
    if (send) send.disabled = disabled || !input || input.value.length === 0;
  },

  _updateShellDisabled(disabled) {
    const menuBar = document.querySelector('[data-testid="menu-bar"]');
    if (!menuBar) return;

    const offlineDisabledMenus = new Set(["File", "View", "Tools"]);

    menuBar.querySelectorAll("[data-menubar-trigger]").forEach((trigger) => {
      const label = trigger.textContent.trim();
      const shouldDisable = disabled && offlineDisabledMenus.has(label);

      trigger.dataset.disabled = shouldDisable ? "true" : "false";
      trigger.setAttribute("aria-disabled", shouldDisable ? "true" : "false");

      if (shouldDisable) {
        trigger.classList.remove("bg-primary", "text-primary-foreground");
      }
    });

    if (disabled) {
      menuBar.dispatchEvent(new CustomEvent("menubar:close-all"));
    }
  },

  _restoreDraftIfNeeded(input) {
    if (!input || !this._draftValue) return;

    const restore = () => {
      if (input.value !== "") return;

      input.value = this._draftValue;
      input.dispatchEvent(new Event("input", { bubbles: true }));
    };

    restore();
    requestAnimationFrame(restore);
    setTimeout(restore, 50);
  },

  _handleConnectionLost() {
    const state = this._sm.getState();
    if (state === "disconnected" || state === "reconnecting" || state === "cancelled") return;

    this._sm.onDisconnect();
  },

  _handleConnectionRestored() {
    this._sm.onReconnect();
    this._maybePushRestoreSession();
  },

  _maybePushRestoreSession() {
    const raw = localStorage.getItem("rhc_reconnect_state");
    if (!raw) return;

    try {
      const state = JSON.parse(raw);
      localStorage.removeItem("rhc_reconnect_state");
      this.pushEvent("restore_session", state);
    } catch {
      localStorage.removeItem("rhc_reconnect_state");
    }
  },
};

export default ConnectionStatusHook;
