import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { PHASE } from "../../../../js/lib/games/core/solo/phases.js";
import { createEffects, playedEffects } from "../../../../js/lib/games/hex_blocks/effects.js";
import { GEOMETRY, layout } from "../../../../js/lib/games/hex_blocks/layout.js";
import { createInitialState, step } from "../../../../js/lib/games/hex_blocks/physics.js";
import { PIECES } from "../../../../js/lib/games/hex_blocks/pieces.js";
import {
  COLS,
  COUNTDOWN_TICKS,
  EVENT,
  HIDDEN,
  MODE,
  ROWS,
} from "../../../../js/lib/games/hex_blocks/protocol.js";
import { render } from "../../../../js/lib/games/hex_blocks/renderer.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";
import { cutsOf, filledWith } from "../../../support/games/canvas_log.js";

const NAMES = [
  ...PIECES.map((p) => `gem_${p.colour}`),
  "empty",
  "ghost",
  "flash",
  "keep",
  ...[..."0123456789"].map((d) => `digit_${d}`),
  "colon",
  "dot",
  "level",
  "lines",
];
const regions = Object.fromEntries(
  NAMES.map((name, k) => [name, { x: k * 30, y: 0, w: 24, h: 20 }]),
);
const atlas = { image: { id: "tiles" }, regions };
const colors = Object.fromEntries(
  ["back", "panel", "edge", "well", "gem", "trail", "led", "pulse"].map((name) => [name, name]),
);
const cut = (log, name) => cutsOf(log, regions[name]);
const alphas = (log, name) => {
  let alpha = 1;
  const seen = [];
  for (const entry of log) {
    if (entry[0] === "globalAlpha") alpha = entry[2];
    if (entry[0] === "drawImage" && entry[2] === regions[name].x) seen.push(alpha);
  }
  return seen;
};

const random = () => createRng(5).fork("bag").next;
/** The effects the game plays of the change from `before` to `after`. */
function effectsOf(before, after) {
  const fx = createEffects();
  playedEffects(fx, { before, after, laid: layout(GEOMETRY.LANDSCAPE), now: 0, random: () => 0.5 });
  return fx;
}
/** The colour the well's frame is filled with: the first fill after the background. */
const edgeOf = (log) => log.filter(([op]) => op === "fillStyle").map(([, , v]) => v)[1];
function playing(mode = MODE.hex_blocks) {
  const r = random();
  let state = { ...createInitialState(mode, r), phase: PHASE.PLAYING };
  for (let i = 0; i < COUNTDOWN_TICKS; i++) state = step(state, r);
  return state;
}
function drawn(state, { side = "LANDSCAPE", fx = createEffects(), now = 0 } = {}) {
  const laid = layout(GEOMETRY[side]);
  const canvas = recordingCanvas(laid.view.width, laid.view.height);
  canvas.clearLog();
  render(canvas.getContext("2d"), { state, laid, fx, atlas, colors, now });
  return canvas.log;
}
const gems = (log) => PIECES.reduce((n, p) => n + cut(log, `gem_${p.colour}`), 0);

describe("Hex Blocks' picture", () => {
  it("draws every square of the well in sight and the count's second", () => {
    const state = { ...createInitialState(MODE.hex_blocks, random()), phase: PHASE.PLAYING };
    const log = drawn(state);
    expect(cut(log, "empty")).toBe(COLS * (ROWS - HIDDEN));
    expect(cut(log, "digit_3")).toBeGreaterThanOrEqual(1);
    expect(cut(log, "ghost")).toBe(0);
  });

  it("draws the piece falling, its shadow, and the three pieces coming", () => {
    const state = playing();
    const log = drawn(state);
    expect(cut(log, "ghost")).toBe(4);
    // The pieces coming, four hexagons each; the piece's own are still on the hidden rows' edge.
    expect(gems(log)).toBeGreaterThanOrEqual(12);
  });

  it("dims the piece held while it may not be swapped again", () => {
    const state = { ...playing(), held: 0, canHold: false };
    expect(alphas(drawn(state), "gem_red")).toContain(0.4);
    expect(alphas(drawn({ ...state, canHold: true }), "gem_red")).not.toContain(0.4);
  });

  it("marks the empty box of the piece held with the keep mark, faint", () => {
    const empty = drawn(playing());
    expect(cut(empty, "keep")).toBe(1);
    expect(alphas(empty, "keep")).toContain(0.3);
    expect(cut(drawn({ ...playing(), held: 0 }), "keep")).toBe(0);
  });

  it("shows the Marathon's level and rows, the Sprint's time and the rows still to clear", () => {
    const marathon = drawn(playing());
    expect(cut(marathon, "level")).toBe(1);
    expect(cut(marathon, "colon")).toBe(0);
    const sprint = drawn(playing(MODE.hex_blocks_sprint));
    expect(cut(sprint, "level")).toBe(0);
    expect(cut(sprint, "colon")).toBe(1);
    expect(cut(sprint, "dot")).toBe(1);
    expect(cut(sprint, "lines")).toBe(1);
  });

  it("pulses the level when it goes up, and tints the well's frame by the level", () => {
    const before = playing();
    const after = { ...before, level: 2, events: EVENT.LEVEL };
    const fx = effectsOf(before, after);
    const pulsing = drawn(after, { fx, now: 5 });
    expect(filledWith(pulsing, "pulse")).toBeGreaterThan(0);
    expect(filledWith(drawn(after, { fx, now: 200 }), "pulse")).toBe(0);
    expect(edgeOf(drawn(before))).not.toBe(edgeOf(drawn(after)));
    expect(edgeOf(drawn({ ...before, level: 6 }))).toBe(edgeOf(drawn(before)));
  });

  it("darkens the well when the next piece had no room, the piece still there", () => {
    const state = { ...playing(), phase: PHASE.CELEBRATING, over: true };
    expect(filledWith(drawn(state), "well")).toBeGreaterThan(filledWith(drawn(playing()), "well"));
  });

  it("flashes the rows a lock cleared", () => {
    const before = playing();
    // A piece set in the well that cleared the bottom row, as the physics records it.
    const landed = { n: 1, cells: [], well: before.well, trail: null };
    const after = { ...before, cleared: [ROWS - 1], landed, events: 0 };
    const fx = effectsOf(before, after);
    expect(cut(drawn(after, { fx, now: 1 }), "flash")).toBe(COLS);
  });
});
