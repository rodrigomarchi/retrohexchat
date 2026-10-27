import { describe, expect, it } from "vitest";
import { createRng } from "../../../../../js/lib/games/core/rng.js";
import {
  FX,
  cascadeEffects,
  createEffects,
  dealEffects,
  flipWidth,
  flying,
  stepEffects,
} from "../../../../../js/lib/games/core/card_table/effects.js";

const column = (x, ids) => ({
  cards: ids.map((card, i) => ({ card, faceUp: true, x, y: i * 10 })),
});

describe("a card table's effects", () => {
  it("deals in rounds, one card to each column still short, left to right", () => {
    const fx = createEffects();
    dealEffects(fx, [column(0, [1, 2, 3]), column(50, [4])], { x: 0, y: 0 }, 0);
    expect(fx.list.map((e) => e.cards[0])).toEqual([1, 4, 2, 3]);
    expect(fx.list.at(-1).start).toBe(3 * FX.dealStagger);
  });

  it("cascades the top of every pile in turn, whatever the cards are", () => {
    const fx = createEffects();
    const piles = [
      { place: { x: 0, y: 0 }, cards: [60, 61] },
      { place: { x: 70, y: 0 }, cards: [90, 91] },
    ];
    cascadeEffects(fx, piles, { width: 720, height: 540 }, 0, createRng(4).next);
    const cascade = fx.list[0];
    expect(cascade.items.map((item) => item.card)).toEqual([61, 91, 60, 90]);
    stepEffects(fx, 10_000);
    expect(flying(fx).size).toBe(0);
  });

  it("narrows a smaller card in the same steps", () => {
    const effect = { start: 0, ticks: FX.flip };
    expect(flipWidth(effect, 0)).toBe(64);
    expect(flipWidth(effect, 3)).toBe(12);
    expect(flipWidth(effect, 0, 44)).toBe(44);
    expect(flipWidth(effect, 3, 44)).toBe(8);
  });

  it("bounces a smaller card off the felt at its own height", () => {
    const fx = createEffects({ card: { width: 44, height: 62 } });
    const piles = [{ place: { x: 300, y: 400 }, cards: [7] }];
    cascadeEffects(fx, piles, { width: 640, height: 480 }, 0, createRng(4).next);
    const item = fx.list[0].items[0];
    let lowest = 0;
    for (let now = 0; now < 40 && !item.gone; now++) {
      stepEffects(fx, now);
      lowest = Math.max(lowest, item.y);
    }
    expect(lowest).toBe(480 - 62);
  });
});
