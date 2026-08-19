/**
 * LiveView Hook: LobbyWebRTCHook
 *
 * Owns the single, persistent RTCPeerConnection for a P2P session and
 * multiplexes EVERY feature over it:
 *
 *   - audio/video  → transceivers (the lobby media hook reuses `this.pc`)
 *   - file transfer → DataChannel "filetransfer" (FileTransferHook)
 *   - games         → DataChannel "gamedata"     (LobbyGameCanvasHook)
 *
 * Both data channels are created up front at connection time so that later
 * renegotiation is only ever triggered by media tracks — this avoids glare
 * between "user toggles video" and "game channel opens".
 */
import { log } from "../logger.js";
import {
  createPeerConnection,
  addIceCandidate,
  close,
  onConnectionStateChange,
  onIceConnectionStateChange,
  onIceCandidate,
  onDataChannel,
  createDataChannel,
  RETRY_CONFIG,
} from "./webrtc.js";
import {
  collectConnectionActivity,
  collectFeatureSnapshot,
  deriveFeatureStats,
  hasConnectionActivity,
} from "./media.js";
import {
  advanceEpoch,
  canApplyDescription,
  isStaleEpoch,
  nextConnectionEpoch,
  normalizeEpoch,
  ownsDescription,
} from "./negotiation.js";
import {
  canScheduleSignalReplay,
  signalReplayDelay,
  needsSignalReplay,
  canScheduleRenegotiationRetry,
  renegotiationRetryDelay,
  isFinalRenegotiationAttempt,
  canDeferDisconnectedRecovery,
} from "./signaling_session.js";

// How often the always-on statistics window refreshes its per-feature metrics.
const STATS_INTERVAL_MS = 2500;
const ICE_CANDIDATE_FAILURE_LIMIT = 3;
const SIGNAL_REPLAY_DELAY_MS = 1500;
const SIGNAL_REPLAY_MAX_ATTEMPTS = 3;
const RENEGOTIATION_RETRY_DELAY_MS = 1200;
const RENEGOTIATION_RETRY_MAX_ATTEMPTS = 3;
const DISCONNECTED_ACTIVITY_DEFERRAL_LIMIT = 2;

