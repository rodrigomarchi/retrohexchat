/**
 * Hex FreeCell's match, as pure functions of its state: what an action from
 * the table does (`act`), what a tick does (`step`), and the score it ends on.
 *
 * The state is `{ phase, table, score, clock, events, won, stuck, autoTicks }`:
 * the table is `rules.js`'s, `clock` is the card table's (`core/card_table/clock.js`),
 * and `events` gathers the `EVENT` bits of the tick. In play, a card no
 * other card can still want goes up by itself, one every `AUTO_TICKS`; once
 * every column runs down, the rest go up the same way.
 *
 * @module games/hex_freecell/physics
 */

import {
  addPoints,
  scoreWithBonus,
  startClock,
  tickMatch,
  untilTimeUp,
} from "../core/card_table/clock.js";
import { PHASE, ending } from "../core/card_table/phases.js";
import { AUTO_TICKS, EVENT, GEOMETRY } from "./protocol.js";
import {
  applyMove,
  autoFinishReady,
  deal,
  hasMove,
  nextAutoMove,
  nextSafeMove,
  won,
} from "./rules.js";
import { scoreMove } from "./scoring.js";

/** A new match: the table dealt, on the table it is laid on, nothing scored, the clock stopped. */
export function createInitialState(random, geometry = GEOMETRY.LANDSCAPE) {
  return {
    phase: PHASE.WAITING,
    table: { ...deal(random), geometry },
    score: 0,
    clock: { started: false, ticks: 0 },
    events: EVENT.DEAL,
    won: false,
    stuck: false,
    autoTicks: 0,
  };
}

/** A move played: its points, its events, and the end it may bring. */
function played(state, move) {
  const table = applyMove(state.table, move);
  if (!table) return state;
  const next = {
    ...state,
    table,
    score: addPoints(state.score, scoreMove(move)),
    events: state.events | (move.to.pile === "foundation" ? EVENT.FOUNDATION : EVENT.PLACE),
  };
  return ending(next, {
    won: won(table),
    // Every column running down, and a card to start the climb with.
    finish: state.phase === PHASE.PLAYING && autoFinishReady(table) && Boolean(nextAutoMove(table)),
    stuck: !hasMove(table),
  });
}

/** What an action from the table (`gestures.js`) does. A move starts the clock. */
export function act(state, action) {
  switch (action.type) {
    case "move": {
      const next = played(state, action.move);
      return next === state ? state : { ...next, clock: startClock(next.clock), autoTicks: 0 };
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
 * One tick: the clock and what it costs, and every `AUTO_TICKS` a card going
 * up by itself — a safe one in play, the lowest one while finishing. The
 * clock counts only play: the cards going up at the end cost no time. While
 * the player holds cards (`holding`), nothing goes up from under their hand.
 */
export function step(state, { holding = false } = {}) {
  const ticked = tickMatch(state);
  const { timeUp } = ticked;
  const autoTicks = state.autoTicks + 1;
  let next = { ...ticked.next, autoTicks };
  if (autoTicks % AUTO_TICKS === 0 && state.clock.started && !holding) {
    const move =
      next.phase === PHASE.AUTO_FINISH
        ? nextAutoMove(next.table)
        : next.phase === PHASE.PLAYING && nextSafeMove(next.table);
    if (move) next = played(next, move);
  }
  return untilTimeUp(next, timeUp);
}

/** The score the match ends on: a win adds the bonus of its time. */
export const finalScore = scoreWithBonus;
