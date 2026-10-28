/**
 * Hex Blocks' match, as pure functions of its state: what a press does
 * (`act`), what a tick does (`step`), and the score it ends on.
 *
 * The state is `{ phase, mode, well, piece, queue, held, canHold, score,
 * clock, events, won, level, lines, combo, cleared, countdown, fall, lock,
 * resets, inputs, repeat }`: `mode` the catalogue id's (`MODE`); `well` and
 * `piece` are `rules.js`'s, the piece null during the count; `queue` the
 * kinds coming; `held` the kind put aside, `canHold` whether this piece may
 * be; `clock` the solo match's (`core/solo/clock.js`), from the first piece;
 * `combo` the clears in a row (-1 after a piece that cleared none);
 * `cleared` the rows the last lock cleared, for the effects; `countdown` the
 * ticks left before the first piece; `fall` the ticks since the piece last
 * fell, `lock` the ticks it has rested, `resets` the moves that put its lock
 * off; `inputs` the moves held down (left, right, down) and `repeat` the
 * sideways one repeating (`dir`, `ticks` held). `events` are the tick's
 * `EVENT` bits. The end is shown (`CELEBRATING`) before the match is over.
 *
 * @module games/hex_blocks/physics
 */

import { startClock, tickMatch, untilTimeUp } from "../core/solo/clock.js";
import { PHASE, ending } from "../core/solo/phases.js";
import { fillQueue } from "./pieces.js";
import {
  COUNTDOWN_TICKS,
  DROP_POINTS,
  EVENT,
  LEVELS,
  LOCK,
  PREVIEW,
  REPEAT,
  SAFETY_TICKS,
  SOFT_FACTOR,
  fallTicks,
} from "./protocol.js";
import {
  clearLines,
  createWell,
  fall,
  fits,
  hold,
  landing,
  lock,
  rotate,
  shift,
  spawn,
  toppedOut,
} from "./rules.js";
import { clearPoints, sprintPoints } from "./scoring.js";

const RESTED = { fall: 0, lock: 0, resets: 0 };

/** A new match in `mode`: an empty well, the queue dealt from `random`, the count to come. */
export const createInitialState = (mode, random) => ({
  phase: PHASE.WAITING,
  mode,
  well: createWell(),
  piece: null,
  queue: fillQueue([], random, PREVIEW + 1),
  held: null,
  canHold: true,
  score: 0,
  clock: { started: false, ticks: 0 },
  events: 0,
  won: false,
  level: 1,
  lines: 0,
  combo: -1,
  cleared: [],
  countdown: COUNTDOWN_TICKS,
  ...RESTED,
  inputs: { left: false, right: false, down: false },
  repeat: { dir: 0, ticks: 0 },
});

/** Points the Marathon earns; the Sprint is scored by its time only. */
const earned = (state, points) => (state.mode.sprint ? state.score : state.score + points);

/** The end of a match that cannot go on: shown, then over, with the points it has. */
const over = (state) => ({ ...state, phase: PHASE.CELEBRATING, events: state.events | EVENT.OVER });

/** The next piece from the queue at the top, or the end when it does not fit. */
function next(state, random) {
  const piece = spawn(state.queue[0]);
  const queue = fillQueue(state.queue.slice(1), random, PREVIEW + 1);
  const brought = { ...state, piece, queue, canHold: true, ...RESTED };
  return fits(state.well, piece) ? brought : over(brought);
}

/** The piece set in the well: its rows cleared and counted, the level, and the next piece or the end. */
function settle(state, piece, random) {
  const locked = { ...state, well: lock(state.well, piece), events: state.events | EVENT.LOCK };
  if (toppedOut(piece)) return over({ ...locked, piece: null });
  const { well, lines: rows } = clearLines(locked.well);
  const n = rows.length;
  const combo = n ? state.combo + 1 : -1;
  const lines = state.lines + n;
  const level = state.mode.sprint
    ? 1
    : Math.min(LEVELS.MAX, Math.max(state.level, 1 + Math.floor(lines / LEVELS.LINES_PER)));
  const cleared = {
    ...locked,
    well,
    lines,
    level,
    combo,
    cleared: rows,
    score: earned(state, clearPoints(n, state.level, combo)),
    events:
      locked.events |
      (n ? EVENT.LINE : 0) |
      (n === 4 ? EVENT.QUAD : 0) |
      (level > state.level ? EVENT.LEVEL : 0),
  };
  if (state.mode.sprint && lines >= state.mode.goal) {
    return ending({ ...cleared, piece: null }, { won: true });
  }
  return next(cleared, random);
}

/** The piece moved to `moved` (or kept, when null): at rest, a move puts its lock off, so many times. */
function moved(state, piece, event) {
  if (!piece) return state;
  const resting = state.lock > 0 && state.resets < LOCK.RESETS;
  return {
    ...state,
    piece,
    events: state.events | event,
    ...(resting ? { lock: 0, resets: state.resets + 1 } : {}),
  };
}

