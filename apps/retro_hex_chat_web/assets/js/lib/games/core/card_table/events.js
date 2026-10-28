/**
 * What happened in a tick on a card table, one bit each: the sounds (each the
 * event's name, `card_table/sounds.js`) and the effects read them. A game
 * raises the ones its table has.
 *
 * @module games/core/card_table/events
 */

import { WIN_EVENT } from "../solo/phases.js";

export const EVENT = Object.freeze({
  DEAL: 1,
  DRAW: 2,
  FLIP: 4,
  PLACE: 8,
  FOUNDATION: 16,
  REFUSE: 32,
  RECYCLE: 64,
  RETURN: 128,
  WIN: WIN_EVENT,
});

/**
 * What the table's gestures say without moving a card: a card refused or a
 * drag put back is only its event (the shake, the sound). Any other action
 * leaves the match as it was.
 */
export function feedback(state, action) {
  if (action.type === "refuse") return { ...state, events: state.events | EVENT.REFUSE };
  if (action.type === "return") return { ...state, events: state.events | EVENT.RETURN };
  return state;
}
