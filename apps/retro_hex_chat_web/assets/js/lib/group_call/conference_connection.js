/**
 * Conference connection controller (framework-free).
 *
 * Minimal browser-side SFU client owning the raw Phoenix Channel (so SDP/ICE do
 * not travel through the ChatLive process), the RTCPeerConnection, media, tiles,
 * quality, reactions, recovery and stats for a group call. It knows nothing about
 * LiveView: `createConferenceConnection(el, ports)` takes the hook element and a
 * `{ pushEvent }` port, and a test drives it through its public surface
 * (mount/destroy, the server-event methods, the pc/channel events it wires)
 * without a LiveSocket. `hooks/group_call/group_call_webrtc_hook.js` is the thin
 * binding that registers the LiveView events onto it.
 *
 * This file holds the controller's core — mount, the channel, joining, offers,
 * candidates, streams and teardown. Its other methods are mixed in from
 * factories beside it, sharing the same `this`: `conference_tiles.js`,
 * `conference_reactions.js`, `conference_local_media.js`,
 * `conference_screen_share.js`, `conference_recovery.js` and
 * `conference_stats.js`.
 */
import { Socket } from "phoenix";
import { t } from "../i18n.js";
import { log } from "../logger.js";
import { captureConstraints } from "../p2p/device_constraints.js";
import { createPeerConnection } from "../p2p/webrtc.js";
import { stringOrNull } from "./payload.js";
import { createTrackRegistry } from "./track_registry.js";
import { createParticipantRegistry } from "./participant_registry.js";
import { createTileView } from "./tile_view.js";
import { mediaStateFromDataset } from "./media_state.js";
import { attachMediaStream, applyMediaProfile, applyTrackHints, setSinkId } from "../p2p/media.js";
import { screenShareMethods } from "./conference_screen_share.js";
import { statsMethods } from "./conference_stats.js";
import { localMediaMethods } from "./conference_local_media.js";
import { RECOVERY_BACKOFF_MS, recoveryMethods } from "./conference_recovery.js";
import { reactionMethods } from "./conference_reactions.js";
import { tileMethods } from "./conference_tiles.js";
const ICE_CANDIDATE_FAILURE_LIMIT = 3;

function emptyMediaStream() {
  if (typeof MediaStream === "function") return new MediaStream();

  return {
    getTracks: () => [],
    getAudioTracks: () => [],
    getVideoTracks: () => [],
  };
}

