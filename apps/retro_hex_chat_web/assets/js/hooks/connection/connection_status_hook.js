/**
 * Unified connection status hook.
 *
 * Replaces ReconnectHook + ConnectionBannerHook with a single hook. The state
 * machine (connection_state_machine.js) owns the logic and the view controller
 * (connection_status_view.js) owns the DOM; this binds the two to the browser's
 * online/offline signals and the server's disconnect pushes.
 */
import { createConnectionStateMachine } from "../../lib/connection/connection_state_machine.js";
import { createConnectionStatusView } from "../../lib/connection/connection_status_view.js";

const ConnectionStatusHook = {
  mounted() {
    this._intentionalDisconnect = false;
    this._reconnectState = null;

    this._view = createConnectionStatusView(this.el, {
      onActionClick: () => this._handleActionClick(),
    });
    this._view.mount();

    this._sm = createConnectionStateMachine({
      onStateChange: (state, data) => this._view.render(state, data),
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
      this._view.clearDraft();
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
    this._view.destroy();
  },

  _handleActionClick() {
    const state = this._sm.getState();
    if (state === "reconnecting") {
      this._sm.cancel();
    } else if (state === "cancelled") {
      window.location.reload();
    }
  },

  _handleConnectionLost() {
    this._wasDisconnected = true;
    const state = this._sm.getState();
    if (state === "disconnected" || state === "reconnecting" || state === "cancelled") return;

    this._sm.onDisconnect();
  },

  _handleConnectionRestored() {
    this._sm.onReconnect();
    this._maybePushRestoreSession();
  },

  // Only after something was actually lost. `online` fires for reasons that
  // are not a dropped socket — a VPN settling, a laptop waking, a headless
  // browser starting — and each of those used to replay the snapshot the
  // server handed over at mount. Measured: about a second after opening a
  // channel the view jumped to the conversation of an earlier session, with
  // the socket never having closed.
  _maybePushRestoreSession() {
    if (!this._wasDisconnected) return;
    if (!this._reconnectState) return;

    const state = this._reconnectState;
    this._reconnectState = null;
    this._wasDisconnected = false;
    this.pushEvent("restore_session", state);
  },
};

export default ConnectionStatusHook;
