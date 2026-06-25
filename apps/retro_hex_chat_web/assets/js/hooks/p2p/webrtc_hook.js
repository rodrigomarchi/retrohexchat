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
  onDataChannel,
  createDataChannel,
  RETRY_CONFIG,
} from "../../lib/p2p/webrtc.js";

const WebRTCHook = {
  mounted() {
    this.pc = null;
    this.iceServers = null;
    this.turnOnly = false;
    this.retryCount = 0;
    this.disconnectedTimer = null;
    this.role = null;
    this.dataChannel = null;

    this.handleEvent("p2p_start_offer", (data) => this._handleStartOffer(data));
    this.handleEvent("p2p_start_answer", (data) => this._handleStartAnswer(data));
    this.handleEvent("p2p_signal", (data) => this._handleSignal(data));

    this.pushEvent("p2p_webrtc_ready", {});
  },

  destroyed() {
    this._cleanup();
  },

  // --- Server event handlers ---

  async _handleStartOffer({ ice_servers, turn_only }) {
    this.iceServers = ice_servers;
    this.turnOnly = !!turn_only;
    this.role = "initiator";

    try {
      await this._createConnection();
      const offer = await createOffer(this.pc);
      this.pushEvent("p2p_signal", { type: "offer", sdp: offer.sdp });
    } catch (error) {
      this._failConnection("offer", error);
    }
  },

  _handleStartAnswer({ ice_servers, turn_only }) {
    this.iceServers = ice_servers;
    this.turnOnly = !!turn_only;
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
    try {
      if (!this.pc) {
        await this._createConnection();
      }

      const answer = await createAnswer(this.pc, {
        type: "offer",
        sdp: data.sdp,
      });
      this.pushEvent("p2p_signal", { type: "answer", sdp: answer.sdp });
    } catch (error) {
      this._failConnection("answer", error);
    }
  },

  async _handleRemoteAnswer(data) {
    if (!this.pc) return;

    try {
      await handleAnswer(this.pc, { type: "answer", sdp: data.sdp });
    } catch (error) {
      this._failConnection("answer", error);
    }
  },

  async _handleRemoteCandidate(data) {
    if (!this.pc || !data.candidate) return;

    try {
      await addIceCandidate(this.pc, data.candidate);
    } catch (error) {
      // A single late/duplicate ICE candidate is not fatal — the connection
      // state machine surfaces a real failure if negotiation truly breaks.
      console.warn("[P2P] Failed to add ICE candidate", error);
    }
  },

  // --- Connection management ---

  async _createConnection() {
    if (this.pc) {
      close(this.pc);
    }

    const servers = this.iceServers || [];
    this.pc = createPeerConnection(servers, {
      turnOnly: this.turnOnly,
    });

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

    this.pc.onicecandidateerror = (event) => {
      // STUN/TURN candidate errors are frequently benign (e.g. one server of
      // several is unreachable); log for diagnostics, do not fail the call.
      console.warn("[P2P] ICE candidate error", event.errorCode, event.errorText);
    };

    this._negotiating = false;
    this.pc.onnegotiationneeded = async () => {
      if (this.role === "initiator" && !this._negotiating) {
        this._negotiating = true;
        try {
          const offer = await createOffer(this.pc);
          this.pushEvent("p2p_signal", { type: "offer", sdp: offer.sdp });
        } catch (error) {
          // Renegotiation (e.g. audio→video upgrade) failed; keep the existing
          // connection alive rather than tearing the whole session down.
          console.warn("[P2P] Renegotiation failed", error);
        } finally {
          this._negotiating = false;
        }
      }
    };

    if (this.role === "initiator") {
      this.dataChannel = createDataChannel(this.pc, "filetransfer", {
        ordered: true,
      });
      this.dataChannel.binaryType = "arraybuffer";
      this._setupDataChannel(this.dataChannel);
    } else {
      onDataChannel(this.pc, (channel) => {
        this.dataChannel = channel;
        this.dataChannel.binaryType = "arraybuffer";
        this._setupDataChannel(this.dataChannel);
      });
    }
  },

  _setupDataChannel(channel) {
    channel.onopen = () => {
      this.el._fileTransferChannel = channel;
      this._dispatchDataChannelEvent("ft_channel_ready", channel);
    };
    channel.onclose = () => {
      this.el._fileTransferChannel = null;
      this._dispatchDataChannelEvent("ft_channel_closed", null);
    };
  },

  _dispatchDataChannelEvent(type, channel) {
    const event = new CustomEvent(type, { detail: { channel } });
    this.el.dispatchEvent(event);
  },

  _dispatchMediaEvent(type, detail) {
    const event = new CustomEvent(type, { detail });
    this.el.dispatchEvent(event);
  },

  _handleConnectionStateChange(state) {
    this.pushEvent("p2p_state_change", { state });

    switch (state) {
      case "connected":
        this._clearDisconnectedTimer();
        this.retryCount = 0;
        this.el._peerConnection = this.pc;
        this.pushEvent("p2p_connected", {});
        this._dispatchMediaEvent("media_pc_ready", { pc: this.pc });
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
        try {
          if (this.role === "initiator") {
            await this._createConnection();
            const offer = await createOffer(this.pc);
            this.pushEvent("p2p_signal", { type: "offer", sdp: offer.sdp });
          } else {
            // Answerer waits for new offer from initiator
            await this._createConnection();
          }
        } catch (error) {
          this._failConnection("retry", error);
        }
      }, delay);
    } else {
      this.pushEvent("p2p_failed", { reason: "max_retries_exhausted" });
    }
  },

  _failConnection(phase, error) {
    console.error(`[P2P] connection ${phase} failed`, error);
    this.pushEvent("p2p_failed", { reason: `${phase}_failed` });
  },

  _clearDisconnectedTimer() {
    if (this.disconnectedTimer) {
      clearTimeout(this.disconnectedTimer);
      this.disconnectedTimer = null;
    }
  },

  _cleanup() {
    this._clearDisconnectedTimer();
    this.el._peerConnection = null;
    this._dispatchMediaEvent("media_pc_closed", {});
    if (this.dataChannel) {
      this.dataChannel.onopen = null;
      this.dataChannel.onclose = null;
      this.dataChannel.onmessage = null;
      this.dataChannel = null;
    }
    if (this.pc) {
      close(this.pc);
      this.pc = null;
    }
  },
};

export default WebRTCHook;
