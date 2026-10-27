import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { createEffects, dealEffects } from "../../../../js/lib/games/hex_solitaire/effects.js";
import { layout } from "../../../../js/lib/games/hex_solitaire/layout.js";
import { MODE } from "../../../../js/lib/games/hex_solitaire/protocol.js";
import { createInitialState } from "../../../../js/lib/games/hex_solitaire/physics.js";
import { render } from "../../../../js/lib/games/hex_solitaire/renderer.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const colors = { felt: "f", feltDark: "d", slot: "s", ink: "i", shadow: "sh" };
const region = (i) => ({ x: i * 66, y: 0, w: 64, h: 88 });
const image = { id: "atlas" };
const atlas = {
  image,
  card: { width: 64, height: 88 },
  faces: Array.from({ length: 52 }, (_, i) => region(i)),
  backs: [0, 1, 2, 3].map((i) => region(60 + i)),
};

function drawn(scene) {
  const canvas = recordingCanvas(640, 480);
  canvas.clearLog();
  render(canvas.getContext("2d"), {
    fx: createEffects(),
    drag: null,
    atlas,
    colors,
    now: 0,
    back: 0,
    ...scene,
  });
  return canvas.log;
}
const images = (log) => log.filter(([op]) => op === "drawImage");
const state = createInitialState(createRng(3).next, MODE.DRAW1);

describe("the picture", () => {
  it("draws the 28 cards on the table and the stock's top, cut from the atlas", () => {
    const log = drawn({ state });
    expect(images(log)).toHaveLength(29);
    expect(images(log).every((call) => call[1] === "atlas")).toBe(true);
  });

  it("draws the back the player chose for every card face down", () => {
    const backTwo = atlas.backs[2];
    const log = drawn({ state, back: 2 });
    const backs = images(log).filter((call) => call[2] === backTwo.x);
    expect(backs).toHaveLength(22); // 21 dealt face down, and the stock
  });

  it("leaves a card that flies out of its place, and draws it where it is", () => {
    const fx = createEffects();
    dealEffects(fx, state.table, 0);
    const log = drawn({ state, fx, now: 0 });
    // Only the first card has left the stock; the rest wait unseen.
    expect(images(log)).toHaveLength(2);
  });

  it("draws a held card over everything, lifted, with its shadow", () => {
    const top = layout(state.table).columns[0].cards[0];
    const drag = { cards: [top.card], from: { pile: "tableau", col: 0, index: 0 }, x: 300, y: 250 };
    const log = drawn({ state, drag });
    const last = images(log).at(-1);
    expect(last.slice(-4)).toEqual([300, 248, 64, 88]);
    expect(
      log.some(([op, ...args]) => op === "fillRect" && args[0] === 304 && args[1] === 252),
    ).toBe(true);
  });

  it("draws plain cards while the atlas is still loading", () => {
    const log = drawn({ state, atlas: null });
    expect(images(log)).toHaveLength(0);
    expect(log.filter(([op]) => op === "strokeRect").length).toBeGreaterThanOrEqual(29);
  });

  it("puts every card on a whole pixel", () => {
    const log = drawn({ state });
    for (const call of images(log)) expect(call.slice(-4).every(Number.isInteger)).toBe(true);
  });

  it("shows the card under one the cascade has launched", () => {
    const foundations = [0, 1, 2, 3].map((suit) =>
      Array.from({ length: 13 }, (_, r) => suit * 13 + r),
    );
    const won = {
      ...state,
      table: {
        ...state.table,
        stock: [],
        tableau: state.table.tableau.map(() => ({ down: [], up: [] })),
        foundations,
      },
    };
    const fx = createEffects();
    fx.list.push({
      kind: "cascade",
      start: 0,
      ticks: Infinity,
      items: [{ card: 12, x: 0, y: 0, vx: 0, vy: 0, launch: 0 }],
    });
    const log = drawn({ state: won, fx, now: 1 });
    const queen = atlas.faces[11];
    const spadesPlace = layout(won.table).foundations[0];
    expect(
      images(log).some((c) => c[2] === queen.x && c[6] === spadesPlace.x && c[7] === spadesPlace.y),
    ).toBe(true);
  });
});
