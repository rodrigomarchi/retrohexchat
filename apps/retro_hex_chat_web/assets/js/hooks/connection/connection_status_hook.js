/**
 * Unified connection status hook.
 *
 * Replaces ReconnectHook + ConnectionBannerHook with a single hook.
 * Uses ConnectionStatusHook state machine for logic, renders to pre-built DOM.
 */
import { createConnectionStateMachine } from "../../lib/connection/connection_state_machine.js";
import { connectionView } from "../../lib/connection/connection_view.js";

const ConnectionStatusHook = {
  mounted() {
    this._banner = this.el.querySelector('[data-role="banner"]');
    this._bannerText = this.el.querySelector('[data-role="banner-text"]');
    this._overlay = this.el.querySelector('[data-role="overlay"]');
    this._overlayInfo = this.el.querySelector('[data-role="overlay-info"]');
    this._overlayCountdown = this.el.querySelector('[data-role="overlay-countdown"]');
    this._overlayAction = this.el.querySelector('[data-role="overlay-action"]');
    this._draftValue = "";
    this._intentionalDisconnect = false;
    this._reconnectState = null;

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
      this._intentionalDisconnect = true;
      this._reconnectState = null;
    });

    this.handleEvent("save_reconnect_state", (data) => {
      this._reconnectState = data && typeof data === "object" ? data : null;
    });

    this.handleEvent("clear_client_state", () => {
      this._intentionalDisconnect = true;
      this._reconnectState = null;
      this._draftValue = "";
    });

    this._maybePushRestoreSession();
    this._sm.onMounted();

    // The hook only ever hears about the network changing, so a drop that
    // happened while it was mounting is a drop nobody will mention again — the
    // banner stays down for the rest of the session. Reconciling with what the
    // browser already knows closes that window, and covers a re-mount landing
    // mid-outage too.
    if (!navigator.onLine) this._handleConnectionLost();
  },

  disconnected() {
    if (this._intentionalDisconnect) {
      this._intentionalDisconnect = false;
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
    const view = connectionView(state, data);

    this._banner.classList.remove(
      "connection-banner--visible",
      "connection-banner--disconnected",
      "connection-banner--reconnected",
    );
    if (view.banner.visible) {
      this._bannerText.textContent = view.banner.text;
      this._banner.classList.add(
        "connection-banner--visible",
        `connection-banner--${view.banner.variant}`,
      );
    }

    this._overlay.classList.remove("reconnect-overlay--visible");
    if (view.overlay.visible) {
      this._overlay.classList.add("reconnect-overlay--visible");
      this._overlayInfo.textContent = view.overlay.info;
      this._overlayCountdown.textContent = view.overlay.countdown;
      this._overlayAction.textContent = view.overlay.action;
    }

    this._updateChatInputDisabled(view.shellDisabled);
    this._updateShellDisabled(view.shellDisabled);
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

    // Which menus go away offline is marked in the markup, not matched by
    // label: the labels are translated, so reading them only ever recognised
    // the English ones, and the trigger's text carries its icon too.
    menuBar.querySelectorAll("[data-menubar-trigger]").forEach((trigger) => {
      const shouldDisable = disabled && trigger.dataset.offlineDisabled === "true";

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
    if (!this._reconnectState) return;

    const state = this._reconnectState;
    this._reconnectState = null;
    this.pushEvent("restore_session", state);
  },
};

export default ConnectionStatusHook;
