/**
 * LiveView Hook: WebRTCHook
 *
 * Wires LiveView server events to the webrtc.js pure logic module.
 * Manages RTCPeerConnection lifecycle, signaling relay, retry logic,
 * and connection state reporting.
 */
import {
  createPeerConnection,
  createOffer,
  createAnswer,
  handleAnswer,
  addIceCandidate,
  close,
  onConnectionStateChange,
  onIceCandidate,
  RETRY_CONFIG,
} from "../lib/webrtc.js";

const WebRTCHook = {
  mounted() {
    this.pc = null;
    this.iceServers = null;
    this.retryCount = 0;
    this.disconnectedTimer = null;
    this.role = null;

    this.handleEvent("p2p_start_offer", (data) => this._handleStartOffer(data));
    this.handleEvent("p2p_start_answer", (data) => this._handleStartAnswer(data));
    this.handleEvent("p2p_signal", (data) => this._handleSignal(data));
  },

  destroyed() {
    this._cleanup();
  },

  // --- Server event handlers ---

  async _handleStartOffer({ ice_servers }) {
    this.iceServers = ice_servers;
    this.role = "initiator";
    await this._createConnection();

    const offer = await createOffer(this.pc);
    this.pushEvent("p2p_signal", { type: "offer", sdp: offer.sdp });
  },

  _handleStartAnswer({ ice_servers }) {
    this.iceServers = ice_servers;
    this.role = "answerer";
    // Wait for offer to arrive via p2p_signal
  },

  async _handleSignal(data) {
    switch (data.type) {
      case "offer":
        await this._handleRemoteOffer(data);
        break;
      case "answer":
        await this._handleRemoteAnswer(data);
        break;
      case "ice-candidate":
        await this._handleRemoteCandidate(data);
        break;
    }
  },

  // --- Signal processing ---

  async _handleRemoteOffer(data) {
    // Answerer receives offer — create PC, set offer, create answer
    if (!this.pc) {
      await this._createConnection();
    }

    const answer = await createAnswer(this.pc, {
      type: "offer",
      sdp: data.sdp,
    });
    this.pushEvent("p2p_signal", { type: "answer", sdp: answer.sdp });
  },

  async _handleRemoteAnswer(data) {
    if (this.pc) {
      await handleAnswer(this.pc, { type: "answer", sdp: data.sdp });
    }
  },

  async _handleRemoteCandidate(data) {
    if (this.pc && data.candidate) {
      await addIceCandidate(this.pc, data.candidate);
    }
  },

  // --- Connection management ---

  async _createConnection() {
    if (this.pc) {
      close(this.pc);
    }

    this.pc = createPeerConnection(this.iceServers || []);

    onIceCandidate(this.pc, (candidate) => {
      if (candidate) {
        this.pushEvent("p2p_signal", {
          type: "ice-candidate",
          candidate: {
            candidate: candidate.candidate,
            sdpMid: candidate.sdpMid,
            sdpMLineIndex: candidate.sdpMLineIndex,
          },
        });
      }
    });

    onConnectionStateChange(this.pc, (state) => {
      this._handleConnectionStateChange(state);
    });
  },

  _handleConnectionStateChange(state) {
    this.pushEvent("p2p_state_change", { state });

    switch (state) {
      case "connected":
        this._clearDisconnectedTimer();
        this.retryCount = 0;
        this.pushEvent("p2p_connected", {});
        break;

      case "disconnected":
        this._startDisconnectedGracePeriod();
        break;

      case "failed":
        this._clearDisconnectedTimer();
        this._handleFailure();
        break;

      case "closed":
        this._clearDisconnectedTimer();
        break;
    }
  },

  _startDisconnectedGracePeriod() {
    this._clearDisconnectedTimer();
    this.disconnectedTimer = setTimeout(() => {
      this.disconnectedTimer = null;
      // Treat prolonged disconnect as failure
      if (this.pc && this.pc.connectionState === "disconnected") {
        this._handleFailure();
      }
    }, RETRY_CONFIG.disconnectedGracePeriod);
  },

  _handleFailure() {
    if (this.retryCount < RETRY_CONFIG.maxAttempts) {
      const attempt = this.retryCount + 1;
      const delay = RETRY_CONFIG.delays[this.retryCount];
      this.retryCount = attempt;

      this.pushEvent("p2p_retry", { attempt });

      setTimeout(async () => {
        if (this.role === "initiator") {
          await this._createConnection();
          const offer = await createOffer(this.pc);
          this.pushEvent("p2p_signal", { type: "offer", sdp: offer.sdp });
        } else {
          // Answerer waits for new offer from initiator
          await this._createConnection();
        }
      }, delay);
    } else {
      this.pushEvent("p2p_failed", { reason: "max_retries_exhausted" });
    }
  },

  _clearDisconnectedTimer() {
    if (this.disconnectedTimer) {
      clearTimeout(this.disconnectedTimer);
      this.disconnectedTimer = null;
    }
  },

  _cleanup() {
    this._clearDisconnectedTimer();
    if (this.pc) {
      close(this.pc);
      this.pc = null;
    }
  },
};

export default WebRTCHook;
