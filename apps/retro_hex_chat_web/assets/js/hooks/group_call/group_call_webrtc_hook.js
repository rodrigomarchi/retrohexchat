/**
 * LiveView Hook: GroupCallWebRTCHook
 *
 * Minimal browser-side SFU client. It uses a raw Phoenix Channel so SDP/ICE do
 * not travel through the ChatLive process.
 */
import { Socket } from "phoenix";
import { t } from "../../lib/i18n.js";
import { log } from "../../lib/logger.js";
import { isEditableTarget } from "../../lib/ui/dom.js";
import { captureConstraints } from "../../lib/p2p/device_constraints.js";
import { createPeerConnection } from "../../lib/p2p/webrtc.js";
import {
  collectQualitySnapshot,
  deriveParticipantQuality,
  participantQualityLabel,
  participantQualityTitle,
} from "../../lib/group_call/quality.js";
import {
  hasOwn,
  idsFromValue,
  normalizeLayoutMode,
  normalizeSelfView,
  payloadValue,
  stringOrNull,
  tileDensity,
} from "../../lib/group_call/payload.js";
import {
  REACTION_TTL_MS,
  buildReactionBubble,
  ensureReactionStack,
  reactionEmoji,
  reactionIconNode,
} from "../../lib/group_call/reactions.js";
import {
  acquireDisplayMedia,
  attachMediaStream,
  collectConnectionActivity,
  collectFeatureSnapshotFromReports,
  deriveFeatureStats,
  hasConnectionActivity,
  applyMediaProfile,
  applySenderProfile,
  applyTrackHints,
  getScreenShareConstraints,
  setSinkId,
} from "../../lib/p2p/media.js";
const STATS_INTERVAL_MS = 2500;
const ICE_CANDIDATE_FAILURE_LIMIT = 3;
const OFFER_WATCHDOG_DELAY_MS = 1500;
const OFFER_WATCHDOG_MAX_ATTEMPTS = 3;
const RECOVERY_BACKOFF_MS = [1000, 2000, 4000];
const DISCONNECTED_ACTIVITY_DEFERRAL_LIMIT = 2;
const PUSH_TO_TALK_KEYS = new Set(["z", "Z"]);

function emptyMediaStream() {
  if (typeof MediaStream === "function") return new MediaStream();

  return {
    getTracks: () => [],
    getAudioTracks: () => [],
    getVideoTracks: () => [],
  };
}

