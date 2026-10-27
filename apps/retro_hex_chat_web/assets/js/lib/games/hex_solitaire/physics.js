/**
 * Hex Solitaire's match, as pure functions of its state: what an action from
 * the table does (`act`), what a tick does (`step`), and the score it ends on.
 *
 * The state is `{ phase, table, score, clock, events, won, autoTicks }`: the
 * table is `rules.js`'s, `clock` is `scoring.js`'s, and `events` gathers the
 * `EVENT` bits of the tick, which the sounds and the effects read and `step`
 * clears.
 *
 * @module games/hex_solitaire/physics
 */

import { AUTO_TICKS, EVENT, PHASE } from "./protocol.js";
import { applyMove, autoFinishReady, deal, draw, nextAutoMove, recycle, won } from "./rules.js";
import {
  addPoints,
  recyclePoints,
  scoreMove,
  startClock,
  tickClock,
  timeBonus,
} from "./scoring.js";

/** A new match: the table dealt, nothing scored, the clock stopped. */
export function createInitialState(random, mode) {
  return {
    phase: PHASE.WAITING,
    table: deal(random, mode),
    score: 0,
    clock: { started: false, ticks: 0 },
    events: EVENT.DEAL,
    won: false,
    autoTicks: 0,
  };
}

/** A move played: its points, its events, and the end it may bring. */
function played(state, move) {
  const result = applyMove(state.table, move);
  if (!result) return state;
  const events =
    (move.to.pile === "foundation" ? EVENT.FOUNDATION : EVENT.PLACE) |
    (result.flipped ? EVENT.FLIP : 0);
  const next = {
    ...state,
    table: result.state,
    score: addPoints(state.score, scoreMove(move, result.flipped)),
    events: state.events | events,
  };
  if (won(next.table)) {
    return { ...next, phase: PHASE.CELEBRATING, won: true, events: next.events | EVENT.WIN };
  }
  if (state.phase === PHASE.PLAYING && autoFinishReady(next.table)) {
    return { ...next, phase: PHASE.AUTO_FINISH, autoTicks: 0 };
  }
  return next;
}

/**
 * What an action from the table (`gestures.js`) does. A draw, a recycle or a
 * move starts the clock; a refusal and a card going back only say so.
 */
export function act(state, action) {
  switch (action.type) {
    case "draw": {
      const table = draw(state.table);
      if (!table) return state;
      return { ...state, table, clock: startClock(state.clock), events: state.events | EVENT.DRAW };
    }
    case "recycle": {
      const table = recycle(state.table);
      if (!table) return state;
      return {
        ...state,
        table,
        clock: startClock(state.clock),
        score: addPoints(state.score, recyclePoints(state.table.mode)),
        events: state.events | EVENT.RECYCLE,
      };
    }
    case "move": {
      const next = played(state, action.move);
      return next === state ? state : { ...next, clock: startClock(next.clock) };
    }
    case "refuse":
      return { ...state, events: state.events | EVENT.REFUSE };
    case "return":
      return { ...state, events: state.events | EVENT.RETURN };
    default:
      return state;
  }
}

/**
 * One tick: the clock and what it costs, and while finishing, the next card
 * up. The clock counts only play: the cards going up by themselves cost no time.
 */
export function step(state) {
  const ticked =
    state.phase === PHASE.PLAYING
      ? tickClock(state.clock)
      : { clock: state.clock, points: 0, timeUp: false };
  let next = {
    ...state,
    clock: ticked.clock,
    score: addPoints(state.score, ticked.points),
    events: 0,
  };
  if (next.phase === PHASE.AUTO_FINISH) {
    const autoTicks = next.autoTicks + 1;
    next = { ...next, autoTicks };
    if (autoTicks % AUTO_TICKS === 0) {
      const move = nextAutoMove(next.table);
      if (move) next = played(next, move);
    }
  }
  if (next.phase !== PHASE.FINISHED && ticked.timeUp) return { ...next, phase: PHASE.FINISHED };
  return next;
}

/** The score the match ends on: a win adds the bonus of its time. */
export const finalScore = (state) =>
  state.won ? state.score + timeBonus(state.clock.ticks) : state.score;
