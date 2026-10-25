/**
 * The group call's stats on the conference connection: sampling the peer
 * connection, deriving each participant's quality and the active speaker, and
 * drawing it on the tiles. Mixed into the controller by
 * `createConferenceConnection`; the methods share its `this`.
 */
import { t } from "../i18n.js";
import { log } from "../logger.js";
import {
  collectQualitySnapshot,
  deriveParticipantQuality,
  participantQualityLabel,
  participantQualityTitle,
} from "./quality.js";
import { stringOrNull } from "./payload.js";
import { collectFeatureSnapshotFromReports, deriveFeatureStats } from "../p2p/media.js";

const STATS_INTERVAL_MS = 2500;

export function statsMethods(el, ports) {
  return {
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

        ports.pushEvent("group_call_stats", {
          ...stats,
          updated_at_ms: Date.now(),
          connection_state: this.pc.connectionState || "",
          summary: {
            connection_state: this.pc.connectionState || "",
            participant_count: this.participantRegistry.size,
            remote_stream_count: this.tileView.size,
            track_count: this.trackRegistry.size,
            screen_share_active: this.screenShare?.active === true,
            offer_id: this.lastAnsweredOfferId || "",
            rejoin_epoch: this.rejoinEpoch || 0,
          },
        });

        if (participantQuality.participants.length > 0) {
          this._syncParticipantQualityState(participantQuality);
          ports.pushEvent("group_call_participant_quality", participantQuality);
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
        const persistedTrack = this.trackRegistry.byWebrtcTrackId(trackIdentifier);
        if (persistedTrack?.participantId) return persistedTrack.participantId;

        for (const tile of this.tileView.remoteTileElements()) {
          if (!tile.dataset.participantId) continue;

          const stream = tile.querySelector("video")?.srcObject;
          const tracks = Array.from(stream?.getTracks?.() || []);
          if (tracks.some((track) => track.id === trackIdentifier)) {
            return tile.dataset.participantId;
          }
        }
      }

      const assignedTiles = this.tileView
        .remoteTileElements()
        .filter((tile) => tile.dataset.participantId);

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
          // Re-derive locally so each viewer reads the label in its own locale,
          // rather than the sender's translated label from the broadcast payload.
          label: participantQualityLabel(quality.level),
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
        const participant = this.participantRegistry.get(participantId);
        if (participant) participant.quality = normalized;

        const remoteTiles = this.tileView
          .tilesForParticipant(participantId)
          .filter((tile) => tile.dataset.local !== "true");

        if (remoteTiles.length === 0) {
          const unassignedRemoteTiles = this.tileView
            .remoteTileElements()
            .filter((tile) => !tile.dataset.participantId);

          if (unassignedRemoteTiles.length === 1) {
            unassignedRemoteTiles[0].dataset.participantId = participantId;
            this._applyParticipantToTile(unassignedRemoteTiles[0], participantId);
          }
        }
      }

      for (const tile of el.querySelectorAll("[data-group-call-video-tile]")) {
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
        speakerBadge.title = activeSpeaker ? t("Speaking") : t("Not speaking");
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
  };
}