const GroupCallWebRTCHook = {
  mounted() {
    this.roomToken = this.el.dataset.groupCallToken;
    this.joinToken = this.el.dataset.joinToken;
    this.localStream = null;
    this.pc = null;
    this.socket = null;
    this.channel = null;
    this.pendingCandidates = [];
    this.remoteCandidateFailures = 0;
    this.participantId = stringOrNull(this.el.dataset.participantId);
    this.mediaEnabled = this._mediaStateFromDataset();
    this.serverAudioMuted = false;
    this.serverVideoBlocked = false;
    this.devicePreferences = this._devicePreferencesFromDataset();
    this.closing = false;
    this.offerQueue = Promise.resolve();
    this.lastAnsweredOfferSdp = null;
    this.lastAnsweredOfferId = null;
    this.layoutState = this._layoutStateFromDataset();
    this.participantsById = new Map();
    this.tracksById = new Map();
    this.tracksByStreamId = new Map();
    this.tracksByWebrtcTrackId = new Map();
    this.remoteTiles = new Map();
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
      this.pushEvent("group_call_participant_quality", payload);
    };
    this.recoveryStateEventHandler = (event) => {
      const payload = event.detail || {};
      if (payload.token && payload.token !== this.roomToken) return;

      this.pushEvent("group_call_recovery_state", payload);
    };

    if (!this.roomToken || !this.joinToken) {
      log.warn("[group-call] missing room token or join token");
      return;
    }

    this.handleEvent("group_call_set_media_state", (payload) => {
      this._setMediaState(payload || {});
    });

    this.handleEvent("group_call_stop_screen_share", (payload) => {
      this._stopScreenShareByModerator(payload || {});
    });

    this.handleEvent("group_call_retry_media", () => {
      this._retryConnection("manual");
    });

    this.handleEvent("group_call_layout_state", (payload) => {
      this._syncLayoutState(payload || {});
    });

    this._bindLocalTile();
    this.el.addEventListener("group-call:toggle-screen-share", this.toggleScreenShareHandler);
    this.el.addEventListener("group-call:participant-quality", this.participantQualityEventHandler);
    this.el.addEventListener("group-call:recovery-state", this.recoveryStateEventHandler);
    document.addEventListener("click", this.screenShareClickHandler);
    document.addEventListener("click", this.reactionClickHandler);
    document.addEventListener("keydown", this.pushToTalkKeydownHandler, true);
    document.addEventListener("keyup", this.pushToTalkKeyupHandler, true);
    this._applyLayout();
    this._connect();
    this.pushEvent("group_call_webrtc_ready", {});
  },

  destroyed() {
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
      this.pushEvent("group_call_offer_received", {
        participant_id: payload?.participant_id,
      });
      this._handleOffer(payload);
    });
    this.channel.on("group_call_ice_candidate", (payload) => {
      this._handleRemoteCandidate(payload.candidate);
    });
    this.channel.on("group_call_peer_joined", (payload) => {
      this._upsertParticipant(payload?.participant);
      this.pushEvent("group_call_peer_joined", payload);
    });
    this.channel.on("group_call_peer_left", (payload) => {
      this._removeParticipant(payload?.participant_id);
      this.pushEvent("group_call_peer_left", payload);
    });
    this.channel.on("group_call_track_added", (payload) => {
      this._syncTrack(payload?.track);
      this.pushEvent("group_call_track_added", payload);
    });
    this.channel.on("group_call_media_state", (payload) => {
      this._upsertParticipant(payload?.participant);
      this.pushEvent("group_call_media_state", payload);
    });
    this.channel.on("group_call_screen_share_state", (payload) => {
      this._upsertParticipant(payload?.participant);
      this._syncTrack(payload?.track);
      this._applyScreenShareStateToTiles(payload || {});
      this.pushEvent("group_call_screen_share_state", payload);
    });
    this.channel.on("group_call_reaction", (payload) => {
      this._applyReaction(payload || {});
      this.pushEvent("group_call_reaction", payload || {});
    });
    this.channel.on("group_call_reaction_error", (payload) => {
      this._notifyWarning(
        payload?.message || t("Could not send conference reaction."),
        "reaction_failed",
      );
    });
    this.channel.on("group_call_set_media_state", (payload) => {
      this._setMediaState(payload || {});
      this.pushEvent("group_call_media_state_forced", payload || {});
    });
    this.channel.on("group_call_stop_screen_share", (payload) => {
      this._stopScreenShareByModerator(payload || {});
    });
    this.channel.on("group_call_track_updated", (payload) => {
      this._syncTrack(payload?.track);
      this.pushEvent("group_call_track_updated", payload);
    });
    this.channel.on("group_call_track_removed", (payload) => {
      this._removeTrack(payload?.track_id);
      this.pushEvent("group_call_track_removed", payload);
    });
    this.channel.on("group_call_closed", (payload) => {
      this.pushEvent("group_call_closed", payload);
      this._cleanup();
    });
    this.channel.on("group_call_error", (payload) => {
      log.warn("[group-call] signaling error", payload);
      this.pushEvent("group_call_client_error", payload);
    });
    this.channel.onError(() => {
      if (!this.closing) {
        this._notifyError(t("Group call signaling connection failed"), "signaling_failed");
      }
    });
    this.channel.onClose(() => {
      if (!this.closing && this.participantId) {
        this._notifyWarning(t("Group call signaling channel closed"), "signaling_closed");
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
          reply?.reason || t("Group call channel rejected the join"),
          "channel_join_rejected",
        );
      })
      .receive("timeout", () => {
        log.warn("[group-call] channel join timed out");
        this._notifyError(t("Group call channel join timed out"), "channel_join_timeout");
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
      this._notifyError(t("Unable to join group call"), "join_failed");
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
            message: reply?.message || t("Unable to join group call"),
          });
        }
        this._notifyError(reply?.message || t("Unable to join group call"), "join_failed");
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
            message: t("Group call join timed out"),
          });
        }
        this._notifyError(t("Group call join timed out"), "join_timeout");
      });

    return push;
  },

  _handleOffer(payload) {
    this.offerQueue = this.offerQueue.catch(() => {}).then(() => this._processOffer(payload || {}));

    return this.offerQueue;
  },

  _handleJoined(payload = {}) {
    this.participantId = payload?.participant?.id || null;
    this.rejoining = false;
    this._upsertParticipant(payload?.participant);
    this._syncParticipants(payload?.participants || []);
    this._syncTracks(payload?.tracks || []);
    this._syncLocalTile();
    this.pushEvent("group_call_client_joined", payload);
    this.channel?.push("group_call_media_state", this.mediaEnabled);
    this._scheduleOfferWatchdog("join");
  },

  async _processOffer({ sdp, ice_servers, offer_id }) {
    if (!sdp) {
      this._notifyError(t("Group call media negotiation failed"), "media_negotiation_failed");
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

      this._notifyError(t("Group call media negotiation failed"), "media_negotiation_failed");
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
        t("Could not access your microphone or camera. You joined receive-only."),
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
    const video = this.el.querySelector("[data-group-call-local-video]");
    if (video) {
      video.srcObject = stream;
      video.muted = true;
      video.playsInline = true;
    }

    this._syncLocalTile();
  },

  _attachRemoteStream(stream, track = null) {
    if (!stream) return;

    const host = this._videoGrid();
    const streamId = stream.id || `remote-${Date.now()}`;
    let tile =
      this.remoteTiles.get(streamId) || host.querySelector(`[data-stream-id="${streamId}"]`);

    if (!tile) {
      tile = this._createRemoteTile(streamId);
      host.appendChild(tile);
      this.remoteTiles.set(streamId, tile);
    }

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

  _videoGrid() {
    return this.el.querySelector("[data-group-call-video-grid]") || this.el;
  },

  _createRemoteTile(streamId) {
    const tile = this._remoteTileFromTemplate() || document.createElement("div");
    tile.classList.add("group-call-video-tile", "group-call-video-tile--remote");
    tile.dataset.groupCallVideoTile = "";
    tile.dataset.streamId = streamId;
    tile.dataset.mediaAudio = "true";
    tile.dataset.mediaVideo = "true";
    tile.dataset.local = "false";
    tile.dataset.activeSpeaker = "false";
    tile.dataset.qualityLevel = "unknown";
    tile.dataset.pinned = "false";
    tile.tabIndex = 0;
    tile.role = "button";
    tile.dataset.testid = `group-call-remote-tile-${streamId}`;
    tile.addEventListener("click", () => this._toggleTileFocus(tile));
    tile.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      this._toggleTileFocus(tile);
    });

    this._ensureRemoteTileNameplate(tile);

    return tile;
  },

  _remoteTileFromTemplate() {
    const template = this.el.querySelector("[data-group-call-remote-tile-template]");
    const node = template?.content?.firstElementChild?.cloneNode(true);

    return node instanceof HTMLElement ? node : null;
  },

  _ensureRemoteTileNameplate(tile) {
    if (tile.querySelector("[data-group-call-tile-name]")) return;

    const nameplate = document.createElement("div");
    nameplate.className = "group-call-video-tile__nameplate";

    const name = document.createElement("span");
    name.className = "truncate font-bold";
    name.dataset.groupCallTileName = "";
    name.textContent = t("Remote");

    nameplate.append(name);
    tile.appendChild(nameplate);
  },

  _bindLocalTile() {
    const tile = this.el.querySelector("[data-group-call-local-tile]");
    if (!tile) return;

    tile.addEventListener("click", () => this._toggleTileFocus(tile));
    tile.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      this._toggleTileFocus(tile);
    });
    this._syncLocalTile();
  },

  _syncLocalTile() {
    const tile = this.el.querySelector("[data-group-call-local-tile]");
    if (!tile) return;

    if (this.participantId) {
      tile.dataset.participantId = String(this.participantId);
    }

    tile.dataset.mediaAudio = String(this.mediaEnabled.audio);
    tile.dataset.mediaVideo = String(this.mediaEnabled.video);
    tile.dataset.mediaScreen = String(this.screenShare?.active === true);
    tile.dataset.trackSource = this.screenShare?.active === true ? "screen" : "camera";
    tile.dataset.localEmptyState = this._localEmptyState();

    const name = tile.querySelector("[data-group-call-local-name]");
    if (name) {
      tile.dataset.localName ||= name.textContent || t("You");
      name.textContent =
        this.screenShare?.active === true ? t("Your screen") : tile.dataset.localName;
    }

    this._syncLocalEmptyState(tile);

    const label =
      this.screenShare?.active === true ? t("Focus your shared screen") : t("Focus your video");
    tile.setAttribute("aria-label", label);
    tile.title = label;
    this._applyLayout();
  },

  _localEmptyState() {
    if (this.screenShare?.active === true) return "screen-share";
    if (this.mediaEnabled.audio === false && this.mediaEnabled.video === false) {
      return "receive-only";
    }
    if (this.mediaEnabled.video === false) return "camera-off";
    return "starting";
  },

  _syncLocalEmptyState(tile) {
    const title = tile.querySelector("[data-group-call-local-empty-title]");
    const detail = tile.querySelector("[data-group-call-local-empty-detail]");
    const copy = this._localEmptyStateCopy(tile.dataset.localEmptyState);

    if (title) title.textContent = copy.title;
    if (detail) detail.textContent = copy.detail;
  },

  _localEmptyStateCopy(state) {
    switch (state) {
      case "screen-share":
        return {
          title: t("Sharing screen"),
          detail: t("Your screen is replacing the camera feed."),
        };
      case "receive-only":
        return {
          title: t("Receive-only mode"),
          detail: t("Your microphone and camera are off."),
        };
      case "camera-off":
        return {
          title: t("Camera off"),
          detail: t("Your camera is not being sent."),
        };
      default:
        return {
          title: t("Camera preview starting"),
          detail: t("Your local preview appears here when the camera is ready."),
        };
    }
  },

  _toggleTileFocus(tile) {
    const participantId = tile.dataset.participantId || null;
    const streamId = tile.dataset.streamId || null;
    const isFocused = tile.dataset.focused === "true";

    if (isFocused) {
      this.pushEvent("group_call_clear_focus", {});
      this._syncLayoutState({
        mode: "auto",
        focused_participant_id: null,
        focused_stream_id: null,
      });
      return;
    }

    if (participantId) {
      this.pushEvent("group_call_focus_participant", {
        participant_id: participantId,
        "participant-id": participantId,
      });
      return;
    }

    this._syncLayoutState({
      mode: "focus",
      focused_participant_id: null,
      focused_stream_id: streamId,
    });
  },

  _layoutStateFromDataset() {
    return {
      mode: normalizeLayoutMode(this.el.dataset.layoutMode),
      focusedParticipantId: stringOrNull(this.el.dataset.focusedParticipantId),
      focusedStreamId: null,
      selfView: normalizeSelfView(this.el.dataset.selfView),
      pinnedParticipantIds: idsFromValue(this.el.dataset.pinnedParticipantIds),
    };
  },

  _syncLayoutState(payload) {
    const mode = payloadValue(payload, "mode");
    const focusedParticipantId = payloadValue(
      payload,
      "focused_participant_id",
      "focusedParticipantId",
    );
    const focusedStreamId = payloadValue(payload, "focused_stream_id", "focusedStreamId");
    const selfView = payloadValue(payload, "self_view", "selfView");
    const selfParticipantId = payloadValue(payload, "self_participant_id", "selfParticipantId");
    const pinnedParticipantIds = payloadValue(
      payload,
      "pinned_participant_ids",
      "pinnedParticipantIds",
    );

    this.layoutState = {
      ...this.layoutState,
      mode: mode === undefined ? this.layoutState.mode : normalizeLayoutMode(mode),
      focusedParticipantId:
        focusedParticipantId === undefined
          ? this.layoutState.focusedParticipantId
          : stringOrNull(focusedParticipantId),
      focusedStreamId:
        focusedStreamId === undefined
          ? this.layoutState.focusedStreamId
          : stringOrNull(focusedStreamId),
      selfView: selfView === undefined ? this.layoutState.selfView : normalizeSelfView(selfView),
      pinnedParticipantIds:
        pinnedParticipantIds === undefined
          ? this.layoutState.pinnedParticipantIds
          : idsFromValue(pinnedParticipantIds),
    };

    if (selfParticipantId !== undefined && selfParticipantId !== null) {
      this.participantId = selfParticipantId;
      this._syncLocalTile();
    }

    this._syncParticipants(payload.participants || []);
    this._syncTracks(payload.tracks || []);
    this._applyLayout();
  },

  _syncParticipants(participants) {
    for (const participant of participants || []) {
      this._upsertParticipant(participant);
    }
  },

  _upsertParticipant(participant) {
    if (!participant?.id) return;

    const id = String(participant.id);
    this.participantsById.set(id, {
      id,
      nickname: participant.nickname || t("Remote"),
      status: participant.status || "connected",
      media_state: participant.media_state || participant.mediaState || {},
    });

    for (const tile of this._tilesForParticipant(id)) {
      this._applyParticipantToTile(tile, id);
    }

    if (String(this.participantId || "") === id) {
      this._syncLocalTile();
    }
  },

  _removeParticipant(participantId) {
    if (!participantId) return;

    const id = String(participantId);
    this.participantsById.delete(id);
    this.participantQualityById?.delete(id);
    if (this.activeSpeakerParticipantId === id) this.activeSpeakerParticipantId = null;

    for (const [streamId, tile] of this.remoteTiles) {
      if (tile.dataset.participantId !== id) continue;
      tile.remove();
      this.remoteTiles.delete(streamId);
      this.remoteVideoStalls?.delete(streamId);
    }

    if (this.layoutState.focusedParticipantId === id) {
      this.layoutState.focusedParticipantId = null;
      this.layoutState.mode = "auto";
    }

    this.layoutState.pinnedParticipantIds = (this.layoutState.pinnedParticipantIds || []).filter(
      (participantId) => participantId !== id,
    );

    this._applyLayout();
  },

  _syncTracks(tracks) {
    for (const track of tracks || []) {
      this._syncTrack(track);
    }
  },

  _syncTrack(track) {
    if (!track?.id) return;

    const normalized = {
      id: String(track.id),
      participantId: stringOrNull(track.participant_id ?? track.participantId),
      kind: track.kind,
      source: track.source || "camera",
      status: track.status,
      streamId: stringOrNull(track.stream_id ?? track.streamId),
      webrtcTrackId: stringOrNull(track.webrtc_track_id ?? track.webrtcTrackId),
    };

    this.tracksById.set(normalized.id, normalized);

    if (normalized.streamId) {
      this.tracksByStreamId.set(normalized.streamId, normalized);
      const tile = this.remoteTiles.get(normalized.streamId);
      if (tile) this._applyTrackToTile(tile, normalized.streamId);
    }

    if (normalized.webrtcTrackId) {
      this.tracksByWebrtcTrackId.set(normalized.webrtcTrackId, normalized);
    }
  },

  _removeTrack(trackId) {
    if (!trackId) return;

    const track = this.tracksById.get(String(trackId));
    this.tracksById.delete(String(trackId));
    if (!track) return;

    if (track.streamId) this.tracksByStreamId.delete(track.streamId);
    if (track.webrtcTrackId) this.tracksByWebrtcTrackId.delete(track.webrtcTrackId);
  },

  _applyTrackToTile(tile, streamId, browserTrack = null) {
    const track =
      this.tracksByStreamId.get(streamId) ||
      this.tracksByWebrtcTrackId.get(browserTrack?.id) ||
      null;

    if (track?.participantId) {
      tile.dataset.participantId = track.participantId;
      this._applyParticipantToTile(tile, track.participantId);
    }

    const source = track?.source || "camera";
    tile.dataset.trackSource = source;
    tile.dataset.mediaScreen = String(source === "screen");

    if (track?.participantId) {
      this._applyParticipantToTile(tile, track.participantId);
    }
  },

  _applyParticipantToTile(tile, participantId) {
    const participant = this.participantsById.get(String(participantId));
    if (!participant) return;

    const name = tile.querySelector("[data-group-call-tile-name]");
    const media = participant.media_state || {};
    const audio = media.audio !== false;
    const video = media.video !== false;
    const screen = media.screen === true || tile.dataset.trackSource === "screen";
    const nickname = participant.nickname || t("Remote");

    if (name) {
      name.textContent = screen ? t("%{nickname}'s screen", { nickname }) : nickname;
    }
    tile.dataset.mediaAudio = String(audio);
    tile.dataset.mediaVideo = String(video);
    tile.dataset.mediaScreen = String(screen);
    this._applyParticipantQualityToTile(tile, participantId);

    const label = screen ? `Focus ${nickname}'s shared screen` : `Focus ${nickname}`;
    tile.setAttribute("aria-label", label);
    tile.title = label;
  },

  _applyScreenShareStateToTiles(payload) {
    const participantId = stringOrNull(payload.participant_id ?? payload.participantId);
    if (!participantId) return;

    const active = payload.active === true;
    const source = active ? "screen" : "camera";
    const participant = this.participantsById.get(participantId);

    if (participant) {
      participant.media_state = {
        ...(participant.media_state || {}),
        screen: active,
      };
    }

    let tiles = this._tilesForParticipant(participantId).filter(
      (tile) => tile.dataset.local !== "true",
    );

    if (tiles.length === 0) {
      const unassignedRemoteTiles = this._remoteTileElements().filter(
        (tile) => !tile.dataset.participantId,
      );

      if (unassignedRemoteTiles.length === 1) {
        tiles = unassignedRemoteTiles;
      }
    }

    for (const tile of tiles) {
      tile.dataset.participantId = participantId;
      tile.dataset.trackSource = source;
      tile.dataset.mediaScreen = String(active);
      this._applyParticipantToTile(tile, participantId);
    }

    this._applyLayout();
  },

  _tilesForParticipant(participantId) {
    return Array.from(this.el.querySelectorAll("[data-group-call-video-tile]")).filter(
      (tile) => tile.dataset.participantId === String(participantId),
    );
  },

  _remoteTileElements() {
    const mappedTiles = Array.from(this.remoteTiles.values());
    const domTiles = Array.from(
      this.el.querySelectorAll('[data-group-call-video-tile][data-local="false"]'),
    );

    return Array.from(new Set([...mappedTiles, ...domTiles]));
  },

  _applyLayout() {
    if (!this.layoutState) return;

    const host = this._videoGrid();
    const tiles = Array.from(this.el.querySelectorAll("[data-group-call-video-tile]"));
    const visibleTiles = tiles.filter((tile) => this._tileVisible(tile));
    const focusedTile = this._focusedTile(visibleTiles);
    const remoteCount = this._remoteTileElements().filter((tile) => this._tileVisible(tile)).length;

    this.el.dataset.layoutMode = this.layoutState.mode;
    this.el.dataset.selfView = this.layoutState.selfView;
    this.el.dataset.pinnedParticipantIds = (this.layoutState.pinnedParticipantIds || []).join(",");
    if (this.layoutState.focusedParticipantId) {
      this.el.dataset.focusedParticipantId = this.layoutState.focusedParticipantId;
    } else {
      delete this.el.dataset.focusedParticipantId;
    }

    host.dataset.tileCount = String(visibleTiles.length);
    host.dataset.tileDensity = tileDensity(visibleTiles.length);

    for (const tile of tiles) {
      const focused = focusedTile === tile;
      const participantId = stringOrNull(tile.dataset.participantId);
      const pinned =
        !!participantId && (this.layoutState.pinnedParticipantIds || []).includes(participantId);
      tile.dataset.focused = String(focused);
      tile.dataset.pinned = String(pinned);
      tile.classList.toggle("group-call-video-tile--focused", focused);
      tile.classList.toggle("group-call-video-tile--pinned", pinned);
    }

    const placeholder = this.el.querySelector("[data-group-call-remote-placeholder]");
    placeholder?.classList.toggle("hidden", remoteCount > 0);
  },

  _focusedTile(tiles) {
    if (!["focus", "sidebar", "speaker"].includes(this.layoutState.mode)) return null;

    if (this.layoutState.mode === "speaker" && this.activeSpeakerParticipantId) {
      const activeSpeaker = tiles.find(
        (tile) => tile.dataset.participantId === this.activeSpeakerParticipantId,
      );
      if (activeSpeaker) return activeSpeaker;
    }

    if (this.layoutState.focusedParticipantId) {
      const byParticipant = tiles.find(
        (tile) => tile.dataset.participantId === this.layoutState.focusedParticipantId,
      );
      if (byParticipant) return byParticipant;
    }

    if (this.layoutState.focusedStreamId) {
      const byStream = tiles.find(
        (tile) => tile.dataset.streamId === this.layoutState.focusedStreamId,
      );
      if (byStream) return byStream;
    }

    return tiles.find((tile) => tile.dataset.local !== "true") || tiles[0] || null;
  },

  _tileVisible(tile) {
    if (tile.dataset.local !== "true") return true;
    return this.layoutState.selfView !== "hidden";
  },

  _mediaStateFromDataset() {
    const audio = this.el.dataset.audio !== "false";
    const video = this.el.dataset.video !== "false";
    return { audio, video };
  },

  _devicePreferencesFromDataset() {
    return {
      audioInputId: stringOrNull(this.el.dataset.audioInputId),
      videoInputId: stringOrNull(this.el.dataset.videoInputId),
      audioOutputId: stringOrNull(this.el.dataset.audioOutputId),
    };
  },

  _captureConstraints() {
    return captureConstraints(this.mediaEnabled, this.devicePreferences);
  },

  _applyAudioOutput(element) {
    if (!this.devicePreferences.audioOutputId || !element) return;
    setSinkId(element, this.devicePreferences.audioOutputId).catch(() => false);
  },

  _sendReaction(reaction) {
    if (!reaction || !this.channel) {
      this._notifyWarning(t("Join the conference before sending reactions."), "reaction_not_ready");
      return;
    }

    this.channel
      .push("group_call_reaction", { reaction })
      ?.receive?.("error", (reply) => {
        this._notifyWarning(
          reply?.message || t("Could not send conference reaction."),
          "reaction_failed",
        );
      })
      ?.receive?.("timeout", () => {
        this._notifyWarning(t("Conference reaction timed out."), "reaction_timeout");
      });
  },

  _applyReaction(payload = {}) {
    const participantId = stringOrNull(payload.participant_id ?? payload.participantId);
    if (!participantId) return;

    const reactionId = stringOrNull(payload.id) || `reaction-${Date.now()}`;
    const reaction = payload.reaction || "heart";
    const tiles = this._reactionTiles(participantId);

    for (const tile of tiles) {
      const stack = ensureReactionStack(tile);
      const bubble = buildReactionBubble({
        reaction,
        reactionId,
        iconNode: reactionIconNode(this.el, reaction),
        emoji: reactionEmoji(reaction),
      });
      stack.appendChild(bubble);

      const key = `${reactionId}:${tile.dataset.streamId || "local"}`;
      const timer = setTimeout(() => {
        bubble.remove();
        this.reactionTimers.delete(key);
      }, REACTION_TTL_MS);

      this.reactionTimers.set(key, timer);
    }
  },

  _reactionTiles(participantId) {
    let tiles = this._tilesForParticipant(participantId);

    if (tiles.length === 0) {
      const unassignedRemoteTiles = this._remoteTileElements().filter(
        (tile) => !tile.dataset.participantId,
      );

      if (unassignedRemoteTiles.length === 1) {
        unassignedRemoteTiles[0].dataset.participantId = participantId;
        this._applyParticipantToTile(unassignedRemoteTiles[0], participantId);
        tiles = unassignedRemoteTiles;
      }
    }

    return tiles;
  },

  async _toggleScreenShare() {
    if (this.screenShare?.active) {
      await this._stopScreenShare("local_stop");
    } else {
      await this._startScreenShare();
    }
  },

  async _startScreenShare() {
    if (this.screenShare?.active) return;

    if (this.screenShareBlocked) {
      this._notifyWarning(
        t("Screen sharing was disabled by a moderator."),
        "screen_share_moderated",
      );
      return;
    }

    if (!navigator.mediaDevices?.getDisplayMedia) {
      this._notifyWarning(
        t("Screen sharing is not supported by this browser."),
        "screen_unsupported",
      );
      return;
    }

    const sender = this._videoSender();
    if (!sender?.replaceTrack) {
      this._notifyWarning(
        t("Screen sharing will be available after media connects."),
        "screen_sender_missing",
      );
      return;
    }

    let stream;

    try {
      stream = await acquireDisplayMedia(getScreenShareConstraints());
    } catch (error) {
      log.warn("[group-call] screen capture failed", error);
      this._notifyWarning(t("Screen sharing was cancelled or denied."), "screen_capture_failed");
      return;
    }

    const track = stream.getVideoTracks()[0];

    if (!track) {
      this._stopStream(stream);
      this._notifyWarning(
        t("Screen sharing did not provide a video track."),
        "screen_track_missing",
      );
      return;
    }

    try {
      await sender.replaceTrack(track);
      await applySenderProfile(sender, "screen");
    } catch (error) {
      log.warn("[group-call] screen replaceTrack failed", error);
      this._stopStream(stream);
      this._notifyWarning(t("Could not publish the shared screen."), "screen_publish_failed");
      return;
    }

    this.videoSender = sender;
    this.screenShare = { active: true, stream, track };

    track.onended = () => {
      this._stopScreenShare("browser_ended");
    };

    this._attachLocalPreviewStream(stream);
    this._syncLocalTile();
    this._publishScreenShareState(true, track, stream);
  },

  async _stopScreenShare(reason = "local_stop") {
    if (!this.screenShare?.active) return;

    const { stream, track } = this.screenShare;
    this.screenShare = { active: false, stream: null, track: null };

    const sender = this._videoSender();

    try {
      if (sender?.replaceTrack) {
        await sender.replaceTrack(this.cameraVideoTrack || null);
        await applySenderProfile(sender);
      }
    } catch (error) {
      log.warn("[group-call] unable to restore camera track after screen share", error);
    }

    if (track) track.onended = null;
    this._stopStream(stream);
    this._attachLocalPreviewStream(this.localStream);
    this._syncLocalTile();
    this._publishScreenShareState(false, track, stream, reason);
  },

  _videoSender() {
    if (this.videoSender) return this.videoSender;
    const senders = typeof this.pc?.getSenders === "function" ? this.pc.getSenders() : [];
    this.videoSender =
      senders.find((sender) => sender.track?.kind === "video") ||
      senders.find((sender) => sender.track === null && sender.replaceTrack);

    return this.videoSender;
  },

  _attachLocalPreviewStream(stream) {
    const video = this.el.querySelector("[data-group-call-local-video]");
    if (!video) return;

    video.srcObject = stream || null;
    video.muted = true;
    video.playsInline = true;
  },

  _publishScreenShareState(active, track = null, stream = null, reason = null) {
    const payload = {
      active,
      participant_id: this.participantId,
      track_id: track?.id || null,
      stream_id: stream?.id || null,
      reason,
    };

    const push = this.channel?.push("group_call_screen_share_state", payload);

    if (active && push?.receive) {
      push.receive("error", (reply) => {
        this._notifyWarning(
          reply?.message || t("Screen sharing was disabled by a moderator."),
          "screen_share_rejected",
        );
        this._stopScreenShare("server_rejected");
      });
    }

    this.pushEvent("group_call_screen_share_state", payload);
  },

  async _stopScreenShareByModerator(payload = {}) {
    this.screenShareBlocked = payload.server_screen_blocked !== false;
    this._notifyWarning(t("Screen sharing was stopped by a moderator."), "screen_share_moderated");
    await this._stopScreenShare(payload.reason || "moderation");
  },

  _stopStream(stream) {
    stream?.getTracks?.().forEach((track) => {
      if (track.readyState !== "ended") track.stop();
    });
  },

  _setMediaState(payload) {
    if (hasOwn(payload, "server_audio_muted")) {
      this.serverAudioMuted = payload.server_audio_muted === true;
    }

    if (hasOwn(payload, "server_video_blocked")) {
      this.serverVideoBlocked = payload.server_video_blocked === true;
    }

    if (hasOwn(payload, "server_screen_blocked")) {
      this.screenShareBlocked = payload.server_screen_blocked === true;
    }

    if (this.screenShareBlocked && this.screenShare?.active) {
      this._stopScreenShare("moderation");
    }

    this._publishLocalMediaState({
      audio: payload.audio !== false,
      video: payload.video !== false,
    });
  },

  _publishLocalMediaState(media, { mirrorToLiveView = false } = {}) {
    const desired = {
      audio: media.audio !== false && !this.serverAudioMuted,
      video: media.video !== false && !this.serverVideoBlocked,
    };

    this.mediaEnabled = desired;
    this._applyMediaEnabled();
    this._syncLocalTile();

    if (this._needsOnDemandMedia(desired)) {
      this._ensureRequestedLocalTracks(desired)
        .catch((error) => {
          log.warn("[group-call] on-demand media capture failed", error);
          this._notifyWarning(
            t("Could not access your microphone or camera."),
            "media_capture_failed",
          );
        })
        .finally(() => {
          this.mediaEnabled = this._actualMediaState(desired);
          this._applyMediaEnabled();
          this._syncLocalTile();
          this._pushLocalMediaState(mirrorToLiveView);
        });
      return;
    }

    this._pushLocalMediaState(mirrorToLiveView);
  },

  _pushLocalMediaState(mirrorToLiveView = false) {
    if (this.participantId) {
      this.channel?.push("group_call_media_state", this.mediaEnabled);
    }

    if (mirrorToLiveView) {
      this.pushEvent("group_call_media_state_forced", this.mediaEnabled);
    }
  },

  _needsOnDemandMedia(desired) {
    if (!this.pc) return false;
    return (
      (desired.audio && !this._hasLocalAudioTrack()) ||
      (desired.video && !this._hasLocalVideoTrack())
    );
  },

  async _ensureRequestedLocalTracks(desired) {
    if (!this.pc) return;

    const needsAudio = desired.audio && !this._hasLocalAudioTrack();
    const needsVideo = desired.video && !this._hasLocalVideoTrack();
    if (!needsAudio && !needsVideo) return;

    const stream = await navigator.mediaDevices.getUserMedia(
      captureConstraints({ audio: needsAudio, video: needsVideo }, this.devicePreferences),
    );

    applyTrackHints(stream);
    this._mergeLocalStream(stream);

    for (const track of stream.getTracks()) {
      const sender = this.pc.addTrack(track, this.localStream || stream);
      this.localSenders.push(sender);

      if (track.kind === "video") {
        this.videoSender = sender;
        this.cameraVideoTrack = track;
      }
    }

    await applyMediaProfile(this.pc);
    this._sendersPc = this.pc;
    this._attachLocalStream(this.localStream || stream);
    this._requestOfferAfterLocalMediaChange();
  },

  _mergeLocalStream(stream) {
    if (!this.localStream || !this.localStream.getTracks) {
      this.localStream = stream;
      return;
    }

    if (typeof this.localStream.addTrack !== "function") {
      if ((this.localStream.getTracks?.() || []).length === 0) this.localStream = stream;
      return;
    }

    for (const track of stream.getTracks()) {
      this.localStream.addTrack(track);
    }
  },

  _actualMediaState(desired) {
    return {
      audio: desired.audio && this._hasLocalAudioTrack(),
      video: desired.video && this._hasLocalVideoTrack(),
    };
  },

  _requestOfferAfterLocalMediaChange() {
    const push = this.channel?.push("group_call_request_offer", {
      attempt: this.recoveryAttempts,
      trigger: "local_media_added",
    });

    push?.receive?.("error", (reply) => {
      if (reply?.code === "rejoin_required") this._rejoinConnection("local_media_added", reply);
    });
  },

  _applyMediaEnabled() {
    if (!this.localStream) return;

    for (const track of this.localStream.getAudioTracks()) {
      track.enabled = this.mediaEnabled.audio;
    }

    for (const track of this.localStream.getVideoTracks()) {
      track.enabled = this.mediaEnabled.video;
    }
  },

  _handlePushToTalkKeydown(event) {
    if (!this._isPushToTalkEvent(event)) return;
    if (event.defaultPrevented || event.repeat || this.pushToTalkActive) return;
    if (isEditableTarget(event.target)) return;
    if (this.mediaEnabled.audio === true || this.serverAudioMuted) return;

    if (!this._hasLocalAudioTrack()) {
      this._notifyWarning(t("Microphone is not available for push-to-talk."), "ptt_audio_missing");
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    this.pushToTalkActive = true;
    this.pushToTalkRestoreAudio = this.mediaEnabled.audio;
    this._publishLocalMediaState({ ...this.mediaEnabled, audio: true }, { mirrorToLiveView: true });
  },

  _handlePushToTalkKeyup(event) {
    if (!this.pushToTalkActive || !this._isPushToTalkEvent(event)) return;

    event.preventDefault();
    event.stopPropagation();

    const restoreAudio = this.pushToTalkRestoreAudio === true;
    this.pushToTalkActive = false;
    this.pushToTalkRestoreAudio = null;

    this._publishLocalMediaState(
      { ...this.mediaEnabled, audio: restoreAudio },
      { mirrorToLiveView: true },
    );
  },

  _isPushToTalkEvent(event) {
    return (
      event.ctrlKey === true &&
      event.shiftKey === true &&
      event.altKey !== true &&
      event.metaKey !== true &&
      PUSH_TO_TALK_KEYS.has(event.key)
    );
  },

  _hasLocalAudioTrack() {
    return (this.localStream?.getAudioTracks?.() || []).some(
      (track) => track.readyState !== "ended",
    );
  },

  _hasLocalVideoTrack() {
    return (this.localStream?.getVideoTracks?.() || []).some(
      (track) => track.readyState !== "ended",
    );
  },

  _handleConnectionStateChange() {
    const state = this.pc?.connectionState || "";

    this.pushEvent("group_call_connection_state", { state });

    if (state === "connected") {
      this._clearOfferWatchdog();
      this._clearRecovery("connected");
      return;
    }

    if (state === "connecting") {
      this._publishRecoveryState({
        state: "connecting",
        message: t("Group call media is connecting."),
      });
      return;
    }

    if (state === "disconnected" || state === "failed") {
      this._scheduleRecovery(state);
    }
  },

  _handleIceConnectionStateChange() {
    const state = this.pc?.iceConnectionState || "";

    if (state === "connected" || state === "completed") {
      this._clearRecovery("ice_connected");
      return;
    }

    if (state === "checking") {
      this._publishRecoveryState({
        state: "connecting",
        message: t("Group call media is connecting."),
      });
      return;
    }

    if (state === "disconnected" || state === "failed") {
      this._scheduleRecovery(`ice_${state}`);
    }
  },

  _scheduleRecovery(reason, { countAttempt = true } = {}) {
    if (this.recoveryTimer) return;

    if (countAttempt && this.recoveryAttempts >= this.maxRecoveryAttempts) {
      this._publishRecoveryState({
        state: "failed",
        reason,
        manual_retry: true,
        attempt: this.recoveryAttempts,
        max_attempts: this.maxRecoveryAttempts,
        message: t("Media recovery failed. Retry the media connection."),
      });
      return;
    }

    const attempt = countAttempt ? this.recoveryAttempts + 1 : this.recoveryAttempts || 1;
    const delay = RECOVERY_BACKOFF_MS[Math.min(attempt - 1, RECOVERY_BACKOFF_MS.length - 1)];
    if (countAttempt) this.recoveryAttempts = attempt;
    const beforeActivity = this._disconnectedRecoveryReason(reason)
      ? collectConnectionActivity(this.pc)
      : null;

    this._publishRecoveryState({
      state: "reconnecting",
      reason,
      attempt,
      max_attempts: this.maxRecoveryAttempts,
      next_retry_ms: delay,
      message: t("Group call media connection interrupted. Trying to recover."),
    });

    this.recoveryTimer = setTimeout(async () => {
      this.recoveryTimer = null;

      if (await this._deferDisconnectedRecoveryForActivity(reason, beforeActivity)) {
        return;
      }

      this._retryConnection("auto");
    }, delay);
  },

  _disconnectedRecoveryReason(reason) {
    return reason === "disconnected" || reason === "ice_disconnected";
  },

  async _deferDisconnectedRecoveryForActivity(reason, beforeActivity) {
    if (!beforeActivity || !this._disconnectedRecoveryReason(reason)) return false;

    const before = await beforeActivity;
    const after = await collectConnectionActivity(this.pc);

    if (!hasConnectionActivity(before, after)) {
      this.recoveryActivityDeferrals = 0;
      return false;
    }

    const deferrals = this.recoveryActivityDeferrals || 0;

    if (deferrals >= DISCONNECTED_ACTIVITY_DEFERRAL_LIMIT) {
      this.recoveryActivityDeferrals = 0;
      return false;
    }

    this.recoveryActivityDeferrals = deferrals + 1;
    log.debug("[group-call] deferring recovery while media/data still moves", {
      reason,
      deferrals: this.recoveryActivityDeferrals,
    });
    this._scheduleRecovery(reason, { countAttempt: false });
    return true;
  },

  _scheduleOfferWatchdog(trigger = "join") {
    if (
      this.offerWatchdogTimer ||
      this.offerWatchdogAttempts >= OFFER_WATCHDOG_MAX_ATTEMPTS ||
      !this._needsOfferWatchdog()
    ) {
      return;
    }

    const attempt = this.offerWatchdogAttempts + 1;
    this.offerWatchdogAttempts = attempt;

    this.offerWatchdogTimer = setTimeout(() => {
      this.offerWatchdogTimer = null;
      if (!this._needsOfferWatchdog()) return;

      this._requestOfferFromWatchdog(trigger, attempt);

      if (attempt >= OFFER_WATCHDOG_MAX_ATTEMPTS) {
        this.offerWatchdogTimer = setTimeout(() => {
          this.offerWatchdogTimer = null;
          if (this._needsOfferWatchdog()) {
            this._publishRecoveryState({
              state: "failed",
              reason: "offer_not_received",
              trigger: "offer_watchdog",
              attempt,
              max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
              manual_retry: true,
              message: t("Media offer was not received. Retry the media connection."),
            });
          }
        }, OFFER_WATCHDOG_DELAY_MS);
        return;
      }

      this._scheduleOfferWatchdog(trigger);
    }, OFFER_WATCHDOG_DELAY_MS * attempt);
  },

  _needsOfferWatchdog() {
    return !this.closing && !this.rejoining && !this.pc?.remoteDescription;
  },

  _requestOfferFromWatchdog(trigger, attempt) {
    this._publishRecoveryState({
      state: "reconnecting",
      reason: "offer_not_received",
      trigger: "offer_watchdog",
      attempt,
      max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
      message: t("Waiting for media offer. Requesting a fresh offer."),
    });

    const push = this.channel?.push("group_call_request_offer", {
      attempt,
      trigger: "offer_watchdog",
      reason: trigger,
    });

    if (!push?.receive) {
      this._publishRecoveryState({
        state: "failed",
        reason: "offer_not_received",
        trigger: "offer_watchdog",
        attempt,
        max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
        manual_retry: true,
        message: t("Media recovery failed. Retry the media connection."),
      });
      return;
    }

    push
      .receive("error", (reply) => {
        if (reply?.code === "rejoin_required") {
          this._rejoinConnection("offer_watchdog", reply);
          return;
        }

        this._publishRecoveryState({
          state: "failed",
          reason: reply?.code || "offer_not_received",
          trigger: "offer_watchdog",
          attempt,
          max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
          manual_retry: true,
          message: reply?.message || t("Media recovery failed. Retry the media connection."),
        });
      })
      .receive("timeout", () => {
        this._publishRecoveryState({
          state: "failed",
          reason: "offer_request_timeout",
          trigger: "offer_watchdog",
          attempt,
          max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
          manual_retry: true,
          message: t("Media recovery timed out. Retry the media connection."),
        });
      });
  },

  _retryConnection(trigger = "manual") {
    if (this.recoveryTimer) {
      clearTimeout(this.recoveryTimer);
      this.recoveryTimer = null;
    }

    if (this.recoveryAttempts < 1) this.recoveryAttempts = 1;

    const attempt = this.recoveryAttempts;

    this._publishRecoveryState({
      state: "negotiating",
      trigger,
      attempt,
      max_attempts: this.maxRecoveryAttempts,
      message: t("Requesting a fresh media offer."),
    });

    const push = this.channel?.push("group_call_request_offer", {
      attempt,
      trigger,
    });

    if (!push?.receive) {
      this._publishRecoveryState({
        state: "failed",
        trigger,
        attempt,
        max_attempts: this.maxRecoveryAttempts,
        manual_retry: true,
        message: t("Media recovery failed. Retry the media connection."),
      });
      return;
    }

    push
      .receive("error", (reply) => {
        if (reply?.code === "rejoin_required") {
          this._rejoinConnection(trigger, reply);
          return;
        }

        this._publishRecoveryState({
          state: "failed",
          trigger,
          attempt,
          max_attempts: this.maxRecoveryAttempts,
          manual_retry: true,
          message: reply?.message || t("Media recovery failed. Retry the media connection."),
        });
      })
      .receive("timeout", () => {
        this._publishRecoveryState({
          state: "failed",
          trigger,
          attempt,
          max_attempts: this.maxRecoveryAttempts,
          manual_retry: true,
          message: t("Media recovery timed out. Retry the media connection."),
        });
      });
  },

  _handleRemoteVideoStalled(streamId, reason = "remote_video_stalled") {
    const key = stringOrNull(streamId);
    if (!key || this.remoteVideoStalls?.get(key) === true) return;

    this.remoteVideoStalls.set(key, true);
    this._publishRecoveryState({
      state: "reconnecting",
      reason,
      trigger: "remote_video_stalled",
      attempt: this.recoveryAttempts || 1,
      max_attempts: this.maxRecoveryAttempts,
      message: t("Remote video stopped rendering. Trying to recover the media path."),
    });
    this._retryConnection("remote_video_stalled");
  },

  _rejoinConnection(trigger = "manual", reply = {}) {
    if (this.rejoining) return;

    const previousParticipantId = this.participantId;
    this.rejoining = true;
    this.rejoinEpoch += 1;

    this._publishRecoveryState({
      state: "rejoining",
      trigger,
      attempt: this.recoveryAttempts,
      max_attempts: this.maxRecoveryAttempts,
      manual_retry: false,
      message: reply?.message || t("Rejoining the media session."),
    });

    this._prepareTransportRejoin();
    this._joinGroupCall("rejoin", { previousParticipantId });
  },

  _prepareTransportRejoin() {
    this._stopStatsPolling();
    this._clearOfferWatchdog();
    this.pendingCandidates = [];
    this.remoteCandidateFailures = 0;
    this.offerQueue = Promise.resolve();
    this.lastAnsweredOfferSdp = null;
    this.lastAnsweredOfferId = null;

    this._clearScreenShareForRejoin();

    if (this.pc) {
      this.pc.onconnectionstatechange = null;
      this.pc.onicecandidate = null;
      this.pc.ontrack = null;
      this.pc.close();
    }

    this.pc = null;
    this.localSenders = [];
    this._sendersPc = null;
    this.videoSender = null;
    this.cameraVideoTrack = this.localStream?.getVideoTracks?.()[0] || null;

    this._clearRemoteTilesForRejoin();
  },

  _clearScreenShareForRejoin() {
    if (!this.screenShare?.active) return;

    if (this.screenShare.track) this.screenShare.track.onended = null;
    this._stopStream(this.screenShare.stream);
    this.screenShare = { active: false, stream: null, track: null };
    this._publishScreenShareState(false, null, null);
    if (this.localStream) this._attachLocalStream(this.localStream);
    this._syncLocalTile();
  },

  _clearRemoteTilesForRejoin() {
    for (const tile of this.remoteTiles?.values?.() || []) {
      tile.remove();
    }

    this.remoteTiles?.clear();
    this.remoteVideoStalls?.clear();
    this.tracksById?.clear();
    this.tracksByStreamId?.clear();
    this.tracksByWebrtcTrackId?.clear();
    this._applyLayout();
  },

  _clearRecovery(reason = "connected") {
    if (this.recoveryTimer) {
      clearTimeout(this.recoveryTimer);
      this.recoveryTimer = null;
    }

    this.recoveryAttempts = 0;
    this.recoveryActivityDeferrals = 0;
    this.remoteCandidateFailures = 0;
    this._clearOfferWatchdog();
    this.remoteVideoStalls?.clear();
    this._publishRecoveryState({
      state: "connected",
      reason,
      attempt: 0,
      max_attempts: this.maxRecoveryAttempts,
      manual_retry: false,
      message: "",
    });
  },

  _publishRecoveryState(payload) {
    this.pushEvent("group_call_recovery_state", {
      attempt: 0,
      max_attempts: this.maxRecoveryAttempts,
      manual_retry: false,
      next_retry_ms: 0,
      ...payload,
    });
  },

  _notifyError(message, code = "connection_failed") {
    this.pushEvent("group_call_client_error", { code, message });
  },

  _notifyWarning(message, code = "media_warning") {
    this.pushEvent("group_call_client_warning", { code, message });
  },

  _clearOfferWatchdog() {
    if (this.offerWatchdogTimer) {
      clearTimeout(this.offerWatchdogTimer);
      this.offerWatchdogTimer = null;
    }

    this.offerWatchdogAttempts = 0;
  },

  _startStatsPolling() {
    if (this.statsTimer) return;

    this.statsPrev = null;
    this.statsTimer = setInterval(() => this._sampleStats(), STATS_INTERVAL_MS);
    this._sampleStats();
  },

  async _sampleStats() {
    if (!this.pc) return;

    try {
      const reports = await this.pc.getStats();
      const snapshot = collectFeatureSnapshotFromReports(reports);
      const stats = deriveFeatureStats(this.statsPrev, snapshot);
      this.statsPrev = snapshot;
      const participantQuality = this._deriveParticipantQuality(reports, stats.connection);

      this.pushEvent("group_call_stats", {
        ...stats,
        updated_at_ms: Date.now(),
        connection_state: this.pc.connectionState || "",
        summary: {
          connection_state: this.pc.connectionState || "",
          participant_count: this.participantsById.size,
          remote_stream_count: this.remoteTiles.size,
          track_count: this.tracksById.size,
          screen_share_active: this.screenShare?.active === true,
          offer_id: this.lastAnsweredOfferId || "",
          rejoin_epoch: this.rejoinEpoch || 0,
        },
      });

      if (participantQuality.participants.length > 0) {
        this._syncParticipantQualityState(participantQuality);
        this.pushEvent("group_call_participant_quality", participantQuality);
      }
    } catch (error) {
      log.debug("[group-call] stats sample failed", error);
    }
  },

  _deriveParticipantQuality(reports, connectionStats = {}) {
    const snapshot = collectQualitySnapshot(
      reports,
      (report) => this._participantIdForStatsReport(report),
      Date.now(),
    );
    const previous = this.participantStatsPrev;
    this.participantStatsPrev = snapshot;

    return deriveParticipantQuality(snapshot, previous, {
      connectionStats,
      connectionState: this.pc?.connectionState || "",
      now: Date.now(),
    });
  },

  _participantIdForStatsReport(report) {
    const explicitParticipantId = stringOrNull(report.participant_id ?? report.participantId);
    if (explicitParticipantId) return explicitParticipantId;

    const trackIdentifier = stringOrNull(
      report.trackIdentifier ?? report.trackId ?? report.track_id,
    );

    if (trackIdentifier) {
      const persistedTrack = this.tracksByWebrtcTrackId.get(trackIdentifier);
      if (persistedTrack?.participantId) return persistedTrack.participantId;

      for (const tile of this._remoteTileElements()) {
        if (!tile.dataset.participantId) continue;

        const stream = tile.querySelector("video")?.srcObject;
        const tracks = Array.from(stream?.getTracks?.() || []);
        if (tracks.some((track) => track.id === trackIdentifier)) {
          return tile.dataset.participantId;
        }
      }
    }

    const assignedTiles = this._remoteTileElements().filter((tile) => tile.dataset.participantId);

    return assignedTiles.length === 1 ? assignedTiles[0].dataset.participantId : null;
  },

  _syncParticipantQualityState(payload) {
    this.activeSpeakerParticipantId = stringOrNull(
      payload.active_speaker_participant_id ?? payload.activeSpeakerParticipantId,
    );

    for (const quality of payload.participants || []) {
      const participantId = stringOrNull(quality.participant_id ?? quality.participantId);
      if (!participantId) continue;

      const normalized = {
        participant_id: participantId,
        level: quality.level || "unknown",
        label: quality.label || participantQualityLabel(quality.level),
        speaking: quality.speaking === true,
        rtt_ms: Number(quality.rtt_ms || quality.rttMs || 0),
        jitter_ms: Number(quality.jitter_ms || quality.jitterMs || 0),
        loss_pct: Number(quality.loss_pct || quality.lossPct || 0),
        bitrate_kbps: Number(quality.bitrate_kbps || quality.bitrateKbps || 0),
        fps: Number(quality.fps || 0),
        freeze_count: Number(quality.freeze_count || quality.freezeCount || 0),
        audio_level: Number(quality.audio_level || quality.audioLevel || 0),
      };

      this.participantQualityById.set(participantId, normalized);
      const participant = this.participantsById.get(participantId);
      if (participant) participant.quality = normalized;

      const remoteTiles = this._tilesForParticipant(participantId).filter(
        (tile) => tile.dataset.local !== "true",
      );

      if (remoteTiles.length === 0) {
        const unassignedRemoteTiles = this._remoteTileElements().filter(
          (tile) => !tile.dataset.participantId,
        );

        if (unassignedRemoteTiles.length === 1) {
          unassignedRemoteTiles[0].dataset.participantId = participantId;
          this._applyParticipantToTile(unassignedRemoteTiles[0], participantId);
        }
      }
    }

    for (const tile of this.el.querySelectorAll("[data-group-call-video-tile]")) {
      const participantId = tile.dataset.participantId;
      if (participantId) this._applyParticipantQualityToTile(tile, participantId);
    }

    this._applyLayout();
  },

  _applyParticipantQualityToTile(tile, participantId) {
    const id = stringOrNull(participantId);
    const quality = id ? this.participantQualityById?.get(id) : null;
    const level = quality?.level || "unknown";
    const activeSpeaker = id && this.activeSpeakerParticipantId === id;

    tile.dataset.qualityLevel = level;
    tile.dataset.activeSpeaker = String(activeSpeaker === true);

    const qualityBadge = tile.querySelector("[data-group-call-quality-badge]");
    if (qualityBadge) {
      qualityBadge.hidden = !quality || level === "unknown";
      qualityBadge.dataset.qualityLevel = level;
      const qualityTitle = quality && level !== "unknown" ? participantQualityTitle(quality) : "";
      qualityBadge.title = qualityTitle;
      qualityBadge.setAttribute("aria-label", qualityTitle);
    }

    const speakerBadge = tile.querySelector("[data-group-call-active-speaker-badge]");
    if (speakerBadge) {
      speakerBadge.title = activeSpeaker ? "Speaking" : "Not speaking";
      speakerBadge.setAttribute("aria-label", speakerBadge.title);
    }
  },

  _stopStatsPolling() {
    if (!this.statsTimer) return;

    clearInterval(this.statsTimer);
    this.statsTimer = null;
    this.statsPrev = null;
    this.participantStatsPrev = null;
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
      this.el.removeEventListener("group-call:toggle-screen-share", this.toggleScreenShareHandler);
    }
    if (this.participantQualityEventHandler) {
      this.el.removeEventListener(
        "group-call:participant-quality",
        this.participantQualityEventHandler,
      );
    }
    if (this.recoveryStateEventHandler) {
      this.el.removeEventListener("group-call:recovery-state", this.recoveryStateEventHandler);
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
    this.participantsById?.clear();
    this.tracksById?.clear();
    this.tracksByStreamId?.clear();
    this.tracksByWebrtcTrackId?.clear();
    this.remoteTiles?.clear();
    this.remoteVideoStalls?.clear();
  },
};

export default GroupCallWebRTCHook;
