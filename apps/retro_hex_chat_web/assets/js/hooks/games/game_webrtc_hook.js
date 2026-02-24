/**
 * LiveView Hook: GameWebRTCHook
 *
 * WebRTC lifecycle management for game sessions.
 * Reuses the pure webrtc.js logic module with game-prefixed events.
 * Creates a DataChannel for game state sync between host and peer.
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

const GameWebRTCHook = {
  mounted() {
    this.pc = null;
    this.iceServers = null;
    this.turnOnly = false;
    this.retryCount = 0;
    this.disconnectedTimer = null;
    this.role = null;
    this.dataChannel = null;

    this.handleEvent("game_start_offer", (data) => this._handleStartOffer(data));
    this.handleEvent("game_start_answer", (data) => this._handleStartAnswer(data));
    this.handleEvent("game_signal", (data) => this._handleSignal(data));
  },

  destroyed() {
    this._cleanup();
  },

  async _handleStartOffer({ ice_servers, turn_only }) {
    this.iceServers = ice_servers;
    this.turnOnly = !!turn_only;
    this.role = "initiator";
    await this._createConnection();

    const offer = await createOffer(this.pc);
    this.pushEvent("game_signal", { type: "offer", sdp: offer.sdp });
  },

  _handleStartAnswer({ ice_servers, turn_only }) {
    this.iceServers = ice_servers;
    this.turnOnly = !!turn_only;
    this.role = "answerer";
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

  async _handleRemoteOffer(data) {
    if (!this.pc) {
      await this._createConnection();
    }
    const answer = await createAnswer(this.pc, {
      type: "offer",
      sdp: data.sdp,
    });
    this.pushEvent("game_signal", { type: "answer", sdp: answer.sdp });
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

  async _createConnection() {
    if (this.pc) {
      close(this.pc);
    }

    const servers = this.iceServers || [];
    this.pc = createPeerConnection(servers, { turnOnly: this.turnOnly });

    onIceCandidate(this.pc, (candidate) => {
      if (candidate) {
        this.pushEvent("game_signal", {
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

    if (this.role === "initiator") {
      this.dataChannel = createDataChannel(this.pc, "gamedata", {
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
      this.el._gameDataChannel = channel;
      this._dispatchEvent("game_channel_ready", { channel });
    };
    channel.onclose = () => {
      this.el._gameDataChannel = null;
      this._dispatchEvent("game_channel_closed", { channel: null });
    };
  },

  _dispatchEvent(type, detail) {
    this.el.dispatchEvent(new CustomEvent(type, { detail }));
  },

  _handleConnectionStateChange(state) {
    this.pushEvent("game_rtc_state", { state });

    switch (state) {
      case "connected":
        this._clearDisconnectedTimer();
        this.retryCount = 0;
        this.pushEvent("game_connected", {});
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

      this.pushEvent("game_rtc_retry", { attempt });

      setTimeout(async () => {
        if (this.role === "initiator") {
          await this._createConnection();
          const offer = await createOffer(this.pc);
          this.pushEvent("game_signal", { type: "offer", sdp: offer.sdp });
        } else {
          await this._createConnection();
        }
      }, delay);
    } else {
      this.pushEvent("game_rtc_failed", { reason: "max_retries_exhausted" });
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

export default GameWebRTCHook;
