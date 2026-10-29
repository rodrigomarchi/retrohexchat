import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { PHASE } from "../../../../js/lib/games/core/solo/phases.js";
import {
  blinkAt,
  createEffects,
  playedEffects,
  settleAt,
} from "../../../../js/lib/games/hex_blocks/effects.js";
import { GEOMETRY, layout } from "../../../../js/lib/games/hex_blocks/layout.js";
import { act, createInitialState, step } from "../../../../js/lib/games/hex_blocks/physics.js";
import { COUNTDOWN_TICKS, LOCK, ROWS } from "../../../../js/lib/games/hex_blocks/protocol.js";
import { cellsOf, landing } from "../../../../js/lib/games/hex_blocks/rules.js";
import { bottomRowForPiece } from "./wells.js";

const laid = layout(GEOMETRY.LANDSCAPE);
const random = () => createRng(9).fork("bag").next;
function playing() {
  const r = random();
  let state = { ...createInitialState({ sprint: false, goal: null }, r), phase: PHASE.PLAYING };
  for (let i = 0; i < COUNTDOWN_TICKS; i++) state = step(state, r);
  return { state, r };
}
/** The effects of every change from `before` to `after`, as the game plays them. */
const played = (fx, before, after, now = 0) =>
  playedEffects(fx, { before, after, laid, now, random: () => 0.5 });
const kinds = (fx, kind) => fx.list.filter((e) => e.kind === kind).length;

describe("Hex Blocks' effects", () => {
  it("flashes a row cleared by gravity once, not again at the next press", () => {
    const { state, r } = playing();
    const resting = { ...state, piece: landing(state.well, state.piece) };
    let s = { ...resting, well: bottomRowForPiece(resting) };
    const fx = createEffects();
    for (let i = 0; i < LOCK.TICKS; i++) {
      const before = s;
      s = step(s, r);
      played(fx, before, s, i);
    }
    expect(kinds(fx, "flash")).toBe(1);
    // The next tick: a press first, as the game plays it.
    const before = s;
    const pressed = act(s, { type: "press", input: "left" }, r);
    played(fx, before, pressed, LOCK.TICKS);
    expect(kinds(fx, "flash")).toBe(1);
    expect(kinds(fx, "settle")).toBe(1);
  });

  it("blinks each lock, two in a row too", () => {
    const { state, r } = playing();
    const fx = createEffects();
    const first = act(state, { type: "drop" }, r);
    played(fx, state, first, 0);
    const second = act(first, { type: "drop" }, r);
    played(fx, first, second, 1);
    expect(kinds(fx, "blink")).toBe(2);
  });

  it("blinks where the piece locked, after a move in the same tick", () => {
    const { state, r } = playing();
    const fx = createEffects();
    const moved = act(state, { type: "press", input: "left" }, r);
    const locked = act(moved, { type: "drop" }, r);
    played(fx, state, locked, 0);
    const blink = blinkAt(fx, 1);
    expect([...blink.cells].sort()).toEqual([...cellsOf(landing(moved.well, moved.piece))].sort());
  });

  it("settles each square by the rows cleared under it, for rows apart", () => {
    const fx = createEffects();
    fx.list.push({ kind: "settle", rows: [ROWS - 4, ROWS - 1], start: 0, ticks: 10 });
    expect(settleAt(fx, ROWS - 2, 0)).toBe(1);
    expect(settleAt(fx, ROWS - 6, 0)).toBe(2);
    expect(settleAt(fx, ROWS - 1, 0)).toBe(0);
  });
});
