import { t } from "../i18n.js";

/**
 * The participant registry for the conference.
 *
 * The hook keeps a map of the participants the server announces, keyed by id,
 * and normalizes each into a stable record (a display nickname, a status, a
 * media-state map, and the language flag drawn beside the name). This owns
 * that map and the normalization. It is pure data — no DOM, no connection — so
 * the defaults and the map lifecycle are testable without a call. The tile DOM
 * the hook drives off these records, and the quality/layout bookkeeping a
 * removal triggers, stay in the hook.
 */
export function createParticipantRegistry() {
  const byId = new Map();

  return {
    /**
     * Normalize a server participant and store it. Returns the stored record
     * (or null when it has no id). The returned object is the live one the map
     * holds, so a later in-place update (e.g. a screen-share media-state change)
     * is reflected without a re-upsert.
     * @param {object} participant
     * @returns {object|null}
     */
    upsert(participant) {
      if (!participant?.id) return null;

      const id = String(participant.id);
      // The language flag only comes with the LiveView's roster; a signalling
      // payload that leaves it out keeps the one already known.
      const flag = "flag" in participant ? participant.flag || null : byId.get(id)?.flag || null;
      const record = {
        id,
        nickname: participant.nickname || t("Remote"),
        status: participant.status || "connected",
        media_state: participant.media_state || participant.mediaState || {},
        flag,
      };
      byId.set(id, record);
      return record;
    },

    get(participantId) {
      return byId.get(String(participantId)) || null;
    },

    remove(participantId) {
      return byId.delete(String(participantId));
    },

    get size() {
      return byId.size;
    },

    clear() {
      byId.clear();
    },
  };
}
