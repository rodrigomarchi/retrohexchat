/**
 * LiveView Hook: GroupCallWebRTCHook
 *
 * Minimal browser-side SFU client. The connection — raw Phoenix Channel,
 * RTCPeerConnection, media, tiles, quality, reactions, recovery and stats —
 * lives in the framework-free controller `lib/group_call/conference_connection.js`,
 * which a test can drive without LiveView. This file only binds that controller
 * to the LiveView: it forwards `pushEvent`, registers the server events, and
 * relays lifecycle callbacks.
 */
import { createConferenceConnection } from "../../lib/group_call/conference_connection.js";
import { log } from "../../lib/logger.js";

const GroupCallWebRTCHook = {
  mounted() {
    this.conn = createConferenceConnection(this.el, {
      // Signalling outlives the socket: the controller keeps negotiating and
      // recovering while LiveView is reconnecting, and pushing then throws.
      // Those throws reached RUM as unhandled errors on every blip. Dropping
      // the signal is the only option available anyway — a reconnect remounts
      // the LiveView and the call renegotiates — so say so and carry on.
      pushEvent: (event, payload) => {
        if (!this.liveSocket?.isConnected?.()) {
          log.warn("[group_call] signal dropped, LiveView not connected", event);
          return;
        }

        this.pushEvent(event, payload);
      },
    });
    this.conn.mount();

    this.handleEvent("group_call_set_media_state", (payload) =>
      this.conn.setMediaState(payload || {}),
    );
    this.handleEvent("group_call_stop_screen_share", (payload) =>
      this.conn.stopScreenShareByModerator(payload || {}),
    );
    this.handleEvent("group_call_retry_media", () => this.conn.retryConnection("manual"));
    this.handleEvent("group_call_layout_state", (payload) =>
      this.conn.syncLayoutState(payload || {}),
    );
  },

  destroyed() {
    this.conn.destroy();
  },
};

export default GroupCallWebRTCHook;
