/**
 * The conference's tiles on the page: participants and tracks drawn onto
 * them, the local tile and its empty state, focus and pinning, and the layout
 * the server sends. Mixed into the controller by `createConferenceConnection`;
 * the methods share its `this`.
 */
import { t } from "../i18n.js";
import {
  idsFromValue,
  normalizeLayoutMode,
  normalizeSelfView,
  payloadValue,
  stringOrNull,
  tileDensity,
} from "./payload.js";
import { focusedTileIndex, isTilePinned, tileIsVisible } from "./layout.js";
import { localEmptyState, localEmptyStateCopy, participantTileMedia } from "./tiles.js";
import { syncNickFlag } from "../nick_flag.js";

export function tileMethods(el, ports) {
  return {
    _videoGrid() {
      return el.querySelector("[data-group-call-video-grid]") || el;
    },

    _bindLocalTile() {
      const tile = el.querySelector("[data-group-call-local-tile]");
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
      const tile = el.querySelector("[data-group-call-local-tile]");
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
      return localEmptyState({
        screenShareActive: this.screenShare?.active === true,
        audioEnabled: this.mediaEnabled.audio,
        videoEnabled: this.mediaEnabled.video,
      });
    },

    _syncLocalEmptyState(tile) {
      const title = tile.querySelector("[data-group-call-local-empty-title]");
      const detail = tile.querySelector("[data-group-call-local-empty-detail]");
      const copy = localEmptyStateCopy(tile.dataset.localEmptyState);

      if (title) title.textContent = copy.title;
      if (detail) detail.textContent = copy.detail;
    },

    _toggleTileFocus(tile) {
      const participantId = tile.dataset.participantId || null;
      const streamId = tile.dataset.streamId || null;
      const isFocused = tile.dataset.focused === "true";

      if (isFocused) {
        ports.pushEvent("group_call_clear_focus", {});
        this.syncLayoutState({
          mode: "auto",
          focused_participant_id: null,
          focused_stream_id: null,
        });
        return;
      }

      if (participantId) {
        ports.pushEvent("group_call_focus_participant", {
          participant_id: participantId,
          "participant-id": participantId,
        });
        return;
      }

      this.syncLayoutState({
        mode: "focus",
        focused_participant_id: null,
        focused_stream_id: streamId,
      });
    },

    _layoutStateFromDataset() {
      return {
        mode: normalizeLayoutMode(el.dataset.layoutMode),
        focusedParticipantId: stringOrNull(el.dataset.focusedParticipantId),
        focusedStreamId: null,
        selfView: normalizeSelfView(el.dataset.selfView),
        pinnedParticipantIds: idsFromValue(el.dataset.pinnedParticipantIds),
      };
    },

    syncLayoutState(payload) {
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
      const record = this.participantRegistry.upsert(participant);
      if (!record) return;

      const id = record.id;
      for (const tile of this.tileView.tilesForParticipant(id)) {
        this._applyParticipantToTile(tile, id);
      }

      if (String(this.participantId || "") === id) {
        this._syncLocalTile();
      }
    },

    _removeParticipant(participantId) {
      if (!participantId) return;

      const id = String(participantId);
      this.participantRegistry.remove(id);
      this.participantQualityById?.delete(id);
      if (this.activeSpeakerParticipantId === id) this.activeSpeakerParticipantId = null;

      for (const streamId of this.tileView.removeByParticipant(id)) {
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
      const normalized = this.trackRegistry.upsert(track);
      if (!normalized) return;

      if (normalized.streamId) {
        const tile = this.tileView.get(normalized.streamId);
        if (tile) this._applyTrackToTile(tile, normalized.streamId);
      }
    },

    _removeTrack(trackId) {
      this.trackRegistry.remove(trackId);
    },

    _applyStreamOwners(owners) {
      if (!owners) return;
      this.trackRegistry.setStreamOwners(owners);
      for (const streamId of this.trackRegistry.ownedStreamIds()) {
        const tile = this.tileView.get(streamId);
        if (tile) this._applyTrackToTile(tile, streamId);
      }
    },

    _applyTrackToTile(tile, streamId, browserTrack = null) {
      const track = this.trackRegistry.forTile(streamId, browserTrack?.id);

      if (track?.participantId) {
        tile.dataset.participantId = track.participantId;
        this._applyParticipantToTile(tile, track.participantId);
      }

      // A stream known only by its owner says nothing about what it carries;
      // the screen-share state events keep the tile's source current.
      const source = track?.source || tile.dataset.trackSource || "camera";
      tile.dataset.trackSource = source;
      tile.dataset.mediaScreen = String(source === "screen");

      if (track?.participantId) {
        this._applyParticipantToTile(tile, track.participantId);
      }
    },

    _applyParticipantToTile(tile, participantId) {
      const participant = this.participantRegistry.get(participantId);
      if (!participant) return;

      const nameEl = tile.querySelector("[data-group-call-tile-name]");
      const { audio, video, screen, name, label } = participantTileMedia(
        participant,
        tile.dataset.trackSource || null,
      );

      if (nameEl) {
        nameEl.textContent = name;
        syncNickFlag(nameEl, participant.flag);
      }
      tile.dataset.mediaAudio = String(audio);
      tile.dataset.mediaVideo = String(video);
      tile.dataset.mediaScreen = String(screen);
      this._applyParticipantQualityToTile(tile, participantId);

      tile.setAttribute("aria-label", label);
      tile.title = label;
    },

    _applyScreenShareStateToTiles(payload) {
      const participantId = stringOrNull(payload.participant_id ?? payload.participantId);
      if (!participantId) return;

      const active = payload.active === true;
      const source = active ? "screen" : "camera";
      const participant = this.participantRegistry.get(participantId);

      if (participant) {
        participant.media_state = {
          ...(participant.media_state || {}),
          screen: active,
        };
      }

      let tiles = this.tileView
        .tilesForParticipant(participantId)
        .filter((tile) => tile.dataset.local !== "true");

      if (tiles.length === 0) {
        const unassigned = this._soleUnassignedRemoteTile();
        if (unassigned) tiles = [unassigned];
      }

      for (const tile of tiles) {
        tile.dataset.participantId = participantId;
        tile.dataset.trackSource = source;
        tile.dataset.mediaScreen = String(active);
        this._applyParticipantToTile(tile, participantId);
      }

      this._applyLayout();
    },

    // A remote tile can arrive before the event that says whose it is. While
    // exactly one tile is waiting for an owner, a participant with no tile of
    // their own is that tile's owner; with two or more the guess could be wrong.
    _soleUnassignedRemoteTile() {
      const unassigned = this.tileView
        .remoteTileElements()
        .filter((tile) => !tile.dataset.participantId);

      return unassigned.length === 1 ? unassigned[0] : null;
    },

    _claimUnassignedRemoteTile(participantId) {
      const tile = this._soleUnassignedRemoteTile();
      if (!tile) return [];

      tile.dataset.participantId = participantId;
      this._applyParticipantToTile(tile, participantId);
      return [tile];
    },

    _applyLayout() {
      if (!this.layoutState) return;

      const host = this._videoGrid();
      const tiles = Array.from(el.querySelectorAll("[data-group-call-video-tile]"));
      const visibleTiles = tiles.filter((tile) => this._tileVisible(tile));
      const focusedIndex = focusedTileIndex(
        {
          mode: this.layoutState.mode,
          activeSpeakerId: this.activeSpeakerParticipantId,
          focusedParticipantId: this.layoutState.focusedParticipantId,
          focusedStreamId: this.layoutState.focusedStreamId,
        },
        visibleTiles.map((tile) => ({
          participantId: tile.dataset.participantId,
          streamId: tile.dataset.streamId,
          isLocal: tile.dataset.local === "true",
        })),
      );
      const focusedTile = focusedIndex >= 0 ? visibleTiles[focusedIndex] : null;
      const remoteCount = this.tileView
        .remoteTileElements()
        .filter((tile) => this._tileVisible(tile)).length;

      el.dataset.layoutMode = this.layoutState.mode;
      el.dataset.selfView = this.layoutState.selfView;
      el.dataset.pinnedParticipantIds = (this.layoutState.pinnedParticipantIds || []).join(",");
      if (this.layoutState.focusedParticipantId) {
        el.dataset.focusedParticipantId = this.layoutState.focusedParticipantId;
      } else {
        delete el.dataset.focusedParticipantId;
      }

      host.dataset.tileCount = String(visibleTiles.length);
      host.dataset.tileDensity = tileDensity(visibleTiles.length);
      host.dataset.remoteCount = String(remoteCount);

      for (const tile of tiles) {
        const focused = focusedTile === tile;
        const participantId = stringOrNull(tile.dataset.participantId);
        const pinned = isTilePinned(participantId, this.layoutState.pinnedParticipantIds || []);
        tile.dataset.focused = String(focused);
        tile.dataset.pinned = String(pinned);
        tile.classList.toggle("group-call-video-tile--focused", focused);
        tile.classList.toggle("group-call-video-tile--pinned", pinned);
      }

      const placeholder = el.querySelector("[data-group-call-remote-placeholder]");
      placeholder?.classList.toggle("hidden", remoteCount > 0);
    },

    _tileVisible(tile) {
      return tileIsVisible(tile.dataset.local === "true", this.layoutState.selfView);
    },
  };
}