const SIDE = { left: -1, right: 1 };

function press(state, input) {
  const inputs = { ...state.inputs, [input]: true };
  if (input === "down") return { ...state, inputs };
  const dir = SIDE[input];
  const repeating = { ...state, inputs, repeat: { dir, ticks: 0 } };
  return state.piece
    ? moved(repeating, shift(state.well, state.piece, dir), EVENT.MOVE)
    : repeating;
}

function release(state, input) {
  const inputs = { ...state.inputs, [input]: false };
  if (input === "down" || SIDE[input] !== state.repeat.dir) return { ...state, inputs };
  // The other way, still held, repeats from now.
  const other = input === "left" ? "right" : "left";
  return { ...state, inputs, repeat: { dir: inputs[other] ? SIDE[other] : 0, ticks: 0 } };
}

/**
 * What a press does: `press` and `release` a held move (`input` left, right
 * or down); `turn` (`dir` 1 clockwise, -1 the other way); `drop`, to the
 * bottom and locked at once; `hold`, the piece put aside. During the count
 * only the held moves are kept, nothing played.
 */
export function act(state, action, random) {
  if (state.phase !== PHASE.PLAYING) return state;
  if (action.type === "press") return press(state, action.input);
  if (action.type === "release") return release(state, action.input);
  if (!state.piece) return state;
  switch (action.type) {
    case "turn":
      return moved(state, rotate(state.well, state.piece, action.dir), EVENT.TURN);
    case "drop": {
      const landed = landing(state.well, state.piece);
      const rows = landed.r - state.piece.r;
      const dropped = {
        ...state,
        score: earned(state, rows * DROP_POINTS.HARD),
        events: state.events | EVENT.DROP,
      };
      return settle(dropped, landed, random);
    }
    case "hold": {
      const dealt = hold(state);
      if (dealt === state) return state;
      const held = {
        ...dealt,
        queue: fillQueue(dealt.queue, random, PREVIEW + 1),
        events: state.events | EVENT.HOLD,
        ...RESTED,
      };
      return fits(held.well, held.piece) ? held : over(held);
    }
    default:
      return state;
  }
}

/** The count: a beep each second, then the first piece and the clock. */
function counted(state, random) {
  const beep = state.countdown % 60 === 0 ? EVENT.COUNT : 0;
  const countdown = state.countdown - 1;
  const ticking = { ...state, countdown, events: state.events | beep };
  if (countdown > 0) return ticking;
  const first = next({ ...ticking, events: ticking.events | EVENT.GO }, random);
  return { ...first, clock: startClock(first.clock) };
}

/** A sideways move held down: once the delay is past, a step every so often. */
function repeated(state) {
  const { dir, ticks } = state.repeat;
  if (dir === 0) return state;
  const held = { ...state, repeat: { dir, ticks: ticks + 1 } };
  const due = ticks + 1 >= REPEAT.DELAY && (ticks + 1 - REPEAT.DELAY) % REPEAT.EVERY === 0;
  return due ? moved(held, shift(state.well, state.piece, dir), EVENT.MOVE) : held;
}

/** Gravity, faster held down; a piece at rest locks once it has rested long enough. */
function fell(state, random) {
  const soft = state.inputs.down;
  const every = soft
    ? Math.max(1, Math.round(fallTicks(state.level) / SOFT_FACTOR))
    : fallTicks(state.level);
  const ticks = state.fall + 1;
  if (ticks >= every) {
    const down = fall(state.well, state.piece);
    if (down) {
      const score = soft ? earned(state, DROP_POINTS.SOFT) : state.score;
      return { ...state, piece: down, fall: 0, lock: 0, score };
    }
  }
  const resting = !fall(state.well, state.piece);
  if (!resting) return { ...state, fall: Math.min(ticks, every) };
  const lockTicks = state.lock + 1;
  if (lockTicks >= LOCK.TICKS) return settle(state, state.piece, random);
  return { ...state, fall: Math.min(ticks, every), lock: lockTicks };
}

/** One tick: the clock, the count, the move held, gravity and the lock; three hours call time. */
export function step(state, random) {
  const { next: ticked, timeUp } = tickMatch(state, 0, SAFETY_TICKS);
  let s = { ...ticked, cleared: [] };
  if (s.phase === PHASE.PLAYING) {
    if (!s.piece) s = counted(s, random);
    else {
      s = repeated(s);
      s = fell(s, random);
    }
  }
  return untilTimeUp(s, timeUp);
}

/** The score the match ends on: the Marathon's points; a Sprint won, by its time, else nothing. */
export const finalScore = (state) => {
  if (!state.mode.sprint) return state.score;
  return state.won ? sprintPoints(state.clock.ticks) : 0;
};
