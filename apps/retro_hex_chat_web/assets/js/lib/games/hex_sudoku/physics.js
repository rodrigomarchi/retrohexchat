/**
 * Hex Sudoku's match, as pure functions of its state: what an action does
 * (`act`), what a tick does (`step`), and the score it ends on.
 *
 * The state is `{ phase, board, score, clock, events, won, selected, pencil,
 * mistakes, hints, history, changed }`: the board is `rules.js`'s, null until
 * the grid is made; `clock` the solo match's (`core/solo/clock.js`), its ticks
 * with what the mistakes and the hints added; `selected` the chosen square or
 * null; `pencil` whether a digit goes in as a note; `history` the boards an
 * undo goes back to; `changed` what the last action did to which square
 * (`{ i, units }`, the units it completed), for the effects; `events` the
 * tick's `EVENT` bits. A win is shown (`CELEBRATING`) before the match is over.
 *
 * @module games/hex_sudoku/physics
 */

import { startClock, tickMatch, untilTimeUp } from "../core/solo/clock.js";
import { PHASE, ending } from "../core/solo/phases.js";
import { EVENT, PENALTY, SAFETY_TICKS, UNDO_DEPTH } from "./protocol.js";
import {
  completedUnits,
  createBoard,
  erase,
  hintSquare,
  keepHints,
  place,
  reveal,
  toggleNote,
  won,
} from "./rules.js";
import { winPoints } from "./scoring.js";

/** A new match: no grid yet, nothing chosen, the clock stopped. */
export const createInitialState = () => ({
  phase: PHASE.WAITING,
  board: null,
  score: 0,
  clock: { started: false, ticks: 0 },
  events: 0,
  won: false,
  selected: null,
  pencil: false,
  mistakes: 0,
  hints: 0,
  history: [],
  changed: null,
});

/** The clock with `ticks` more on it. */
const added = (clock, ticks) => ({ ...clock, ticks: clock.ticks + ticks });

/**
 * A new board in play: what changed on square `i`, the units it completed,
 * and the win when it is the last. `history` says whether an undo can go back
 * to the board before.
 */
function changed(state, board, i, { event, history = true }) {
  const units = board.values[i] === board.solution[i] ? completedUnits(board, i) : [];
  const next = {
    ...state,
    board,
    history: history ? [...state.history, state.board].slice(-UNDO_DEPTH) : state.history,
    events: state.events | event | (units.length ? EVENT.COMPLETE : 0),
    changed: { i, units },
  };
  return won(board) ? ending({ ...next, selected: null }, { won: true }) : next;
}

/** A digit from the keypad or the keyboard: a note while the pencil is on, else the square's digit. */
function digit(state, d) {
  const { board, selected: i } = state;
  if (i === null) return state;
  if (state.pencil) {
    const noted = toggleNote(board, i, d);
    return noted === board ? state : changed(state, noted, i, { event: EVENT.NOTE });
  }
  const placed = place(board, i, d);
  if (placed.board === board) return state;
  if (!placed.wrong) return changed(state, placed.board, i, { event: EVENT.PLACE });
  return {
    ...changed(state, placed.board, i, { event: EVENT.MISTAKE }),
    mistakes: state.mistakes + 1,
    clock: added(state.clock, PENALTY.MISTAKE),
  };
}

/** A hint: a square revealed for good, chosen, and a minute on the clock. */
function hint(state, random) {
  const i = hintSquare(state.board, state.selected, random);
  if (i === null) return state;
  const next = changed(state, reveal(state.board, i), i, { event: EVENT.HINT, history: false });
  return {
    ...next,
    selected: next.phase === PHASE.PLAYING ? i : null,
    hints: state.hints + 1,
    clock: added(state.clock, PENALTY.HINT),
  };
}

/** The chosen square moved by `dx`, `dy`, kept on the grid; the centre when none was chosen. */
function moved(selected, dx, dy) {
  if (selected === null) return 40;
  const col = Math.min(8, Math.max(0, (selected % 9) + dx));
  const row = Math.min(8, Math.max(0, Math.floor(selected / 9) + dy));
  return row * 9 + col;
}

/** What an action other than the grid's arrival does, the clock started by it. */
function play(state, action, random) {
  switch (action.type) {
    case "select":
      return { ...state, selected: action.i };
    case "move":
      return { ...state, selected: moved(state.selected, action.dx, action.dy) };
    case "digit":
      return digit(state, action.d);
    case "erase": {
      if (state.selected === null) return state;
      const board = erase(state.board, state.selected);
      return board === state.board
        ? state
        : changed(state, board, state.selected, { event: EVENT.ERASE });
    }
    case "pencil":
      return { ...state, pencil: !state.pencil, events: state.events | EVENT.PENCIL };
    case "hint":
      return hint(state, random);
    case "undo": {
      const before = state.history.at(-1);
      if (!before) return state;
      return {
        ...state,
        board: keepHints(before, state.board),
        history: state.history.slice(0, -1),
        events: state.events | EVENT.UNDO,
        changed: null,
      };
    }
    default:
      return state;
  }
}

/**
 * What an action does: `grid` brings the grid (`generator.js`'s), and once it
 * is here, `select` (a square `i`), `move` (`dx`, `dy`), `digit` (`d`),
 * `erase`, `pencil`, `hint` and `undo` play on it. Any of those starts the
 * clock; a hint with no square chosen draws one from `random`.
 */
export function act(state, action, random) {
  if (action.type === "grid") {
    return state.board ? state : { ...state, board: createBoard(action.grid) };
  }
  if (!state.board || state.phase !== PHASE.PLAYING) return state;
  const next = play(state, action, random);
  return next === state ? state : { ...next, clock: startClock(next.clock) };
}

/** One tick: the clock, which costs nothing, and the three hours that call time. */
export function step(state) {
  const { next, timeUp } = tickMatch(state, 0, SAFETY_TICKS);
  return untilTimeUp({ ...next, changed: null }, timeUp);
}

/** The score the match ends on: a win's, by its time; nothing otherwise. */
export const finalScore = (state) => (state.won ? winPoints(state.clock.ticks) : 0);
