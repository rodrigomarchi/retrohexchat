import { describe, expect, it } from "vitest";
import { PHASE } from "../../../../js/lib/games/core/solo/phases.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import {
  act,
  createInitialState,
  finalScore,
  step,
} from "../../../../js/lib/games/hex_blocks/physics.js";
import {
  COLS,
  COUNTDOWN_TICKS,
  EVENT,
  LOCK,
  MODE,
  PREVIEW,
  REPEAT,
  ROWS,
  SAFETY_TICKS,
  fallTicks,
} from "../../../../js/lib/games/hex_blocks/protocol.js";
import {
  cellsOf,
  fall,
  filled,
  landing,
  spawn,
} from "../../../../js/lib/games/hex_blocks/rules.js";
import { sprintPoints } from "../../../../js/lib/games/hex_blocks/scoring.js";

const random = () => createRng(3).fork("bag").next;
/** A new match as the flow begins it: in play. */
const begun = (mode, r) => ({ ...createInitialState(mode, r), phase: PHASE.PLAYING });

/** A match `mode`, its count over: the first piece in the well. */
function started(mode = MODE.hex_blocks) {
  const r = random();
  let state = begun(mode, r);
  for (let i = 0; i < COUNTDOWN_TICKS; i++) state = step(state, r);
  return { state, r };
}
const run = (state, r, ticks) => {
  let s = state;
  for (let i = 0; i < ticks; i++) s = step(s, r);
  return s;
};
const rowOf = (piece) => piece.r;
const colOf = (piece) => piece.c;
/** The well with every square of a zigzag row filled but the columns given. */
function fillRow(well, r, gaps) {
  const cells = [...well.cells];
  for (let c = 0; c < COLS; c++) if (!gaps.includes(c)) cells[r * COLS + c] = 1;
  return { ...well, cells };
}

describe("the start of a match", () => {
  it("counts three seconds down before the first piece comes in, the clock stopped", () => {
    const r = random();
    expect(createInitialState(MODE.hex_blocks, r).phase).toBe(PHASE.WAITING);
    let state = begun(MODE.hex_blocks, r);
    expect(state.piece).toBeNull();
    expect(state.queue.length).toBeGreaterThanOrEqual(PREVIEW + 1);
    state = step(state, r);
    expect(state.events & EVENT.COUNT).toBeTruthy();
    state = run(state, r, COUNTDOWN_TICKS - 2);
    expect(state.piece).toBeNull();
    expect(state.clock.started).toBe(false);
    state = step(state, r);
    expect(state.piece).not.toBeNull();
    expect(state.events & EVENT.GO).toBeTruthy();
    expect(state.clock.started).toBe(true);
    expect(state.queue.length).toBeGreaterThanOrEqual(PREVIEW);
  });

  it("deals the same pieces for the same seed", () => {
    const kinds = () => started().state.queue.slice(0, 6);
    expect(kinds()).toEqual(kinds());
  });

  it("plays nothing pressed during the count", () => {
    const r = random();
    const state = begun(MODE.hex_blocks, r);
    expect(act(state, { type: "drop" }, r)).toBe(state);
  });
});

describe("gravity", () => {
  it("brings a piece down a row each second at level 1", () => {
    const { state, r } = started();
    const top = rowOf(state.piece);
    expect(rowOf(run(state, r, fallTicks(1) - 1).piece)).toBe(top);
    expect(rowOf(run(state, r, fallTicks(1)).piece)).toBe(top + 1);
    expect(rowOf(run(state, r, 3 * fallTicks(1)).piece)).toBe(top + 3);
  });

  it("falls faster held down, a point a row", () => {
    const { state, r } = started();
    const pressed = act(state, { type: "press", input: "down" }, r);
    const later = run(pressed, r, 30);
    expect(rowOf(later.piece) - rowOf(state.piece)).toBeGreaterThanOrEqual(9);
    expect(later.score).toBe(rowOf(later.piece) - rowOf(state.piece));
    const released = act(later, { type: "release", input: "down" }, r);
    expect(rowOf(run(released, r, 10).piece)).toBe(rowOf(later.piece));
  });

  it("drops a piece to the floor at once, two points a row, and brings the next", () => {
    const { state, r } = started();
    const landed = landing(state.well, state.piece);
    const dropped = act(state, { type: "drop" }, r);
    expect(filled(dropped.well)).toBe(4);
    for (const [c, row] of cellsOf(landed)) expect(dropped.well.cells[row * COLS + c]).not.toBe(0);
    expect(dropped.score).toBe(2 * (landed.r - state.piece.r));
    expect(dropped.piece.kind).toBe(state.queue[0]);
    expect(dropped.events & EVENT.DROP).toBeTruthy();
  });
});

