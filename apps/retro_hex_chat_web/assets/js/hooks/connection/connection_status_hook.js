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

    this._overlayAction.addEventListener("click", () => this._handleActionClick());

    this._sm = createConnectionStateMachine({
      onStateChange: (state, data) => this._render(state, data),
      onMaxAttemptsExceeded: () => {
        window.location.href = "/connect?reason=expired";
      },
    });

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
    this._sm.onDisconnect();
  },

  reconnected() {
    this._sm.onReconnect();
    this._maybePushRestoreSession();
  },

  destroyed() {
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
  },

  _updateStatusBar(state) {
    const el = document.querySelector('[data-testid="status-connection"]');
    if (!el) return;

    const info = STATUS_BAR_MAP[state] || STATUS_BAR_MAP.connected;
    el.className = `status-bar-connection--${info.css}`;
    el.textContent = `${info.indicator} ${info.text}`;
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
