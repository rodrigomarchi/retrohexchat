/**
 * LiveView Hook: GroupCallWebRTCHook
 *
 * Minimal browser-side SFU client. It uses a raw Phoenix Channel so SDP/ICE do
 * not travel through the ChatLive process.
 */
import { Socket } from "phoenix";
import { log } from "../../lib/logger.js";
import { collectFeatureSnapshot, deriveFeatureStats } from "../../lib/p2p/media.js";

const DEFAULT_CONSTRAINTS = { audio: true, video: true };
const LAYOUT_MODES = new Set(["auto", "grid", "focus", "sidebar"]);
const SELF_VIEW_MODES = new Set(["tile", "pip", "hidden"]);
const STATS_INTERVAL_MS = 2500;

const GroupCallWebRTCHook = {
  mounted() {
    this.roomToken = this.el.dataset.groupCallToken;
    this.joinToken = this.el.dataset.joinToken;
    this.localStream = null;
    this.pc = null;
    this.socket = null;
    this.channel = null;
    this.pendingCandidates = [];
    this.participantId = null;
    this.mediaEnabled = this._mediaConstraints();
    this.closing = false;
    this.offerQueue = Promise.resolve();
    this.lastAnsweredOfferSdp = null;
    this.layoutState = this._layoutStateFromDataset();
    this.participantsById = new Map();
    this.tracksById = new Map();
    this.tracksByStreamId = new Map();
    this.tracksByWebrtcTrackId = new Map();
    this.remoteTiles = new Map();
    this.statsTimer = null;
    this.statsPrev = null;

    if (!this.roomToken || !this.joinToken) {
      log.warn("[group-call] missing room token or join token");
      return;
    }

    this.handleEvent("group_call_set_media_state", (payload) => {
      this._setMediaState(payload || {});
    });

    this.handleEvent("group_call_layout_state", (payload) => {
      this._syncLayoutState(payload || {});
    });

    this._bindLocalTile();
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

    this.channel.on("group_call_joined", (payload) => {
      this.participantId = payload?.participant?.id || null;
      this._upsertParticipant(payload?.participant);
      this._syncParticipants(payload?.participants || []);
      this._syncTracks(payload?.tracks || []);
      this._syncLocalTile();
      this.pushEvent("group_call_client_joined", payload);
      this.channel?.push("group_call_media_state", this.mediaEnabled);
    });
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
    this.channel.on("group_call_set_media_state", (payload) => {
      this._setMediaState(payload || {});
      this.pushEvent("group_call_media_state_forced", payload || {});
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
        this._notifyError("Group call signaling connection failed", "signaling_failed");
      }
    });
    this.channel.onClose(() => {
      if (!this.closing && this.participantId) {
        this._notifyWarning("Group call signaling channel closed", "signaling_closed");
      }
    });

    this.channel
      .join()
      .receive("ok", () => {
        this.channel
          .push("group_call_join", {
            client_info: this._clientInfo(),
            media_constraints: this.mediaEnabled,
          })
          .receive("error", (reply) => {
            this._notifyError(reply?.message || "Unable to join group call", "join_failed");
          })
          .receive("timeout", () => {
            this._notifyError("Group call join timed out", "join_timeout");
          });
      })
      .receive("error", (reply) => {
        log.warn("[group-call] channel join rejected", reply);
        this._notifyError(
          reply?.reason || "Group call channel rejected the join",
          "channel_join_rejected",
        );
      })
      .receive("timeout", () => {
        log.warn("[group-call] channel join timed out");
        this._notifyError("Group call channel join timed out", "channel_join_timeout");
      });
  },

  _handleOffer(payload) {
    this.offerQueue = this.offerQueue.catch(() => {}).then(() => this._processOffer(payload || {}));

    return this.offerQueue;
  },

  async _processOffer({ sdp, ice_servers }) {
    if (!sdp) {
      this._notifyError("Group call media negotiation failed", "media_negotiation_failed");
      return;
    }

    if (this.lastAnsweredOfferSdp === sdp) {
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
      });
      this.lastAnsweredOfferSdp = sdp;
    } catch (error) {
      log.warn("[group-call] failed to handle offer", error);
      this._notifyError("Group call media negotiation failed", "media_negotiation_failed");
    }
  },

  async _ensurePeerConnection(iceServers) {
    if (this.pc) return;

    this.pc = new RTCPeerConnection({ iceServers });

    this.pc.onconnectionstatechange = () => {
      this.pushEvent("group_call_connection_state", {
        state: this.pc.connectionState,
      });
    };

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
    if (this.localStream) return;

    try {
      this.localStream = await navigator.mediaDevices.getUserMedia(this.mediaEnabled);
    } catch (error) {
      log.warn("[group-call] media capture failed, answering recvonly", error);
      this._notifyWarning(
        "Could not access your microphone or camera. You joined receive-only.",
        "media_capture_failed",
      );
      return;
    }

    for (const track of this.localStream.getTracks()) {
      this.pc.addTrack(track, this.localStream);
    }

    this._attachLocalStream(this.localStream);
    this._applyMediaEnabled();
  },

  async _handleRemoteCandidate(candidate) {
    if (!candidate) return;

    if (!this.pc || !this.pc.remoteDescription) {
      this.pendingCandidates.push(candidate);
      return;
    }

    try {
      await this.pc.addIceCandidate(candidate);
    } catch (error) {
      log.warn("[group-call] failed to add ICE candidate", error);
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

    video.srcObject = stream;
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
    name.textContent = "Remote";

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
    tile.setAttribute("aria-label", "Focus your video");
    tile.title = "Focus your video";
    this._applyLayout();
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
      mode: this._normalizeLayoutMode(this.el.dataset.layoutMode),
      focusedParticipantId: this._stringOrNull(this.el.dataset.focusedParticipantId),
      focusedStreamId: null,
      selfView: this._normalizeSelfView(this.el.dataset.selfView),
      sidebarOpen: this.el.dataset.sidebarOpen !== "false",
    };
  },

  _syncLayoutState(payload) {
    const mode = this._payloadValue(payload, "mode");
    const focusedParticipantId = this._payloadValue(
      payload,
      "focused_participant_id",
      "focusedParticipantId",
    );
    const focusedStreamId = this._payloadValue(payload, "focused_stream_id", "focusedStreamId");
    const selfView = this._payloadValue(payload, "self_view", "selfView");
    const sidebarOpen = this._payloadValue(payload, "sidebar_open", "sidebarOpen");
    const selfParticipantId = this._payloadValue(
      payload,
      "self_participant_id",
      "selfParticipantId",
    );

    this.layoutState = {
      ...this.layoutState,
      mode: mode === undefined ? this.layoutState.mode : this._normalizeLayoutMode(mode),
      focusedParticipantId:
        focusedParticipantId === undefined
          ? this.layoutState.focusedParticipantId
          : this._stringOrNull(focusedParticipantId),
      focusedStreamId:
        focusedStreamId === undefined
          ? this.layoutState.focusedStreamId
          : this._stringOrNull(focusedStreamId),
      selfView:
        selfView === undefined ? this.layoutState.selfView : this._normalizeSelfView(selfView),
      sidebarOpen: sidebarOpen === undefined ? this.layoutState.sidebarOpen : sidebarOpen !== false,
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
      nickname: participant.nickname || "Remote",
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

    for (const [streamId, tile] of this.remoteTiles) {
      if (tile.dataset.participantId !== id) continue;
      tile.remove();
      this.remoteTiles.delete(streamId);
    }

    if (this.layoutState.focusedParticipantId === id) {
      this.layoutState.focusedParticipantId = null;
      this.layoutState.mode = "auto";
    }

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
      participantId: this._stringOrNull(track.participant_id ?? track.participantId),
      kind: track.kind,
      status: track.status,
      streamId: this._stringOrNull(track.stream_id ?? track.streamId),
      webrtcTrackId: this._stringOrNull(track.webrtc_track_id ?? track.webrtcTrackId),
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
  },

  _applyParticipantToTile(tile, participantId) {
    const participant = this.participantsById.get(String(participantId));
    if (!participant) return;

    const name = tile.querySelector("[data-group-call-tile-name]");
    const media = participant.media_state || {};
    const audio = media.audio !== false;
    const video = media.video !== false;

    if (name) name.textContent = participant.nickname || "Remote";
    tile.dataset.mediaAudio = String(audio);
    tile.dataset.mediaVideo = String(video);
    tile.setAttribute("aria-label", `Focus ${participant.nickname || "participant"}`);
    tile.title = `Focus ${participant.nickname || "participant"}`;
  },

  _tilesForParticipant(participantId) {
    return Array.from(this.el.querySelectorAll("[data-group-call-video-tile]")).filter(
      (tile) => tile.dataset.participantId === String(participantId),
    );
  },

  _applyLayout() {
    if (!this.layoutState) return;

    const host = this._videoGrid();
    const tiles = Array.from(this.el.querySelectorAll("[data-group-call-video-tile]"));
    const visibleTiles = tiles.filter((tile) => this._tileVisible(tile));
    const focusedTile = this._focusedTile(visibleTiles);
    const remoteCount = Array.from(this.remoteTiles.values()).filter((tile) =>
      this._tileVisible(tile),
    ).length;

    this.el.dataset.layoutMode = this.layoutState.mode;
    this.el.dataset.selfView = this.layoutState.selfView;
    this.el.dataset.sidebarOpen = String(this.layoutState.sidebarOpen);
    if (this.layoutState.focusedParticipantId) {
      this.el.dataset.focusedParticipantId = this.layoutState.focusedParticipantId;
    } else {
      delete this.el.dataset.focusedParticipantId;
    }

    host.dataset.tileCount = String(visibleTiles.length);

    for (const tile of tiles) {
      const focused = focusedTile === tile;
      tile.dataset.focused = String(focused);
      tile.classList.toggle("group-call-video-tile--focused", focused);
    }

    const placeholder = this.el.querySelector("[data-group-call-remote-placeholder]");
    placeholder?.classList.toggle("hidden", remoteCount > 0);
  },

  _focusedTile(tiles) {
    if (!["focus", "sidebar"].includes(this.layoutState.mode)) return null;

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

  _normalizeLayoutMode(mode) {
    return LAYOUT_MODES.has(mode) ? mode : "auto";
  },

  _normalizeSelfView(mode) {
    return SELF_VIEW_MODES.has(mode) ? mode : "tile";
  },

  _stringOrNull(value) {
    if (value === undefined || value === null || value === "") return null;
    return String(value);
  },

  _payloadValue(payload, ...keys) {
    for (const key of keys) {
      if (Object.prototype.hasOwnProperty.call(payload, key)) return payload[key];
    }

    return undefined;
  },

  _mediaConstraints() {
    const audio = this.el.dataset.audio !== "false";
    const video = this.el.dataset.video !== "false";
    return { ...DEFAULT_CONSTRAINTS, audio, video };
  },

  _setMediaState(payload) {
    this.mediaEnabled = {
      audio: payload.audio !== false,
      video: payload.video !== false,
    };

    this._applyMediaEnabled();
    this._syncLocalTile();

    if (this.participantId) {
      this.channel?.push("group_call_media_state", this.mediaEnabled);
    }
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

  _notifyError(message, code = "connection_failed") {
    this.pushEvent("group_call_client_error", { code, message });
  },

  _notifyWarning(message, code = "media_warning") {
    this.pushEvent("group_call_client_warning", { code, message });
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
      const snapshot = await collectFeatureSnapshot(this.pc);
      const stats = deriveFeatureStats(this.statsPrev, snapshot);
      this.statsPrev = snapshot;

      this.pushEvent("group_call_stats", {
        ...stats,
        updated_at_ms: Date.now(),
        connection_state: this.pc.connectionState || "",
        summary: {
          connection_state: this.pc.connectionState || "",
          participant_count: this.participantsById.size,
          remote_stream_count: this.remoteTiles.size,
          track_count: this.tracksById.size,
        },
      });
    } catch (error) {
      log.debug("[group-call] stats sample failed", error);
    }
  },

  _stopStatsPolling() {
    if (!this.statsTimer) return;

    clearInterval(this.statsTimer);
    this.statsTimer = null;
    this.statsPrev = null;
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
    this._stopStatsPolling();
    this.channel?.push("group_call_leave", {});
    this.channel?.leave();
    this.socket?.disconnect();

    this.localStream?.getTracks()?.forEach((track) => track.stop());
    this.pc?.close();

    this.channel = null;
    this.socket = null;
    this.localStream = null;
    this.pc = null;
    this.pendingCandidates = [];
    this.participantId = null;
    this.offerQueue = Promise.resolve();
    this.lastAnsweredOfferSdp = null;
    this.participantsById?.clear();
    this.tracksById?.clear();
    this.tracksByStreamId?.clear();
    this.tracksByWebrtcTrackId?.clear();
    this.remoteTiles?.clear();
  },
};

export default GroupCallWebRTCHook;
