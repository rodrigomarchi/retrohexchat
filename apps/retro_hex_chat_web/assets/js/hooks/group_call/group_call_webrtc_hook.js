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

const GroupCallWebRTCHook = {
  mounted() {
    this.conn = createConferenceConnection(this.el, {
      pushEvent: (event, payload) => this.pushEvent(event, payload),
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