export function createConferenceConnection(el, ports) {
  return {
    ...tileMethods(el, ports),
    ...reactionMethods(el, ports),
    ...recoveryMethods(el, ports),
    ...localMediaMethods(el, ports),
    ...statsMethods(el, ports),
    ...screenShareMethods(el, ports),

    mount() {
      this.roomToken = el.dataset.groupCallToken;
      this.joinToken = el.dataset.joinToken;
      this.localStream = null;
      this.pc = null;
      this.socket = null;
      this.channel = null;
      this.pendingCandidates = [];
      this.remoteCandidateFailures = 0;
      this.participantId = stringOrNull(el.dataset.participantId);
      this.mediaEnabled = this._mediaStateFromDataset();
      this.serverAudioMuted = false;
      this.serverVideoBlocked = false;
      this.devicePreferences = this._devicePreferencesFromDataset();
      this.closing = false;
      this.offerQueue = Promise.resolve();
      this.lastAnsweredOfferSdp = null;
      this.lastAnsweredOfferId = null;
      this.layoutState = this._layoutStateFromDataset();
      this.participantRegistry = createParticipantRegistry();
      this.trackRegistry = createTrackRegistry();
      this.tileView = createTileView(el, {
        onToggleFocus: (tile) => this._toggleTileFocus(tile),
      });
      this.remoteVideoStalls = new Map();
      this.statsTimer = null;
      this.statsPrev = null;
      this.localSenders = [];
      this._sendersPc = null;
      this.recoveryTimer = null;
      this.recoveryAttempts = 0;
      this.recoveryActivityDeferrals = 0;
      this.maxRecoveryAttempts = RECOVERY_BACKOFF_MS.length;
      this.offerWatchdogTimer = null;
      this.offerWatchdogAttempts = 0;
      this.rejoinEpoch = 0;
      this.rejoining = false;
      this.participantStatsPrev = null;
      this.participantQualityById = new Map();
      this.activeSpeakerParticipantId = null;
      this.reactionTimers = new Map();
      this.pushToTalkActive = false;
      this.pushToTalkRestoreAudio = null;
      this.videoSender = null;
      this.cameraVideoTrack = null;
      this.screenShare = {
        active: false,
        stream: null,
        track: null,
      };
      this.screenShareBlocked = false;
      this.toggleScreenShareHandler = () => {
        this._toggleScreenShare();
      };
      this.screenShareClickHandler = (event) => {
        const button = event.target?.closest?.("[data-group-call-screen-share-for]");
        if (!button || button.dataset.groupCallScreenShareFor !== this.roomToken) return;

        event.preventDefault();
        this._toggleScreenShare();
      };
      this.reactionClickHandler = (event) => {
        const button = event.target?.closest?.("[data-group-call-reaction]");
        if (!button || button.dataset.groupCallReactionFor !== this.roomToken) return;

        event.preventDefault();
        this._sendReaction(button.dataset.groupCallReaction);
      };
      this.pushToTalkKeydownHandler = (event) => {
        this._handlePushToTalkKeydown(event);
      };
      this.pushToTalkKeyupHandler = (event) => {
        this._handlePushToTalkKeyup(event);
      };
      this.participantQualityEventHandler = (event) => {
        const payload = event.detail || {};
        if (payload.token && payload.token !== this.roomToken) return;

        this._syncParticipantQualityState(payload);
        ports.pushEvent("group_call_participant_quality", payload);
      };
      this.recoveryStateEventHandler = (event) => {
        const payload = event.detail || {};
        if (payload.token && payload.token !== this.roomToken) return;

        ports.pushEvent("group_call_recovery_state", payload);
      };

      if (!this.roomToken || !this.joinToken) {
        log.warn("[group-call] missing room token or join token");
        return;
      }

      this._bindLocalTile();
      el.addEventListener("group-call:toggle-screen-share", this.toggleScreenShareHandler);
      el.addEventListener("group-call:participant-quality", this.participantQualityEventHandler);
      el.addEventListener("group-call:recovery-state", this.recoveryStateEventHandler);
      document.addEventListener("click", this.screenShareClickHandler);
      document.addEventListener("click", this.reactionClickHandler);
      document.addEventListener("keydown", this.pushToTalkKeydownHandler, true);
      document.addEventListener("keyup", this.pushToTalkKeyupHandler, true);
      this._applyLayout();
      this._connect();
      ports.pushEvent("group_call_webrtc_ready", {});
    },

    destroy() {
      this._cleanup();
    },

    _connect() {
      this.socket = new Socket("/socket");
      this.socket.connect();

      this.channel = this.socket.channel(`group_call:${this.roomToken}`, {
        join_token: this.joinToken,
      });

      this.channel.on("group_call_joined", (payload) => this._handleJoined(payload));
      this.channel.on("group_call_offer", (payload) => {
        ports.pushEvent("group_call_offer_received", {
          participant_id: payload?.participant_id,
        });
        this._handleOffer(payload);
      });
      this.channel.on("group_call_ice_candidate", (payload) => {
        this._handleRemoteCandidate(payload.candidate);
      });
      this.channel.on("group_call_peer_joined", (payload) => {
        this._upsertParticipant(payload?.participant);
        ports.pushEvent("group_call_peer_joined", payload);
      });
      this.channel.on("group_call_peer_left", (payload) => {
        this._removeParticipant(payload?.participant_id);
        ports.pushEvent("group_call_peer_left", payload);
      });
      this.channel.on("group_call_track_added", (payload) => {
        this._syncTrack(payload?.track);
        ports.pushEvent("group_call_track_added", payload);
      });
      this.channel.on("group_call_media_state", (payload) => {
        this._upsertParticipant(payload?.participant);
        ports.pushEvent("group_call_media_state", payload);
      });
      this.channel.on("group_call_screen_share_state", (payload) => {
        this._upsertParticipant(payload?.participant);
        this._syncTrack(payload?.track);
        this._applyScreenShareStateToTiles(payload || {});
        ports.pushEvent("group_call_screen_share_state", payload);
      });
      this.channel.on("group_call_reaction", (payload) => {
        this._applyReaction(payload || {});
        ports.pushEvent("group_call_reaction", payload || {});
      });
      this.channel.on("group_call_reaction_error", (payload) => {
        this._notifyWarning(
          payload?.message || t("Could not send your reaction."),
          "reaction_failed",
        );
      });
      this.channel.on("group_call_set_media_state", (payload) => {
        this.setMediaState(payload || {});
        ports.pushEvent("group_call_media_state_forced", payload || {});
      });
      this.channel.on("group_call_stop_screen_share", (payload) => {
        this.stopScreenShareByModerator(payload || {});
      });
      this.channel.on("group_call_track_updated", (payload) => {
        this._syncTrack(payload?.track);
        ports.pushEvent("group_call_track_updated", payload);
      });
      this.channel.on("group_call_track_removed", (payload) => {
        this._removeTrack(payload?.track_id);
        ports.pushEvent("group_call_track_removed", payload);
      });
      this.channel.on("group_call_closed", (payload) => {
        ports.pushEvent("group_call_closed", payload);
        this._cleanup();
      });
      this.channel.on("group_call_error", (payload) => {
        log.warn("[group-call] signaling error", payload);
        ports.pushEvent("group_call_client_error", payload);
      });
      this.channel.onError(() => {
        if (!this.closing) {
          this._notifyError(t("The call could not reach the server"), "signaling_failed");
        }
      });
      this.channel.onClose(() => {
        if (!this.closing && this.participantId) {
          this._notifyWarning(t("The call lost its link to the server"), "signaling_closed");
        }
      });

      this.channel
        .join()
        .receive("ok", () => {
          this._joinGroupCall("initial");
        })
        .receive("error", (reply) => {
          log.warn("[group-call] channel join rejected", reply);
          this._notifyError(
            reply?.reason || t("The group call refused to let you in"),
            "channel_join_rejected",
          );
        })
        .receive("timeout", () => {
          log.warn("[group-call] channel join timed out");
          this._notifyError(t("The call did not answer in time"), "channel_join_timeout");
        });
    },

    _joinGroupCall(trigger = "initial", extra = {}) {
      const push = this.channel?.push("group_call_join", {
        client_info: this._clientInfo(),
        media_constraints: this.mediaEnabled,
        previous_participant_id: extra.previousParticipantId || this.participantId,
        rejoin_epoch: this.rejoinEpoch,
        trigger,
      });

      if (!push?.receive) {
        this._notifyError(t("Could not join the group call"), "join_failed");
        return null;
      }

      push
        .receive("error", (reply) => {
          this.rejoining = false;
          if (trigger !== "initial") {
            this._publishRecoveryState({
              state: "failed",
              trigger,
              attempt: this.recoveryAttempts,
              max_attempts: this.maxRecoveryAttempts,
              manual_retry: true,
              message: reply?.message || t("Could not join the group call"),
            });
          }
          this._notifyError(reply?.message || t("Could not join the group call"), "join_failed");
        })
        .receive("timeout", () => {
          this.rejoining = false;
          if (trigger !== "initial") {
            this._publishRecoveryState({
              state: "failed",
              trigger,
              attempt: this.recoveryAttempts,
              max_attempts: this.maxRecoveryAttempts,
              manual_retry: true,
              message: t("The call took too long to let you in"),
            });
          }
          this._notifyError(t("The call took too long to let you in"), "join_timeout");
        });

      return push;
    },

    _handleOffer(payload) {
      this._applyStreamOwners(payload?.stream_participants);
      this.offerQueue = this.offerQueue
        .catch(() => {})
        .then(() => this._processOffer(payload || {}));

      return this.offerQueue;
    },

    _handleJoined(payload = {}) {
      this.participantId = payload?.participant?.id || null;
      this.rejoining = false;
      this._upsertParticipant(payload?.participant);
      this._syncParticipants(payload?.participants || []);
      this._syncTracks(payload?.tracks || []);
      this._syncLocalTile();
      ports.pushEvent("group_call_client_joined", payload);
      this.channel?.push("group_call_media_state", this.mediaEnabled);
      this._scheduleOfferWatchdog("join");
    },

    async _processOffer({ sdp, ice_servers, offer_id }) {
      if (!sdp) {
        this._notifyError(
          t("The call could not set up sound and video"),
          "media_negotiation_failed",
        );
        return;
      }

      if (
        (offer_id && this.lastAnsweredOfferId === offer_id) ||
        (!offer_id && this.lastAnsweredOfferSdp === sdp)
      ) {
        this._clearOfferWatchdog();
        return;
      }

      try {
        await this._ensurePeerConnection(ice_servers || []);
        await this.pc.setRemoteDescription({ type: "offer", sdp });
        await this._ensureLocalTracks();
        await this._flushPendingCandidates();

        const answer = await this.pc.createAnswer();
        await this.pc.setLocalDescription(answer);

        this.channel.push("group_call_answer", {
          sdp: this.pc.localDescription.sdp,
          offer_id: offer_id || null,
        });
        this.lastAnsweredOfferSdp = sdp;
        this.lastAnsweredOfferId = offer_id || null;
        this._clearOfferWatchdog();
      } catch (error) {
        log.warn("[group-call] failed to handle offer", error);

        // A description this connection cannot accept means the two sides no
        // longer agree on the session — the SFU rebuilt its peer, or a
        // description arrived out of turn. No later offer can land here either,
        // so replace the connection instead of leaving the call wedged behind an
        // error nobody can clear.
        if (this._isUnusableDescriptionError(error)) {
          this._rejoinConnection("offer_rejected");
          return;
        }

        this._notifyError(
          t("The call could not set up sound and video"),
          "media_negotiation_failed",
        );
      }
    },

    // The two failures that outlive the offer that caused them: a layout the
    // connection can no longer extend, and a description applied out of turn.
    _isUnusableDescriptionError(error) {
      return error?.name === "InvalidAccessError" || error?.name === "InvalidStateError";
    },

    async _ensurePeerConnection(iceServers) {
      if (this.pc) return;

      this.pc = createPeerConnection(iceServers, { turnOnly: false });
      this.remoteCandidateFailures = 0;

      this.pc.onconnectionstatechange = () => this._handleConnectionStateChange();
      this.pc.oniceconnectionstatechange = () => this._handleIceConnectionStateChange();

      this.pc.onicecandidate = (event) => {
        if (!event.candidate) return;
        this.channel?.push("group_call_ice_candidate", {
          candidate: event.candidate.toJSON(),
        });
      };

      this.pc.ontrack = (event) => {
        this._attachRemoteStream(event.streams[0], event.track);
      };

      this._startStatsPolling();
    },

    async _ensureLocalTracks() {
      if (this.localStream) {
        await this._publishLocalTracks();
        this._attachLocalStream(this.localStream);
        this._applyMediaEnabled();
        return;
      }

      if (!this.mediaEnabled.audio && !this.mediaEnabled.video) {
        this.localStream = emptyMediaStream();
        this._attachLocalStream(this.localStream);
        this._applyMediaEnabled();
        return;
      }

      try {
        this.localStream = await navigator.mediaDevices.getUserMedia(this._captureConstraints());
        applyTrackHints(this.localStream);
      } catch (error) {
        log.warn("[group-call] media capture failed, answering recvonly", error);
        this._notifyWarning(
          t(
            "Could not access your microphone or camera. You joined without sending sound or video.",
          ),
          "media_capture_failed",
        );
        this.localStream = emptyMediaStream();
        this._attachLocalStream(this.localStream);
        this.mediaEnabled = { audio: false, video: false };
        this._applyMediaEnabled();
        this._syncLocalTile();
        this._pushLocalMediaState();
        return;
      }

      await this._publishLocalTracks();
      this._attachLocalStream(this.localStream);
      this._applyMediaEnabled();
    },

    async _publishLocalTracks() {
      if (!this.pc || !this.localStream || this._sendersPc === this.pc) return;

      this.localSenders = [];

      for (const track of this.localStream.getTracks()) {
        const sender = this.pc.addTrack(track, this.localStream);
        this.localSenders.push(sender);

        if (track.kind === "video") {
          this.videoSender = sender;
          this.cameraVideoTrack = track;
        }
      }

      await applyMediaProfile(this.pc);
      this._sendersPc = this.pc;
    },

    async _handleRemoteCandidate(candidate) {
      if (!candidate) return;

      if (!this.pc || !this.pc.remoteDescription) {
        this.pendingCandidates.push(candidate);
        return;
      }

      try {
        await this.pc.addIceCandidate(candidate);
        this.remoteCandidateFailures = 0;
      } catch (error) {
        this._recordRemoteCandidateFailure(error);
      }
    },

    _recordRemoteCandidateFailure(error) {
      log.warn("[group-call] failed to add ICE candidate", error);
      this.remoteCandidateFailures = (this.remoteCandidateFailures || 0) + 1;

      if (this.remoteCandidateFailures >= ICE_CANDIDATE_FAILURE_LIMIT) {
        this._scheduleRecovery("ice_candidate_failed");
      }
    },

    async _flushPendingCandidates() {
      const candidates = this.pendingCandidates.splice(0);

      for (const candidate of candidates) {
        await this._handleRemoteCandidate(candidate);
      }
    },

    _attachLocalStream(stream) {
      const video = el.querySelector("[data-group-call-local-video]");
      if (video) {
        video.srcObject = stream;
        video.muted = true;
        video.playsInline = true;
      }

      this._syncLocalTile();
    },

    _attachRemoteStream(stream, track = null) {
      if (!stream) return;

      const streamId = stream.id || `remote-${Date.now()}`;
      const tile = this.tileView.ensure(streamId);

      let video = tile.querySelector("video");

      if (!video) {
        video = document.createElement("video");
        video.autoplay = true;
        video.playsInline = true;
        video.className = "group-call-video-tile__video group-call-remote-video";
        tile.insertBefore(video, tile.firstChild);
      }

      attachMediaStream(video, stream, {
        muted: false,
        onVideoStalled: ({ reason }) => {
          this._handleRemoteVideoStalled(streamId, reason);
        },
      });
      this._applyAudioOutput(video);
      this._applyTrackToTile(tile, streamId, track);
      this._applyLayout();
    },

    _mediaStateFromDataset() {
      return mediaStateFromDataset(el.dataset);
    },

    _devicePreferencesFromDataset() {
      return {
        audioInputId: stringOrNull(el.dataset.audioInputId),
        videoInputId: stringOrNull(el.dataset.videoInputId),
        audioOutputId: stringOrNull(el.dataset.audioOutputId),
      };
    },

    _captureConstraints() {
      return captureConstraints(this.mediaEnabled, this.devicePreferences);
    },

    _applyAudioOutput(element) {
      if (!this.devicePreferences.audioOutputId || !element) return;
      setSinkId(element, this.devicePreferences.audioOutputId).catch(() => false);
    },

    _stopStream(stream) {
      stream?.getTracks?.().forEach((track) => {
        if (track.readyState !== "ended") track.stop();
      });
    },

    _clientInfo() {
      return {
        user_agent: navigator.userAgent,
        platform: navigator.platform,
        language: navigator.language,
      };
    },

    _cleanup() {
      this.closing = true;
      if (this.toggleScreenShareHandler) {
        el.removeEventListener("group-call:toggle-screen-share", this.toggleScreenShareHandler);
      }
      if (this.participantQualityEventHandler) {
        el.removeEventListener(
          "group-call:participant-quality",
          this.participantQualityEventHandler,
        );
      }
      if (this.recoveryStateEventHandler) {
        el.removeEventListener("group-call:recovery-state", this.recoveryStateEventHandler);
      }
      if (this.screenShareClickHandler) {
        document.removeEventListener("click", this.screenShareClickHandler);
      }
      if (this.reactionClickHandler) {
        document.removeEventListener("click", this.reactionClickHandler);
      }
      if (this.pushToTalkKeydownHandler) {
        document.removeEventListener("keydown", this.pushToTalkKeydownHandler, true);
      }
      if (this.pushToTalkKeyupHandler) {
        document.removeEventListener("keyup", this.pushToTalkKeyupHandler, true);
      }
      this._stopStatsPolling();
      this._clearOfferWatchdog();
      if (this.recoveryTimer) {
        clearTimeout(this.recoveryTimer);
        this.recoveryTimer = null;
      }
      this.channel?.leave();
      this.socket?.disconnect();

      this._stopStream(this.screenShare?.stream);
      this.localStream?.getTracks()?.forEach((track) => track.stop());
      this.pc?.close();

      this.channel = null;
      this.socket = null;
      this.localStream = null;
      this.pc = null;
      this.pendingCandidates = [];
      this.remoteCandidateFailures = 0;
      this.participantId = null;
      this.offerQueue = Promise.resolve();
      this.lastAnsweredOfferSdp = null;
      this.lastAnsweredOfferId = null;
      this.videoSender = null;
      this.cameraVideoTrack = null;
      this.screenShare = { active: false, stream: null, track: null };
      this.screenShareBlocked = false;
      this.serverAudioMuted = false;
      this.serverVideoBlocked = false;
      this.pushToTalkActive = false;
      this.pushToTalkRestoreAudio = null;
      this.recoveryAttempts = 0;
      this.offerWatchdogAttempts = 0;
      this.participantStatsPrev = null;
      this.activeSpeakerParticipantId = null;
      for (const timer of this.reactionTimers?.values?.() || []) {
        clearTimeout(timer);
      }
      this.reactionTimers?.clear();
      this.participantQualityById?.clear();
      this.participantRegistry.clear();
      this.trackRegistry.clear();
      this.tileView.clear();
      this.remoteVideoStalls?.clear();
    },
  };
}
