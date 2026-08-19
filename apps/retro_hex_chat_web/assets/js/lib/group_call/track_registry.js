import { stringOrNull } from "./payload.js";

/**
 * The remote-track registry for the conference.
 *
 * The hook keeps three indexes over the tracks the server announces — by track
 * id, by media-stream id, and by browser (WebRTC) track id — so a stream or an
 * `ontrack` event can be resolved back to the participant it belongs to. This
 * owns those three maps and the normalization that fills them. It is pure data:
 * no DOM, no connection, so the field normalization and the tile-attach lookup
 * precedence are testable without a call. The tile DOM stays in the hook.
 */
export function createTrackRegistry() {
  const byId = new Map();
  const byStreamId = new Map();
  const byWebrtcTrackId = new Map();

  return {
    /**
     * Normalize a server track and index it under every id it carries.
     * @param {object} track raw server track
     * @returns {object|null} the normalized record, or null when it has no id
     */
    upsert(track) {
      if (!track?.id) return null;

      const normalized = {
        id: String(track.id),
        participantId: stringOrNull(track.participant_id ?? track.participantId),
        kind: track.kind,
        source: track.source || "camera",
        status: track.status,
        streamId: stringOrNull(track.stream_id ?? track.streamId),
        webrtcTrackId: stringOrNull(track.webrtc_track_id ?? track.webrtcTrackId),
      };

      byId.set(normalized.id, normalized);
      if (normalized.streamId) byStreamId.set(normalized.streamId, normalized);
      if (normalized.webrtcTrackId) byWebrtcTrackId.set(normalized.webrtcTrackId, normalized);

      return normalized;
    },

    /**
     * Drop a track from every index.
     * @param {string|number} trackId
     * @returns {object|null} the removed record, or null when unknown
     */
    remove(trackId) {
      if (trackId === undefined || trackId === null) return null;

      const key = String(trackId);
      const track = byId.get(key);
      byId.delete(key);
      if (!track) return null;

      if (track.streamId) byStreamId.delete(track.streamId);
      if (track.webrtcTrackId) byWebrtcTrackId.delete(track.webrtcTrackId);

      return track;
    },

    /**
     * The tile-attach lookup: prefer the media-stream id, fall back to the
     * browser track id.
     * @param {string} streamId
     * @param {string} [browserTrackId]
     * @returns {object|null}
     */
    forTile(streamId, browserTrackId) {
      return byStreamId.get(streamId) || byWebrtcTrackId.get(browserTrackId) || null;
    },

    byWebrtcTrackId(webrtcTrackId) {
      return byWebrtcTrackId.get(webrtcTrackId) || null;
    },

    get size() {
      return byId.size;
    },

    clear() {
      byId.clear();
      byStreamId.clear();
      byWebrtcTrackId.clear();
    },
  };
}
