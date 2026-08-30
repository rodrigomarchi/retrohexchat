/**
 * LiveView Hook: LobbyWebRTCHook
 *
 * Owns the single, persistent RTCPeerConnection for a P2P session and
 * multiplexes every feature over it (audio/video transceivers, the file-transfer
 * and game DataChannels). The connection logic — signalling, negotiation,
 * recovery, ICE, stats — lives in the framework-free controller
 * `lib/p2p/lobby_connection.js`, which a test can drive without LiveView.
 *
 * This file only binds that controller to two transports. What the peer needs
 * to hear goes over `p2p:<session_token>`, a Phoenix Channel of its own, so the
 * negotiation is not a property of the page hosting it. Everything else — it
 * failed, it is retrying, here are its stats — still goes to the LiveView,
 * because that is chat chrome. The controller does not know the difference:
 * it says what happened, and the routing here decides which wire carries it.
 */
import { createLobbyConnection } from "../../lib/p2p/lobby_connection.js";
import { createSignalingChannel, SIGNAL_EVENTS } from "../../lib/p2p/signaling_channel.js";

const LobbyWebRTCHook = {
  mounted() {
    this.signaling = createSignalingChannel({
      sessionToken: this.el.dataset.sessionToken,
      joinToken: this.el.dataset.joinToken,
      onError: (reply) => this.pushEvent("lobby_signaling_unavailable", reply),
    });

    this.conn = createLobbyConnection(this.el, {
      pushEvent: (event, payload) =>
        SIGNAL_EVENTS.includes(event)
          ? this.signaling.send(event, payload)
          : this.pushEvent(event, payload),
    });
    this.conn.mount();

    this.signaling
      .on("lobby_signal", (data) => this.conn.handleSignal(data))
      .on("lobby_signal_replay", (data) => this.conn.handleSignalReplay(data))
      .on("lobby_signal_rejected", (data) => this.conn.handleSignalRejected(data))
      // Answerer → initiator request to (re)offer after the answerer added tracks.
      .on("lobby_renegotiate", (data) => this.conn.handleRenegotiate(data));
    this.signaling.connect();

    // The host still owns when signaling starts and when it restarts: those
    // carry the transport policy, which is the page's to decide.
    this.handleEvent("lobby_start_offer", (data) => this.conn.handleStartOffer(data));
    this.handleEvent("lobby_start_answer", (data) => this.conn.handleStartAnswer(data));
    this.handleEvent("lobby_restart", (data = {}) => this.conn.handleRestart(data));
  },

  destroyed() {
    this.signaling.disconnect();
    this.conn.destroy();
  },

  reconnected() {
    this.conn.reconnected();
  },
};

export default LobbyWebRTCHook;