describe("moving held down", () => {
  it("steps once at the press, again after the delay, then quickly", () => {
    const { state, r } = started();
    const c0 = colOf(state.piece);
    let s = act(state, { type: "press", input: "left" }, r);
    expect(colOf(s.piece)).toBe(c0 - 1);
    s = run(s, r, REPEAT.DELAY - 1);
    expect(colOf(s.piece)).toBe(c0 - 1);
    s = run(s, r, 1);
    expect(colOf(s.piece)).toBe(c0 - 2);
    s = run(s, r, REPEAT.EVERY);
    expect(colOf(s.piece)).toBe(c0 - 3);
  });

  it("stops repeating on release, and the last direction pressed wins", () => {
    const { state, r } = started();
    const c0 = colOf(state.piece);
    let s = act(state, { type: "press", input: "left" }, r);
    s = act(s, { type: "press", input: "right" }, r);
    expect(colOf(s.piece)).toBe(c0);
    s = run(s, r, REPEAT.DELAY);
    expect(colOf(s.piece)).toBe(c0 + 1);
    s = act(s, { type: "release", input: "right" }, r);
    s = act(s, { type: "release", input: "left" }, r);
    const still = colOf(s.piece);
    expect(colOf(run(s, r, 20).piece)).toBe(still);
  });

  it("turns, and holds a piece once", () => {
    const { state, r } = started();
    const turned = act(state, { type: "turn", dir: 1 }, r);
    expect(turned.piece.turn).toBe(1);
    expect(turned.events & EVENT.TURN).toBeTruthy();
    const held = act(turned, { type: "hold" }, r);
    expect(held.held).toBe(state.piece.kind);
    expect(held.piece.kind).toBe(state.queue[0]);
    expect(act(held, { type: "hold" }, r).held).toBe(state.piece.kind);
    expect(act(held, { type: "hold" }, r)).toBe(held);
  });
});

describe("locking", () => {
  /** The piece resting on the floor. */
  const resting = () => {
    const { state, r } = started();
    return { state: { ...state, piece: landing(state.well, state.piece) }, r };
  };

  it("locks a piece half a second after it comes to rest", () => {
    const { state, r } = resting();
    expect(fall(state.well, state.piece)).toBeNull();
    expect(filled(run(state, r, LOCK.TICKS - 1).well)).toBe(0);
    const locked = run(state, r, LOCK.TICKS);
    expect(filled(locked.well)).toBe(4);
    expect(locked.events & EVENT.LOCK).toBeTruthy();
  });

  it("waits again after a move at rest, but only so many times", () => {
    const { state, r } = resting();
    let s = run(state, r, LOCK.TICKS - 2);
    s = act(s, { type: "turn", dir: 1 }, r);
    s = run(s, r, LOCK.TICKS - 2);
    expect(filled(s.well)).toBe(0);
    for (let i = 0; i < LOCK.RESETS; i++) {
      s = act(s, { type: "turn", dir: i % 2 ? 1 : -1 }, r);
      s = run(s, r, 2);
    }
    // Out of resets: a move no longer puts the lock off.
    expect(s.resets).toBe(LOCK.RESETS);
    s = run(s, r, LOCK.TICKS - 3);
    s = act(s, { type: "turn", dir: 1 }, r);
    expect(filled(run(s, r, 2).well)).toBe(4);
  });
});

