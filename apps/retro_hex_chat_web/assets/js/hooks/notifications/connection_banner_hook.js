/**
 * LiveView hook for connection status banners.
 *
 * Shows a red banner for brief disconnections (>1s) with countdown,
 * and a green banner on reconnection that fades after 3s.
 * Hides when the full reconnect overlay is visible.
 */
import { createBannerStateMachine } from "../../lib/notifications/connection_banner.js";

const ConnectionBannerHook = {
  mounted() {
    this._sm = createBannerStateMachine();
    this._sm.setOnChange((state) => this._render(state));
  },

  disconnected() {
    this._sm.onDisconnect();
    this._checkOverlay();
  },

  reconnected() {
    this._sm.onReconnect();
  },

  destroyed() {
    this._sm.destroy();
  },

  _checkOverlay() {
    const overlay = document.querySelector(".reconnect-overlay.reconnect-overlay--visible");
    if (overlay) {
      this._sm.onOverlayVisible();
    }
  },

  _render(state) {
    const el = this.el;
    el.classList.remove(
      "connection-banner--visible",
      "connection-banner--disconnected",
      "connection-banner--reconnected",
      "connection-banner--fade-out",
    );

    if (state === "disconnected") {
      el.textContent = "\u26a0\ufe0f Desconectado \u2014 Reconectando...";
      el.classList.add("connection-banner--visible", "connection-banner--disconnected");
    } else if (state === "reconnected") {
      el.textContent = "\u2713 Reconectado!";
      el.classList.add("connection-banner--visible", "connection-banner--reconnected");
    }
  },
};

export default ConnectionBannerHook;
