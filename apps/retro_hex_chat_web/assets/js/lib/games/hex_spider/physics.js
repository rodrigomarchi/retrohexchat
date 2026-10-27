/**
 * Hex Spider's match, as pure functions of its state: what an action from the
 * table does (`act`), what a tick does (`step`), and the score it ends on.
 *
 * The state is `{ phase, table, score, clock, events, won, stuck }`: the
 * table is `rules.js`'s, `clock` is the card table's (`core/card_table/clock.js`),
 * and `events` gathers the `EVENT` bits of the tick. Points are Windows':
 * 500 to start, one a move, a hundred a suit; time costs nothing.
 *
 * @module games/hex_spider/physics
 */

import { addPoints, startClock, tickClock } from "../core/card_table/clock.js";
import { PHASE } from "../core/card_table/table.js";
import { EVENT, GEOMETRY, POINTS } from "./protocol.js";
import { applyMove, deal, dealRow, hasMove, won } from "./rules.js";

/** A new match: the table dealt for its variant, on the table it is laid on, the clock stopped. */
export function createInitialState(random, suits, geometry = GEOMETRY.LANDSCAPE) {
  return {
    phase: PHASE.WAITING,
    table: { ...deal(random, suits), geometry },
    score: POINTS.START,
    clock: { started: false, ticks: 0 },
    events: EVENT.DEAL,
    won: false,
    stuck: false,
  };
}

/** A move or a deal played: its point, its suit, its events, and the end it may bring. */
function played(state, result, event) {
  if (!result) return state;
  const next = {
    ...state,
    table: result.state,
    clock: startClock(state.clock),
    score: addPoints(state.score, POINTS.MOVE + (result.completed ? POINTS.COMPLETE : 0)),
    events:
      state.events |
      event |
      (result.flipped ? EVENT.FLIP : 0) |
      (result.completed ? EVENT.FOUNDATION : 0),
  };
  if (won(next.table)) {
    return { ...next, phase: PHASE.CELEBRATING, won: true, events: next.events | EVENT.WIN };
  }
  if (!hasMove(next.table)) return { ...next, phase: PHASE.FINISHED, stuck: true };
  return next;
}

/** What an action from the table (`gestures.js`) does. */
export function act(state, action) {
  switch (action.type) {
    case "move":
      return played(state, applyMove(state.table, action.move), EVENT.PLACE);
    case "deal":
      return played(state, dealRow(state.table), EVENT.DEAL);
    case "refuse":
      return { ...state, events: state.events | EVENT.REFUSE };
    case "return":
      return { ...state, events: state.events | EVENT.RETURN };
    default:
      return state;
  }
}

/** One tick: the clock, which costs nothing, and the hour that calls time. */
export function step(state) {
  const ticked =
    state.phase === PHASE.PLAYING
      ? tickClock(state.clock, 0)
      : { clock: state.clock, timeUp: false };
  const next = { ...state, clock: ticked.clock, events: 0 };
  if (next.phase !== PHASE.FINISHED && ticked.timeUp) return { ...next, phase: PHASE.FINISHED };
  return next;
}

/** The score the match ends on. */
export const finalScore = (state) => state.score;