describe("clearing rows", () => {
  it("clears a full row, scores it by the level, and counts it", () => {
    const { state, r } = started();
    const piece = landing(state.well, state.piece);
    const bottom = cellsOf(piece)
      .filter(([, row]) => row === ROWS - 1)
      .map(([c]) => c);
    const well = fillRow(state.well, ROWS - 1, bottom);
    const s = act({ ...state, well, level: 3 }, { type: "drop" }, r);
    expect(s.lines).toBe(1);
    expect(s.score).toBe(2 * (piece.r - state.piece.r) + 100 * 3);
    expect(s.events & EVENT.LINE).toBeTruthy();
    expect(s.cleared).toEqual([ROWS - 1]);
  });

  it("goes up a level every ten rows, and falls faster for it", () => {
    const { state, r } = started();
    const piece = landing(state.well, state.piece);
    const bottom = cellsOf(piece)
      .filter(([, row]) => row === ROWS - 1)
      .map(([c]) => c);
    const s = act(
      { ...state, well: fillRow(state.well, ROWS - 1, bottom), lines: 9 },
      { type: "drop" },
      r,
    );
    expect(s.level).toBe(2);
    expect(s.events & EVENT.LEVEL).toBeTruthy();
    expect(fallTicks(2)).toBeLessThan(fallTicks(1));
    expect(fallTicks(20)).toBe(3);
  });

  it("adds a bonus for a clear right after a clear", () => {
    const { state, r } = started();
    const clearing = (s) => {
      const piece = landing(s.well, s.piece);
      const bottom = cellsOf(piece)
        .filter(([, row]) => row === ROWS - 1)
        .map(([c]) => c);
      return act({ ...s, well: fillRow(s.well, ROWS - 1, bottom) }, { type: "drop" }, r);
    };
    const first = clearing(state);
    const second = clearing({ ...first, well: { cells: Array(COLS * ROWS).fill(0) } });
    const dropped = 2 * (landing(first.well, first.piece).r - first.piece.r);
    expect(second.score - first.score).toBe(dropped + 100 + 50);
    expect(second.combo).toBe(1);
  });
});

describe("the end", () => {
  it("is over when the next piece cannot come in: the Marathon keeps its points", () => {
    const { state, r } = started();
    const cells = [...state.well.cells];
    for (let row = 2; row < ROWS; row++) {
      for (let c = 0; c < COLS; c++) if (c !== 0) cells[row * COLS + c] = 1;
    }
    const s = act({ ...state, well: { cells }, score: 1234 }, { type: "drop" }, r);
    expect(s.phase).toBe(PHASE.CELEBRATING);
    expect(s.won).toBe(false);
    expect(s.events & EVENT.OVER).toBeTruthy();
    expect(finalScore(s)).toBe(1234);
  });

  it("wins the Sprint at forty rows, scored by its time", () => {
    const { state, r } = started(MODE.hex_blocks_sprint);
    const piece = landing(state.well, state.piece);
    const bottom = cellsOf(piece)
      .filter(([, row]) => row === ROWS - 1)
      .map(([c]) => c);
    const s = act(
      {
        ...state,
        well: fillRow(state.well, ROWS - 1, bottom),
        lines: 39,
        clock: { started: true, ticks: 3600 },
      },
      { type: "drop" },
      r,
    );
    expect(s.won).toBe(true);
    expect(s.phase).toBe(PHASE.CELEBRATING);
    expect(finalScore(s)).toBe(sprintPoints(3600));
  });

  it("scores a Sprint that tops out nothing, and keeps the Sprint at level 1", () => {
    const { state, r } = started(MODE.hex_blocks_sprint);
    expect(finalScore({ ...state, phase: PHASE.FINISHED, score: 500 })).toBe(0);
    const piece = landing(state.well, state.piece);
    const bottom = cellsOf(piece)
      .filter(([, row]) => row === ROWS - 1)
      .map(([c]) => c);
    const s = act(
      { ...state, well: fillRow(state.well, ROWS - 1, bottom), lines: 19 },
      { type: "drop" },
      r,
    );
    expect(s.level).toBe(1);
  });

  it("is over, and says so, when the next piece has no room to come in", () => {
    const { state, r } = started();
    const cells = [...state.well.cells];
    // The middle of the top rows filled: the piece locks low, the next cannot come in.
    for (let row = 0; row < 3; row++) for (let c = 3; c < 8; c++) cells[row * COLS + c] = 1;
    const s = act(
      { ...state, piece: { ...state.piece, c: 0, r: 10 }, well: { cells } },
      { type: "drop" },
      r,
    );
    expect(s.phase).toBe(PHASE.CELEBRATING);
    expect(s.over).toBe(true);
  });

  it("never scores more than the server takes", () => {
    const { state } = started();
    expect(finalScore({ ...state, score: 12_345_678 })).toBe(9_999_999);
  });

  it("calls time after three hours, as it stands", () => {
    const { state, r } = started();
    const s = step({ ...state, clock: { started: true, ticks: SAFETY_TICKS - 1 }, score: 77 }, r);
    expect(s.phase).toBe(PHASE.FINISHED);
    expect(finalScore(s)).toBe(77);
  });

  it("brings a new piece in at the top after a lock", () => {
    const { state, r } = started();
    const s = act(state, { type: "drop" }, r);
    expect(s.piece).toEqual(spawn(state.queue[0]));
  });
});
