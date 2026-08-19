/**
 * LiveView Hook: LobbyWebRTCHook
 *
 * Owns the single, persistent RTCPeerConnection for a P2P session and
 * multiplexes every feature over it (audio/video transceivers, the file-transfer
 * and game DataChannels). The connection logic — signalling, negotiation,
 * recovery, ICE, stats — lives in the framework-free controller
 * `lib/p2p/lobby_connection.js`, which a test can drive without LiveView. This
 * file only binds that controller to the LiveView: it forwards `pushEvent`,
 * registers the server events, and relays lifecycle callbacks.
 */
import { createLobbyConnection } from "../../lib/p2p/lobby_connection.js";

const LobbyWebRTCHook = {
  mounted() {
    this.conn = createLobbyConnection(this.el, {
      pushEvent: (event, payload) => this.pushEvent(event, payload),
    });
    this.conn.mount();

    this.handleEvent("lobby_start_offer", (data) => this.conn.handleStartOffer(data));
    this.handleEvent("lobby_start_answer", (data) => this.conn.handleStartAnswer(data));
    this.handleEvent("lobby_restart", (data = {}) => this.conn.handleRestart(data));
    this.handleEvent("lobby_signal", (data) => this.conn.handleSignal(data));
    this.handleEvent("lobby_signal_replay", (data) => this.conn.handleSignalReplay(data));
    this.handleEvent("lobby_signal_rejected", (data = {}) => this.conn.handleSignalRejected(data));
    // Answerer → initiator request to (re)offer after the answerer added tracks.
    this.handleEvent("lobby_renegotiate", (data = {}) => this.conn.handleRenegotiate(data));
  },

  destroyed() {
    this.conn.destroy();
  },

  reconnected() {
    this.conn.reconnected();
  },
};

export default LobbyWebRTCHook;
