/**
 * LiveView Hook: LobbyWebRTCHook
 *
 * Owns the single, persistent RTCPeerConnection for a universal lobby and
 * multiplexes EVERY feature over it:
 *
 *   - audio/video  → transceivers (the lobby media hook reuses `this.pc`)
 *   - file transfer → DataChannel "filetransfer" (FileTransferHook)
 *   - games         → DataChannel "gamedata"     (LobbyGameCanvasHook)
 *
 * Both data channels are created up front at connection time so that later
 * renegotiation is only ever triggered by media tracks — this avoids glare
 * between "user toggles video" and "game channel opens".
 *
 * Derived from p2p/webrtc_hook.js + games/game_webrtc_hook.js, kept isolated
 * so the dedicated /p2p and /game flows are untouched.
 */
import {
  createPeerConnection,
  addIceCandidate,
  close,
  onConnectionStateChange,
  onIceCandidate,
  onDataChannel,
  createDataChannel,
  RETRY_CONFIG,
} from "../../lib/p2p/webrtc.js";
import { collectFeatureSnapshot, deriveFeatureStats } from "../../lib/p2p/media.js";

// How often the always-on statistics window refreshes its per-feature metrics.
const STATS_INTERVAL_MS = 2500;

// Negotiation model: the INITIATOR is the single offerer. Both peers can still
// add media at any time (self-controlled audio/video), but only the initiator
// ever sends offers — the answerer asks the initiator to renegotiate instead
// (`lobby_renegotiate`). This sidesteps the offer glare that "perfect negotiation"
// resolves with rollback but which, in practice, leaves the polite peer's freshly
// received tracks muted (no RTP) when both peers add video at the same instant.
// Mirrors the proven approach in games/game_webrtc_hook.js.
const LobbyWebRTCHook = {
  mounted() {
    this.pc = null;
    this.iceServers = null;
    this.turnOnly = false;
    this.retryCount = 0;
    this.disconnectedTimer = null;
    this.role = null;
    this.negotiating = false;
    this.renegotiationQueued = false;
    this.queuedKinds = [];
    this.fileChannel = null;
    this.gameChannel = null;
    this.pendingIceCandidates = [];
    this._pendingDescription = null;
    this.statsTimer = null;
    this._statsPrev = null;

    this.handleEvent("lobby_start_offer", (data) => this._handleStartOffer(data));
    this.handleEvent("lobby_start_answer", (data) => this._handleStartAnswer(data));
    this.handleEvent("lobby_signal", (data) => this._handleSignal(data));
    // Answerer → initiator request to (re)offer after the answerer added tracks.
    this.handleEvent("lobby_renegotiate", (data = {}) => this._handleRenegotiate(data));

    // The media hook's stalled-stream watchdog asks us to recover a remote track
    // that negotiated but never started flowing (black frame, no RTP).
    this._onMediaRecover = () => this._recoverMedia();
    this.el.addEventListener("lobby_media_recover", this._onMediaRecover);

    this.pushEvent("lobby_webrtc_ready", {});
  },

  destroyed() {
    this.el.removeEventListener("lobby_media_recover", this._onMediaRecover);
    this._cleanup();
  },

  // --- Server event handlers ---

  // The initiator owns the two outgoing data channels; creating them triggers
  // onnegotiationneeded, which sends the first offer (no explicit createOffer
  // needed — that avoids a duplicate offer).
  async _handleStartOffer({ ice_servers, turn_only }) {
    if (this.role === "initiator" && this.pc) return;

    this.iceServers = ice_servers;
    this.turnOnly = !!turn_only;
    this.role = "initiator";
    // NB: do NOT reset pendingIceCandidates here — the peer's ICE candidates can
    // arrive before this event and must survive until the PC has a remote desc.

    try {
      await this._createConnection();
    } catch (error) {
      this._failConnection("offer", error);
    }
  },

  // The answerer never offers; it builds the connection up front so the inbound
  // offer and data channels have a target, then only ever answers.
  async _handleStartAnswer({ ice_servers, turn_only }) {
    if (this.role === "answerer" && this.pc) return;

    this.iceServers = ice_servers;
    this.turnOnly = !!turn_only;
    this.role = "answerer";
    // NB: do NOT reset pendingIceCandidates here — the initiator's ICE candidates
    // routinely arrive before this event and must survive until setRemoteDescription.

    try {
      await this._createConnection();
      // The initiator's offer can arrive before this event; apply it now.
      if (this._pendingDescription) {
        const pending = this._pendingDescription;
        this._pendingDescription = null;
        await this._handleRemoteDescription(pending);
      }
    } catch (error) {
      this._failConnection("answer", error);
    }
  },

  async _handleSignal(data) {
    if (data.type === "ice-candidate") {
      await this._handleRemoteCandidate(data);
    } else {
      await this._handleRemoteDescription(data);
    }
  },

  // --- Single-offerer negotiation ---

  async _handleRemoteDescription(data) {
    // The offer can arrive before the answerer's "lobby_start_answer" event has
    // built the PC. Buffer it (we only ever keep the latest) so _handleStartAnswer
    // can apply it once the connection — and its ICE servers — exist.
    if (!this.pc) {
      if (data.type === "offer") this._pendingDescription = data;
      return;
    }

    try {
      if (data.type === "offer") {
        // Answerer path: apply the initiator's offer and answer it.
        await this.pc.setRemoteDescription({ type: "offer", sdp: data.sdp });
        await this._flushPendingIceCandidates();
        await this.pc.setLocalDescription();
        this.pushEvent("lobby_signal", {
          type: this.pc.localDescription.type,
          sdp: this.pc.localDescription.sdp,
        });
      } else {
        // Initiator path: apply the answerer's answer, then drain any queued
        // renegotiation that arrived while this one was in flight.
        await this.pc.setRemoteDescription({ type: "answer", sdp: data.sdp });
        await this._flushPendingIceCandidates();
        this.negotiating = false;
        if (this.renegotiationQueued) {
          this.renegotiationQueued = false;
          this._maybeOffer();
        }
      }
    } catch (error) {
      this.negotiating = false;
      console.warn("[Lobby] Failed to apply remote description", error);
    }
  },

  // Answerer asks the initiator to (re)offer after it added local tracks. The
  // request carries the track kinds so the initiator can pre-create matching
  // recvonly transceivers, keeping the m-line layout aligned on both sides.
  _requestRenegotiation(recover = false) {
    const kinds = this.pc
      .getTransceivers()
      .map((t) => t.sender && t.sender.track && t.sender.track.kind)
      .filter(Boolean);
    this.pushEvent("lobby_renegotiate", { kinds, recover });
  },

  _handleRenegotiate({ kinds = [], recover = false }) {
    if (this.role !== "initiator" || !this.pc) return;
    if (recover && this.pc.restartIce) this.pc.restartIce();
    this._maybeOffer(kinds);
  },

  // Recover a stalled media stream. Only the initiator can restart ICE, so the
  // answerer routes the request through the initiator (single-offerer model).
  _recoverMedia() {
    if (!this.pc) return;
    if (this.role === "initiator") {
      if (this.pc.restartIce) this.pc.restartIce();
      this._maybeOffer();
    } else {
      this._requestRenegotiation(true);
    }
  },

  // Initiator-only. Serialized so two changes can't race into two offers.
  async _maybeOffer(ensureKinds = []) {
    if (this.role !== "initiator" || !this.pc) return;

    if (this.negotiating || this.pc.signalingState !== "stable") {
      // Defer, but remember the kinds: the drained re-offer must still create the
      // receiving transceivers for tracks the answerer added during this window.
      this.renegotiationQueued = true;
      this.queuedKinds.push(...ensureKinds);
      return;
    }

    this.negotiating = true;
    const kinds = this.queuedKinds.splice(0).concat(ensureKinds);
    try {
      for (const kind of kinds) {
        this._ensureReceivingTransceiver(kind);
      }
      await this.pc.setLocalDescription();
      this.pushEvent("lobby_signal", {
        type: this.pc.localDescription.type,
        sdp: this.pc.localDescription.sdp,
      });
    } catch (error) {
      this.negotiating = false;
      console.warn("[Lobby] Failed to create offer", error);
    }
  },

  // Make sure there is an m-line that can receive the peer's track of `kind`.
  _ensureReceivingTransceiver(kind) {
    if (kind !== "audio" && kind !== "video") return;

    const exists = this.pc.getTransceivers().some((t) => {
      const receiving = t.receiver && t.receiver.track && t.receiver.track.kind === kind;
      const sending = t.sender && t.sender.track && t.sender.track.kind === kind;
      return receiving || sending;
    });

    if (!exists) {
      this.pc.addTransceiver(kind, { direction: "recvonly" });
    }
  },

  async _handleRemoteCandidate(data) {
    if (!data.candidate) return;

    if (!this.pc || !this.pc.remoteDescription) {
      this.pendingIceCandidates.push(data.candidate);
      return;
    }

    try {
      await addIceCandidate(this.pc, data.candidate);
    } catch (error) {
      console.warn("[Lobby] Failed to add ICE candidate", error);
    }
  },

  async _flushPendingIceCandidates() {
    if (!this.pc || !this.pc.remoteDescription || this.pendingIceCandidates.length === 0) {
      return;
    }

    const candidates = this.pendingIceCandidates.splice(0);
    for (const candidate of candidates) {
      try {
        await addIceCandidate(this.pc, candidate);
      } catch (error) {
        console.warn("[Lobby] Failed to flush ICE candidate", error);
      }
    }
  },

  // --- Connection management ---

  async _createConnection() {
    if (this.pc) {
      // Rebuilding for a retry: candidates/descriptions for the old PC are stale.
      close(this.pc);
      this.pendingIceCandidates = [];
      this._pendingDescription = null;
    }

    const servers = this.iceServers || [];
    this.pc = createPeerConnection(servers, { turnOnly: this.turnOnly });
    this.negotiating = false;
    this.renegotiationQueued = false;
    this.queuedKinds = [];

    onIceCandidate(this.pc, (candidate) => {
      if (candidate) {
        this.pushEvent("lobby_signal", {
          type: "ice-candidate",
          candidate: {
            candidate: candidate.candidate,
            sdpMid: candidate.sdpMid,
            sdpMLineIndex: candidate.sdpMLineIndex,
          },
        });
      }
    });

    onConnectionStateChange(this.pc, (state) => this._handleConnectionStateChange(state));

    this.pc.onicecandidateerror = (event) => {
      console.warn("[Lobby] ICE candidate error", event.errorCode, event.errorText);
    };

    // A local track change (e.g. this peer turned on its camera) needs a fresh
    // offer. The initiator offers directly; the answerer asks the initiator to.
    this.pc.onnegotiationneeded = () => {
      if (this.role === "initiator") {
        this._maybeOffer();
      } else {
        this._requestRenegotiation();
      }
    };

    if (this.role === "initiator") {
      this._createOutgoingChannels();
    } else {
      onDataChannel(this.pc, (channel) => this._adoptChannel(channel));
    }
  },

  _createOutgoingChannels() {
    const fileChannel = createDataChannel(this.pc, "filetransfer", { ordered: true });
    fileChannel.binaryType = "arraybuffer";
    this._setupFileChannel(fileChannel);

    const gameChannel = createDataChannel(this.pc, "gamedata", { ordered: true });
    gameChannel.binaryType = "arraybuffer";
    this._setupGameChannel(gameChannel);
  },

  // Answerer routes inbound channels by label.
  _adoptChannel(channel) {
    channel.binaryType = "arraybuffer";

    if (channel.label === "gamedata") {
      this._setupGameChannel(channel);
    } else {
      this._setupFileChannel(channel);
    }
  },

  _setupFileChannel(channel) {
    this.fileChannel = channel;
    channel.onopen = () => {
      this.el._fileTransferChannel = channel;
      this._dispatch("ft_channel_ready", { channel });
    };
    channel.onclose = () => {
      this.el._fileTransferChannel = null;
      this._dispatch("ft_channel_closed", { channel: null });
    };
  },

  _setupGameChannel(channel) {
    this.gameChannel = channel;
    channel.onopen = () => {
      this.el._gameDataChannel = channel;
      this._dispatch("game_channel_ready", { channel });
    };
    channel.onclose = () => {
      this.el._gameDataChannel = null;
      this._dispatch("game_channel_closed", { channel: null });
    };
  },

  _dispatch(type, detail) {
    this.el.dispatchEvent(new CustomEvent(type, { detail }));
  },

  _handleConnectionStateChange(state) {
    this.pushEvent("lobby_state_change", { state });

    switch (state) {
      case "connected":
        this._clearDisconnectedTimer();
        this.retryCount = 0;
        this.el._peerConnection = this.pc;
        this.pushEvent("lobby_connected", {});
        this._dispatch("lobby_media_pc_ready", { pc: this.pc });
        this._startStatsPolling();
        break;

      case "disconnected":
        this._startDisconnectedGracePeriod();
        break;

      case "failed":
        this._clearDisconnectedTimer();
        this._stopStatsPolling();
        this._handleFailure();
        break;

      case "closed":
        this._clearDisconnectedTimer();
        this._stopStatsPolling();
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

      this.pushEvent("lobby_retry", { attempt });

      setTimeout(async () => {
        try {
          // Rebuilding the connection re-creates the data channels on the
          // initiator, which triggers onnegotiationneeded → a fresh offer.
          await this._createConnection();
        } catch (error) {
          this._failConnection("retry", error);
        }
      }, delay);
    } else {
      this.pushEvent("lobby_failed", { reason: "max_retries_exhausted" });
    }
  },

  _failConnection(phase, error) {
    console.error(`[Lobby] connection ${phase} failed`, error);
    this.pushEvent("lobby_failed", { reason: `${phase}_failed` });
  },

  _clearDisconnectedTimer() {
    if (this.disconnectedTimer) {
      clearTimeout(this.disconnectedTimer);
      this.disconnectedTimer = null;
    }
  },

  // --- Always-on statistics ---

  // From the moment the connection is established until it closes, sample
  // getStats() on a fixed cadence and push an always-complete per-feature payload
  // to the statistics window. This runs independently of whether a call is active
  // — idle features simply report zeros.
  _startStatsPolling() {
    if (this.statsTimer) return;
    this._statsPrev = null;
    this.statsTimer = setInterval(() => this._sampleStats(), STATS_INTERVAL_MS);
    // Emit a first sample promptly so the window is populated without waiting a
    // full interval.
    this._sampleStats();
  },

  async _sampleStats() {
    if (!this.pc || this.pc.connectionState !== "connected") return;
    try {
      const snapshot = await collectFeatureSnapshot(this.pc);
      const stats = deriveFeatureStats(this._statsPrev, snapshot);
      this._statsPrev = snapshot;
      this.pushEvent("lobby_stats", stats);
    } catch (error) {
      console.warn("[Lobby] Failed to sample stats", error);
    }
  },

  _stopStatsPolling() {
    if (this.statsTimer) {
      clearInterval(this.statsTimer);
      this.statsTimer = null;
    }
    this._statsPrev = null;
  },

  _cleanup() {
    this._clearDisconnectedTimer();
    this._stopStatsPolling();
    this.el._peerConnection = null;
    this.el._fileTransferChannel = null;
    this.el._gameDataChannel = null;
    this._dispatch("lobby_media_pc_closed", {});

    for (const channel of [this.fileChannel, this.gameChannel]) {
      if (channel) {
        channel.onopen = null;
        channel.onclose = null;
        channel.onmessage = null;
      }
    }
    this.fileChannel = null;
    this.gameChannel = null;

    if (this.pc) {
      close(this.pc);
      this.pc = null;
    }
  },
};

export default LobbyWebRTCHook;