// Negotiation model: the INITIATOR is the single offerer. Both peers can still
// add media at any time (self-controlled audio/video), but only the initiator
// ever sends offers — the answerer asks the initiator to renegotiate instead
// (`lobby_renegotiate`). This sidesteps the offer glare that "perfect negotiation"
// resolves with rollback but which, in practice, leaves the polite peer's freshly
// received tracks muted (no RTP) when both peers add video at the same instant.
// Single-offerer negotiation, serialized per round.
export function createLobbyConnectionHook() {
  return {
    mounted() {
      this.pc = null;
      this.iceServers = null;
      this.turnOnly = false;
      this.retryCount = 0;
      this.recoveryTimer = null;
      this.recoveryFailed = false;
      this.failedReason = null;
      this.signalingEpoch = 0;
      this.offerSeq = 0;
      this.currentOfferId = null;
      this.activeRemoteOfferId = null;
      this.lastRemoteAnswerOfferId = null;
      this.lastRemoteAnswerSdp = null;
      this.connectionResetPending = false;
      this.disconnectedTimer = null;
      this.disconnectedActivityDeferrals = 0;
      this.role = null;
      this.negotiating = false;
      this.renegotiationQueued = false;
      this.queuedKinds = [];
      this.fileChannel = null;
      this.gameChannel = null;
      this.pendingIceCandidates = [];
      this.remoteIceCandidateKeys = new Set();
      this.iceCandidateFailures = 0;
      this._pendingDescription = null;
      this.statsTimer = null;
      this._statsPrev = null;
      this.signalReplayTimer = null;
      this.signalReplayAttempts = 0;
      this.signalBackoffTimer = null;
      this.signalQueue = Promise.resolve();
      this.renegotiationRetryTimer = null;
      this.renegotiationRetryAttempts = 0;
      this.renegotiationRetryPayload = null;
      this.videoSource = "camera";
      this.recoveryStateEventHandler = (event) => {
        const payload = event.detail || {};

        if (payload.state === "failed") {
          this._notifyFailed(payload.reason || "failed", {
            manualRetry: payload.manual_retry !== false,
          });
        } else if (payload.state === "reconnecting") {
          this._markRecovering();
          this.pushEvent("lobby_retry", {
            attempt: payload.attempt || null,
            reason: payload.reason || "auto_retry",
          });
        }
      };

      this.handleEvent("lobby_start_offer", (data) => this._handleStartOffer(data));
      this.handleEvent("lobby_start_answer", (data) => this._handleStartAnswer(data));
      this.handleEvent("lobby_restart", (data = {}) => this._handleRestart(data));
      this.handleEvent("lobby_signal", (data) => this._handleSignal(data));
      this.handleEvent("lobby_signal_replay", (data) => this._handleSignalReplay(data));
      this.handleEvent("lobby_signal_rejected", (data = {}) => this._handleSignalRejected(data));
      // Answerer → initiator request to (re)offer after the answerer added tracks.
      this.handleEvent("lobby_renegotiate", (data = {}) => this._handleRenegotiate(data));

      // The media hook's stalled-stream watchdog asks us to recover a remote track
      // that negotiated but never started flowing (black frame, no RTP). Most
      // recoveries can renegotiate in place; startup races can request a full
      // coordinated restart through the LiveView.
      this._onMediaRecover = (event) => {
        if (event.detail?.restart) {
          this.pushEvent("lobby_media_restart", {
            reason: event.detail.reason || "media_startup_stalled",
          });
        } else {
          this._recoverMedia();
        }
      };
      this.el.addEventListener("lobby_media_recover", this._onMediaRecover);
      this._onMediaSourceChanged = (event) => {
        this.videoSource = event.detail?.source === "screen" ? "screen" : "camera";
      };
      this.el.addEventListener("lobby_media_source_changed", this._onMediaSourceChanged);
      this.el.addEventListener("p2p-lobby:recovery-state", this.recoveryStateEventHandler);

      this.pushEvent("lobby_webrtc_ready", {});
    },

    destroyed() {
      this.el.removeEventListener("lobby_media_recover", this._onMediaRecover);
      this.el.removeEventListener("lobby_media_source_changed", this._onMediaSourceChanged);
      this.el.removeEventListener("p2p-lobby:recovery-state", this.recoveryStateEventHandler);
      this._cleanup();
    },

    reconnected() {
      this._requestSignalReplay("liveview_reconnected");
      this._scheduleSignalReplay("liveview_reconnected");
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
      this._markRecovering();
      // NB: do NOT reset pendingIceCandidates here — the peer's ICE candidates can
      // arrive before this event and must survive until the PC has a remote desc.

      try {
        await this._createConnection();
        this._scheduleSignalReplay("start_offer");
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
      this._markRecovering();
      // NB: do NOT reset pendingIceCandidates here — the initiator's ICE candidates
      // routinely arrive before this event and must survive until setRemoteDescription.

      try {
        await this._createConnection();
        this._scheduleSignalReplay("start_answer");
        // The initiator's offer can arrive before this event; apply it now.
        if (this._pendingDescription) {
          const pending = this._pendingDescription;
          this._pendingDescription = null;
          await this._handleSignal(pending);
        }
      } catch (error) {
        this._failConnection("answer", error);
      }
    },

    async _handleRestart({ epoch, ice_servers, turn_only, reason } = {}) {
      if (ice_servers) this.iceServers = ice_servers;
      if (typeof turn_only === "boolean") this.turnOnly = turn_only;
      const restartReason = reason || "manual_retry";

      if (!this.role || !this.iceServers) {
        this.pushEvent("lobby_failed", { reason: "restart_unavailable" });
        return;
      }

      this._clearDisconnectedTimer();
      this._clearRecoveryTimer();
      this._markRecovering();
      this._stopStatsPolling();
      this.retryCount = 0;

      try {
        await this._createConnection({ epoch });

        if (this.role === "initiator") {
          window.setTimeout(() => {
            if (!this.pc || this.negotiating || this.pc.signalingState !== "stable") return;
            this._maybeOffer([], { connectionReset: true, recover: true });
          }, 0);
        } else {
          this._requestRenegotiation(true, {
            reason: restartReason,
            connectionReset: true,
          });
        }
      } catch (error) {
        this._failConnection(restartReason, error);
      }
    },

    async _handleSignal(data) {
      this.signalQueue = this.signalQueue.catch(() => {}).then(() => this._applySignal(data));

      return this.signalQueue;
    },

    // The connection validates a description when its turn in the operation queue
    // comes, not when it is handed over. Two signals arriving in the same tick
    // therefore both pass a state check made at call time, and the second one
    // throws — so serialise here and let each be judged against the state its
    // predecessor actually left behind.
    async _applySignal(data) {
      if (data.type === "ice-candidate") {
        await this._handleRemoteCandidate(data);
      } else {
        await this._handleRemoteDescription(data);
      }
    },

    // The server dropped a signal instead of relaying it. Every retry sent inside
    // the window it names is another signal against the same budget, so the
    // retries are what hold the window shut. Stand down for as long as the server
    // asked, then resync from the peer's stored signalling rather than guessing
    // which descriptions and candidates went missing.
    _handleSignalRejected({ code, retry_after_ms: retryAfterMs } = {}) {
      log.warn("[Lobby] Server rejected a signal", { code, retryAfterMs });

      if (code !== "rate_limited") return;

      this._clearSignalReplayTimer();
      this._clearRenegotiationRetry();
      this._clearSignalBackoff();

      this.signalBackoffTimer = setTimeout(
        () => {
          this.signalBackoffTimer = null;
          if (this.recoveryFailed || !this.pc) return;

          this.signalReplayAttempts = 0;
          this.renegotiationRetryAttempts = 0;
          this._requestSignalReplay("signal_rate_limited");
          this._scheduleSignalReplay("signal_rate_limited");
        },
        Math.max(Number(retryAfterMs) || 0, 0),
      );
    },

    _clearSignalBackoff() {
      if (this.signalBackoffTimer) {
        clearTimeout(this.signalBackoffTimer);
        this.signalBackoffTimer = null;
      }
    },

    async _handleSignalReplay({ events = [] } = {}) {
      for (const entry of events || []) {
        const event = entry?.event;
        const payload = entry?.payload || {};

        if (event === "lobby_signal") {
          await this._handleSignal(payload);
        } else if (event === "lobby_renegotiate") {
          await this._handleRenegotiate(payload);
        }
      }
    },

    // --- Single-offerer negotiation ---

    async _handleRemoteDescription(data) {
      const epoch = normalizeEpoch(data.epoch);

      if (this._isStaleEpoch(epoch)) {
        log.warn("[Lobby] Ignoring stale remote description", {
          remoteEpoch: epoch,
          currentEpoch: this.signalingEpoch,
          type: data.type,
        });
        return;
      }

      // Single-offerer: the initiator only ever applies answers, the answerer only
      // ever applies offers. A description of the other kind is a misroute or a
      // replay aimed at the peer; applying it desyncs the state machine and every
      // later description for this round becomes unapplicable.
      if (!ownsDescription(this.role, data.type)) {
        log.warn(`[Lobby] Ignoring ${data.type} meant for the peer (role=${this.role})`);
        return;
      }

      // The offer can arrive before the answerer's "lobby_start_answer" event has
      // built the PC. Buffer it (we only ever keep the latest) so _handleStartAnswer
      // can apply it once the connection — and its ICE servers — exist.
      if (!this.pc) {
        if (data.type === "offer") this._pendingDescription = data;
        return;
      }

      try {
        if (data.type === "offer") {
          if (data.offer_id && this.activeRemoteOfferId === data.offer_id) return;

          // A peer that rebuilt its connection re-offers from a fresh m-line
          // layout, which no longer extends the one this side settled on. Only a
          // matching rebuild can accept it, and the epoch does not have to advance
          // for the peer's connection to be new — the reset flag alone decides.
          if (data.connection_reset) {
            await this._createConnection({ epoch: epoch || undefined });
          } else if (epoch && epoch > this.signalingEpoch) {
            this.signalingEpoch = epoch;
          }

          if (!this._canApplyDescription("offer")) return;

          // Answerer path: apply the initiator's offer and answer it.
          await this.pc.setRemoteDescription({ type: "offer", sdp: data.sdp });
          await this._flushPendingIceCandidates();
          await this.pc.setLocalDescription();
          this.activeRemoteOfferId = data.offer_id || null;
          this._clearRenegotiationRetry();
          this.pushEvent("lobby_signal", {
            type: this.pc.localDescription.type,
            sdp: this.pc.localDescription.sdp,
            epoch: this.signalingEpoch,
            offer_id: this.activeRemoteOfferId,
          });
        } else {
          if (
            (data.offer_id && this.lastRemoteAnswerOfferId === data.offer_id) ||
            (!data.offer_id && data.sdp && this.lastRemoteAnswerSdp === data.sdp)
          ) {
            return;
          }

          if (epoch && epoch !== this.signalingEpoch) {
            log.warn("[Lobby] Ignoring answer for a different epoch", {
              remoteEpoch: epoch,
              currentEpoch: this.signalingEpoch,
            });
            return;
          }

          if (data.offer_id && this.currentOfferId && data.offer_id !== this.currentOfferId) {
            log.warn("[Lobby] Ignoring answer for a stale offer", {
              offerId: data.offer_id,
              currentOfferId: this.currentOfferId,
            });
            return;
          }

          if (!this._canApplyDescription("answer")) return;

          // Initiator path: apply the answerer's answer, then drain any queued
          // renegotiation that arrived while this one was in flight.
          await this.pc.setRemoteDescription({ type: "answer", sdp: data.sdp });
          await this._flushPendingIceCandidates();
          this.lastRemoteAnswerOfferId = data.offer_id || null;
          this.lastRemoteAnswerSdp = data.sdp || null;
          this.negotiating = false;
          this.currentOfferId = null;
          if (this.renegotiationQueued) {
            this.renegotiationQueued = false;
            this._maybeOffer();
          }
        }
      } catch (error) {
        this.negotiating = false;
        this.currentOfferId = null;
        this._recoverSignalingFailure("remote_description", error);
      }
    },

    // Answerer asks the initiator to (re)offer after it added local tracks. The
    // request carries the track kinds so the initiator can pre-create matching
    // recvonly transceivers, keeping the m-line layout aligned on both sides.
    _requestRenegotiation(recover = false, options = {}) {
      const transceivers = this.pc?.getTransceivers?.() || [];
      const kinds = transceivers
        .map((t) => t.sender && t.sender.track && t.sender.track.kind)
        .filter(Boolean);
      const payload = {
        kinds,
        recover,
        epoch: this.signalingEpoch,
        reason: options.reason || null,
        attempt: options.attempt || null,
        connection_reset: options.connectionReset === true,
      };

      this.pushEvent("lobby_renegotiate", payload);
      this._scheduleRenegotiationRetry(payload);
    },

    async _handleRenegotiate({ kinds = [], recover = false, epoch, connection_reset }) {
      if (this.role !== "initiator" || !this.pc) return;
      const requestedEpoch = normalizeEpoch(epoch);
      if (this._isStaleEpoch(requestedEpoch)) return;

      if (connection_reset) {
        try {
          await this._createConnection({ epoch: requestedEpoch || undefined });
        } catch (error) {
          this._failConnection("renegotiate_reset", error);
          return;
        }
      } else if (recover) {
        this._advanceSignalingEpoch(requestedEpoch);
        if (this.pc.restartIce) this.pc.restartIce();
      }

      this._maybeOffer(kinds, { recover, connectionReset: connection_reset === true });
    },

    // Recover a stalled media stream. Only the initiator can restart ICE, so the
    // answerer routes the request through the initiator (single-offerer model).
    _recoverMedia() {
      if (!this.pc) return;
      if (this.role === "initiator") {
        this._advanceSignalingEpoch();
        if (this.pc.restartIce) this.pc.restartIce();
        this._maybeOffer([], { recover: true });
      } else {
        this._advanceSignalingEpoch();
        this._requestRenegotiation(true, { reason: "media_recover" });
      }
    },

    // Initiator-only. Serialized so two changes can't race into two offers.
    async _maybeOffer(ensureKinds = [], options = {}) {
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
        this.offerSeq += 1;
        this.currentOfferId = `p2p-${this.signalingEpoch}-${this.offerSeq}`;
        const connectionReset = options.connectionReset || this.connectionResetPending;
        this.connectionResetPending = false;
        this.pushEvent("lobby_signal", {
          type: this.pc.localDescription.type,
          sdp: this.pc.localDescription.sdp,
          epoch: this.signalingEpoch,
          offer_id: this.currentOfferId,
          recover: options.recover === true,
          connection_reset: connectionReset === true,
        });
        this._scheduleSignalReplay("offer_wait");
      } catch (error) {
        this.negotiating = false;
        this.currentOfferId = null;
        this._recoverSignalingFailure("offer_create", error);
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

      const epoch = normalizeEpoch(data.epoch);
      if (this._isStaleEpoch(epoch)) return;
      const key = this._remoteCandidateKey(data.candidate, epoch);
      if (this.remoteIceCandidateKeys.has(key)) return;

      if (!this.pc || !this.pc.remoteDescription) {
        if (this._pendingIceCandidateKeys().has(key)) return;
        this.pendingIceCandidates.push({ candidate: data.candidate, epoch });
        return;
      }

      if (epoch && epoch > this.signalingEpoch) {
        if (this._pendingIceCandidateKeys().has(key)) return;
        this.pendingIceCandidates.push({ candidate: data.candidate, epoch });
        return;
      }

      try {
        await addIceCandidate(this.pc, data.candidate);
        this.remoteIceCandidateKeys.add(key);
        this.iceCandidateFailures = 0;
      } catch (error) {
        this._recordIceCandidateFailure(error);
      }
    },

    async _flushPendingIceCandidates() {
      if (!this.pc || !this.pc.remoteDescription || this.pendingIceCandidates.length === 0) {
        return;
      }

      const candidates = this.pendingIceCandidates.splice(0);
      const keep = [];
      for (const entry of candidates) {
        const candidate = entry.candidate || entry;
        const epoch = normalizeEpoch(entry.epoch);
        const key = this._remoteCandidateKey(candidate, epoch);

        if (this._isStaleEpoch(epoch)) continue;
        if (this.remoteIceCandidateKeys.has(key)) continue;
        if (epoch && epoch > this.signalingEpoch) {
          keep.push(entry);
          continue;
        }

        try {
          await addIceCandidate(this.pc, candidate);
          this.remoteIceCandidateKeys.add(key);
          this.iceCandidateFailures = 0;
        } catch (error) {
          this._recordIceCandidateFailure(error);
        }
      }
      this.pendingIceCandidates.push(...keep);
    },

    _pendingIceCandidateKeys() {
      return new Set(
        this.pendingIceCandidates.map((entry) =>
          this._remoteCandidateKey(entry.candidate || entry, normalizeEpoch(entry.epoch)),
        ),
      );
    },

    _remoteCandidateKey(candidate, epoch = null) {
      return [
        epoch || "",
        candidate?.candidate || "",
        candidate?.sdpMid || "",
        candidate?.sdpMLineIndex ?? "",
      ].join("|");
    },

    _recordIceCandidateFailure(error) {
      log.warn("[Lobby] Failed to add ICE candidate", error);
      this.iceCandidateFailures = (this.iceCandidateFailures || 0) + 1;

      if (this.iceCandidateFailures >= ICE_CANDIDATE_FAILURE_LIMIT) {
        this._recoverSignalingFailure("ice_candidate", error);
      }
    },

    // --- Connection management ---

    async _createConnection({ epoch } = {}) {
      const nextEpoch = nextConnectionEpoch(this.signalingEpoch, epoch);

      if (this.pc) {
        // Rebuilding for a retry: candidates/descriptions for the old PC are stale.
        close(this.pc);
        this.pendingIceCandidates = this.pendingIceCandidates.filter((entry) => {
          const pendingEpoch = normalizeEpoch(entry.epoch);
          return pendingEpoch && pendingEpoch >= nextEpoch;
        });
        this._pendingDescription = null;
      }

      this.signalingEpoch = nextEpoch;
      this.offerSeq = 0;
      this.currentOfferId = null;
      this.activeRemoteOfferId = null;
      this.lastRemoteAnswerOfferId = null;
      this.lastRemoteAnswerSdp = null;
      this.connectionResetPending = true;
      this.remoteIceCandidateKeys = new Set();
      this.iceCandidateFailures = 0;
      this._clearSignalReplayTimer();
      this._clearRenegotiationRetry();
      this.signalReplayAttempts = 0;
      this.renegotiationRetryAttempts = 0;

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
            epoch: this.signalingEpoch,
          });
        }
      });

      onConnectionStateChange(this.pc, (state) => this._handleConnectionStateChange(state));
      onIceConnectionStateChange(this.pc, (state) => this._handleIceConnectionStateChange(state));

      this.pc.onicecandidateerror = (event) => {
        log.warn("[Lobby] ICE candidate error", event.errorCode, event.errorText);
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

      // Hand the connection over now, not once it reports "connected". The media
      // hook wires `ontrack` here, so remote tracks are caught as their offer is
      // applied instead of being back-filled from the receivers afterwards, and
      // the local camera and microphone ride this first offer rather than forcing
      // a second negotiation round the moment the call comes up.
      this.el._peerConnection = this.pc;
      this._dispatch("lobby_media_pc_ready", { pc: this.pc });
    },

    // File transfer and games want opposite things from the same SCTP
    // association, so they are configured as opposites.
    //
    // A file must arrive intact and in order, and it is happy to wait. Game state
    // must arrive *now*: a snapshot is superseded by the next one 16 ms later, so
    // retransmitting a lost one delivers stale truth, and delivering it in order
    // holds every fresher snapshot behind it. That head-of-line blocking is what
    // turns a single dropped datagram into a freeze-then-jump on the guest, which
    // is why the game channel is unreliable and unordered.
    //
    // Priority is the other half: without it a 64 KB file chunk transmits ahead of
    // a 25-byte snapshot simply for being queued first.
    _createOutgoingChannels() {
      const fileChannel = createDataChannel(this.pc, "filetransfer", {
        ordered: true,
        priority: "low",
      });
      fileChannel.binaryType = "arraybuffer";
      this._setupFileChannel(fileChannel);

      const gameChannel = createDataChannel(this.pc, "gamedata", {
        ordered: false,
        maxRetransmits: 0,
        priority: "high",
      });
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
          this._clearRecoveryTimer();
          this._clearSignalReplayTimer();
          this._markRecovering();
          this.disconnectedActivityDeferrals = 0;
          this.retryCount = 0;
          this.pushEvent("lobby_connected", {});
          this._startStatsPolling();
          break;

        case "disconnected":
          this._startDisconnectedGracePeriod("connection_disconnected");
          break;

        case "failed":
          this._clearDisconnectedTimer();
          this._stopStatsPolling();
          this._handleFailure("connection_failed");
          break;

        case "closed":
          this._clearDisconnectedTimer();
          this._stopStatsPolling();
          break;
      }
    },

    _handleIceConnectionStateChange(state) {
      switch (state) {
        case "connected":
        case "completed":
          this._clearDisconnectedTimer();
          this._clearSignalReplayTimer();
          break;

        case "disconnected":
          this._startDisconnectedGracePeriod("ice_disconnected");
          break;

        case "failed":
          this._clearDisconnectedTimer();
          this._stopStatsPolling();
          this._handleFailure("ice_failed");
          break;

        case "closed":
          this._clearDisconnectedTimer();
          this._stopStatsPolling();
          break;
      }
    },

    _startDisconnectedGracePeriod(reason = "disconnected", { preserveDeferrals = false } = {}) {
      const hadDisconnectedTimer = !!this.disconnectedTimer;
      this._clearDisconnectedTimer({ resetDeferrals: !preserveDeferrals });
      const pc = this.pc;
      const beforeActivity = collectConnectionActivity(pc);

      if (!preserveDeferrals && !hadDisconnectedTimer) {
        this.pushEvent("lobby_recovery_pending", { reason });
      }

      this.disconnectedTimer = setTimeout(async () => {
        this.disconnectedTimer = null;
        if (this.pc !== pc) return;

        if (
          this.pc &&
          (this.pc.connectionState === "disconnected" ||
            this.pc.iceConnectionState === "disconnected")
        ) {
          if (await this._deferDisconnectedRecoveryForActivity(beforeActivity, reason)) {
            return;
          }

          this._handleFailure(reason);
        }
      }, RETRY_CONFIG.disconnectedGracePeriod);
    },

    async _deferDisconnectedRecoveryForActivity(beforeActivity, reason) {
      const before = await beforeActivity;
      const after = await collectConnectionActivity(this.pc);

      if (!hasConnectionActivity(before, after)) {
        this.disconnectedActivityDeferrals = 0;
        return false;
      }

      const deferrals = this.disconnectedActivityDeferrals || 0;

      if (!canDeferDisconnectedRecovery(deferrals, DISCONNECTED_ACTIVITY_DEFERRAL_LIMIT)) {
        this.disconnectedActivityDeferrals = 0;
        return false;
      }

      this.disconnectedActivityDeferrals = deferrals + 1;
      log.debug("[Lobby] Deferring disconnected recovery while media/data still moves", {
        reason,
        deferrals: this.disconnectedActivityDeferrals,
      });
      this._startDisconnectedGracePeriod(reason, { preserveDeferrals: true });
      return true;
    },

    _handleFailure(reason = "auto_retry") {
      if (this.recoveryFailed || this.recoveryTimer) return;

      this._clearSignalReplayTimer();
      this._clearRenegotiationRetry();

      if (this.retryCount < RETRY_CONFIG.maxAttempts) {
        const attempt = this.retryCount + 1;
        const delay = RETRY_CONFIG.delays[this.retryCount];
        this.retryCount = attempt;
        const retryReason = reason || "auto_retry";

        this.pushEvent("lobby_retry", { attempt, reason: retryReason });

        this.recoveryTimer = setTimeout(async () => {
          this.recoveryTimer = null;
          if (this.recoveryFailed) return;

          try {
            // Rebuilding the connection re-creates the data channels on the
            // initiator, which triggers onnegotiationneeded → a fresh offer.
            await this._createConnection();
            if (this.role === "answerer") {
              this._requestRenegotiation(true, {
                attempt,
                reason: retryReason,
                connectionReset: true,
              });
            }
          } catch (error) {
            this._failConnection("retry", error);
          }
        }, delay);
      } else {
        this._notifyFailed("max_retries_exhausted");
      }
    },

    _failConnection(phase, error) {
      log.error(`[Lobby] connection ${phase} failed`, error);
      this._notifyFailed(`${phase}_failed`);
    },

    _recoverSignalingFailure(phase, error) {
      log.warn(`[Lobby] signaling ${phase} failed`, error);
      this._handleFailure(phase);
    },

    // Which description kind this side is responsible for applying. Unknown until
    // the LiveView assigns a role, and until then nothing is filtered out: the
    // initiator's offer routinely beats "lobby_start_answer" to the client.
    // setRemoteDescription throws when the connection cannot accept the kind of
    // description on offer, and the catch turns that throw into a full rebuild —
    // which re-sends the signals that caused it. Screen the state first so a
    // stray description is dropped rather than escalated into a reconnect.
    _canApplyDescription(type) {
      const state = this.pc.signalingState;
      const applicable = canApplyDescription(state, type);

      if (!applicable) {
        log.warn(`[Lobby] Ignoring ${type} in signalingState=${state}`);
      }

      return applicable;
    },

    _advanceSignalingEpoch(value) {
      this.signalingEpoch = advanceEpoch(this.signalingEpoch, value);
      this.offerSeq = 0;
      this.currentOfferId = null;
    },

    _isStaleEpoch(epoch) {
      return isStaleEpoch(this.signalingEpoch, epoch);
    },

    _markRecovering() {
      this.recoveryFailed = false;
      this.failedReason = null;
    },

    _notifyFailed(reason, { manualRetry = true } = {}) {
      if (this.recoveryFailed) return;

      this._clearRecoveryTimer();
      this.recoveryFailed = true;
      this.failedReason = reason;
      this.pushEvent("lobby_failed", {
        reason,
        manual_retry: manualRetry,
      });
    },

    _clearDisconnectedTimer({ resetDeferrals = true } = {}) {
      if (this.disconnectedTimer) {
        clearTimeout(this.disconnectedTimer);
        this.disconnectedTimer = null;
      }
      if (resetDeferrals) this.disconnectedActivityDeferrals = 0;
    },

    _clearRecoveryTimer() {
      if (this.recoveryTimer) {
        clearTimeout(this.recoveryTimer);
        this.recoveryTimer = null;
      }
    },

    _scheduleSignalReplay(reason) {
      if (
        !canScheduleSignalReplay(
          this.signalReplayAttempts,
          SIGNAL_REPLAY_MAX_ATTEMPTS,
          !!this.signalReplayTimer,
        )
      ) {
        return;
      }

      const attempt = this.signalReplayAttempts + 1;
      this.signalReplayAttempts = attempt;

      this.signalReplayTimer = setTimeout(
        () => {
          this.signalReplayTimer = null;
          if (!this._needsSignalReplay()) return;

          this._requestSignalReplay(reason, attempt);
          this._scheduleSignalReplay(reason);
        },
        signalReplayDelay(attempt, SIGNAL_REPLAY_DELAY_MS),
      );
    },

    _needsSignalReplay() {
      return needsSignalReplay({
        hasPc: !!this.pc,
        connectionState: this.pc?.connectionState,
        iceConnectionState: this.pc?.iceConnectionState,
        recoveryFailed: this.recoveryFailed,
      });
    },

    _requestSignalReplay(reason, attempt = null) {
      if (!this.role) return;

      this.pushEvent("lobby_signal_replay_request", {
        reason,
        attempt,
        epoch: this.signalingEpoch || null,
        offer_id: this.currentOfferId || this.activeRemoteOfferId || this.lastRemoteAnswerOfferId,
      });
    },

    _clearSignalReplayTimer() {
      if (this.signalReplayTimer) {
        clearTimeout(this.signalReplayTimer);
        this.signalReplayTimer = null;
      }
    },

    _scheduleRenegotiationRetry(payload) {
      if (this.role === "answerer") {
        this.renegotiationRetryPayload = payload;
      }

      if (
        !canScheduleRenegotiationRetry(
          this.role,
          this.renegotiationRetryAttempts,
          RENEGOTIATION_RETRY_MAX_ATTEMPTS,
          !!this.renegotiationRetryTimer,
        )
      ) {
        return;
      }

      const attempt = this.renegotiationRetryAttempts + 1;
      this.renegotiationRetryAttempts = attempt;

      this.renegotiationRetryTimer = setTimeout(
        () => {
          this.renegotiationRetryTimer = null;
          if (this.role !== "answerer" || !this.pc || this.recoveryFailed) return;

          this.pushEvent("lobby_renegotiate", {
            ...this.renegotiationRetryPayload,
            retry_attempt: attempt,
          });

          if (isFinalRenegotiationAttempt(attempt, RENEGOTIATION_RETRY_MAX_ATTEMPTS)) {
            this._recoverSignalingFailure(
              "renegotiate_request",
              new Error("renegotiation request was not answered"),
            );
            return;
          }

          this._scheduleRenegotiationRetry(this.renegotiationRetryPayload);
        },
        renegotiationRetryDelay(attempt, RENEGOTIATION_RETRY_DELAY_MS),
      );
    },

    _clearRenegotiationRetry() {
      if (this.renegotiationRetryTimer) {
        clearTimeout(this.renegotiationRetryTimer);
        this.renegotiationRetryTimer = null;
      }
      this.renegotiationRetryPayload = null;
      this.renegotiationRetryAttempts = 0;
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
        stats.video.source = this.videoSource;
        stats.summary = {
          connection_state: this.pc.connectionState || "",
          ice_connection_state: this.pc.iceConnectionState || "",
          signaling_epoch: this.signalingEpoch || 0,
          offer_id:
            this.currentOfferId || this.activeRemoteOfferId || this.lastRemoteAnswerOfferId || "",
        };
        this.pushEvent("lobby_stats", stats);
      } catch (error) {
        log.warn("[Lobby] Failed to sample stats", error);
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
      this._clearRecoveryTimer();
      this._clearSignalReplayTimer();
      this._clearRenegotiationRetry();
      this._clearSignalBackoff();
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
      this.pendingIceCandidates = [];
      this.remoteIceCandidateKeys = new Set();
      this.iceCandidateFailures = 0;
      this.signalReplayAttempts = 0;
      this.renegotiationRetryAttempts = 0;

      if (this.pc) {
        close(this.pc);
        this.pc = null;
      }
    },
  };
}
