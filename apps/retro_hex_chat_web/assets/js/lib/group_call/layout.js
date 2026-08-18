/**
 * Conference video-tile layout decisions — pure, over tile descriptors.
 *
 * The hook reads the tiles out of the DOM and applies the result (focused and
 * pinned classes, host dataset); which tile is focused, whether a tile is
 * visible and whether it is pinned are decided here against plain descriptors,
 * so the focus-resolution order can be tested without a grid.
 *
 * @module group_call/layout
 */

const FOCUS_MODES = ["focus", "sidebar", "speaker"];

/**
 * Whether a tile is shown. Remote tiles always are; the local tile follows the
 * self-view setting.
 *
 * @param {boolean} isLocal
 * @param {string} selfView
 * @returns {boolean}
 */
export function tileIsVisible(isLocal, selfView) {
  if (!isLocal) return true;
  return selfView !== "hidden";
}

/**
 * The index of the focused tile among `tiles`, or -1 when none is focused.
 *
 * The order mirrors the conference: in speaker mode the active speaker wins,
 * then an explicitly focused participant, then a focused stream, then the first
 * remote tile, then the first tile at all.
 *
 * @param {object} state
 * @param {string} state.mode
 * @param {string|null} [state.activeSpeakerId]
 * @param {string|null} [state.focusedParticipantId]
 * @param {string|null} [state.focusedStreamId]
 * @param {Array<{participantId?: string, streamId?: string, isLocal: boolean}>} tiles
 * @returns {number}
 */
export function focusedTileIndex(
  { mode, activeSpeakerId, focusedParticipantId, focusedStreamId },
  tiles,
) {
  if (!FOCUS_MODES.includes(mode)) return -1;

  if (mode === "speaker" && activeSpeakerId) {
    const index = tiles.findIndex((tile) => tile.participantId === activeSpeakerId);
    if (index >= 0) return index;
  }

  if (focusedParticipantId) {
    const index = tiles.findIndex((tile) => tile.participantId === focusedParticipantId);
    if (index >= 0) return index;
  }

  if (focusedStreamId) {
    const index = tiles.findIndex((tile) => tile.streamId === focusedStreamId);
    if (index >= 0) return index;
  }

  const remote = tiles.findIndex((tile) => !tile.isLocal);
  if (remote >= 0) return remote;

  return tiles.length > 0 ? 0 : -1;
}

/**
 * Whether a participant's tile is pinned.
 *
 * @param {string|null} participantId
 * @param {string[]} pinnedIds
 * @returns {boolean}
 */
export function isTilePinned(participantId, pinnedIds) {
  return !!participantId && pinnedIds.includes(participantId);
}
