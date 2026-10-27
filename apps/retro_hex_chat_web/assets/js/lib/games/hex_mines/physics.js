/**
 * Hex Mines' match, as pure functions of its state: what an action from the
 * board does (`act`), what a tick does (`step`), and the score it ends on.
 *
 * The state is `{ phase, board, score, clock, events, won, lost, mode, opened }`: the
 * board is `rules.js`'s, `clock` the solo match's (`core/solo/clock.js`),
 * `mode` what a plain tap does on a phone (`"dig"` or `"flag"`), and `events`
 * gathers the `EVENT` bits of the tick and `opened` the squares it opened (with
 * their ring out from the first, for the wave drawn). A win or a mine going off is shown
 * (`CELEBRATING`) before the match is over.
 *
 * @module games/hex_mines/physics
 */

import { startClock, tickMatch, untilTimeUp } from "../core/solo/clock.js";
import { PHASE, ending } from "../core/solo/phases.js";
import { EVENT } from "./protocol.js";
import { CELL, chord, createBoard, flagAll, open, toggleFlag, won } from "./rules.js";
import { winPoints } from "./scoring.js";

/** A new match on a level's board, nothing opened, the clock stopped. */
export const createInitialState = (level) => ({
  phase: PHASE.WAITING,
  board: createBoard(level),
  score: 0,
  clock: { started: false, ticks: 0 },
  events: 0,
  won: false,
  lost: false,
  mode: "dig",
  opened: [],
});

/** Squares opened (by a press or a chord): the clock starts, and a mine or the last square ends it. */
function opened(state, result) {
  if (result.board === state.board) return state;
  const event = result.boom ? EVENT.BOOM : result.opened.length > 1 ? EVENT.FLOOD : EVENT.OPEN;
  const next = {
    ...state,
    board: result.board,
    clock: startClock(state.clock),
    events: state.events | event,
    opened: result.opened,
  };
  if (result.boom) return { ...next, phase: PHASE.CELEBRATING, lost: true };
  return won(next.board) ? ending({ ...next, board: flagAll(next.board) }, { won: true }) : next;
}

/**
 * What an action from the board (`gestures.js`) does: `open`, `chord` and
 * `flag` a square `i`, or switch the `mode`. The mines are laid from
 * `random` at the first square opened.
 */
export function act(state, action, random) {
  switch (action.type) {
    case "open":
      return opened(state, open(state.board, action.i, random));
    case "chord":
      return opened(state, chord(state.board, action.i));
    case "flag": {
      const board = toggleFlag(state.board, action.i);
      if (board === state.board) return state;
      const event = board.cell[action.i] === CELL.FLAG ? EVENT.FLAG : EVENT.UNFLAG;
      return { ...state, board, events: state.events | event };
    }
    case "mode":
      return { ...state, mode: state.mode === "dig" ? "flag" : "dig" };
    default:
      return state;
  }
}

/** One tick: the clock, which costs nothing, and the hour that calls time. */
export function step(state) {
  const { next, timeUp } = tickMatch(state, 0);
  return untilTimeUp({ ...next, opened: [] }, timeUp);
}

/** The score the match ends on: a win's, by its time; nothing otherwise. */
export const finalScore = (state) => (state.won ? winPoints(state.clock.ticks) : 0);
