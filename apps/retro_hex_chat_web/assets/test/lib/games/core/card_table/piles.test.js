import { describe, expect, it } from "vitest";
import {
  cardPlace,
  columnCards,
  contains,
  fanOffsets,
  overlap,
} from "../../../../../js/lib/games/core/card_table/piles.js";

const CARD = { width: 64, height: 88 };

describe("a column's fan", () => {
  it("keeps its offsets while the column fits", () => {
    expect(fanOffsets({ room: 300, down: 3, up: 4, downOffset: 6, upOffset: 18, min: 4 })).toEqual({
      downOffset: 6,
      upOffset: 18,
    });
  });

  it("squeezes the face-up cards first, then the face-down ones, never under the least", () => {
    const room = 200;
    const long = fanOffsets({ room, down: 6, up: 13, downOffset: 6, upOffset: 18, min: 4 });
    expect(long.downOffset).toBe(6);
    expect(6 * long.downOffset + 12 * long.upOffset).toBeLessThanOrEqual(room);

    // Spider's longest: 25 cards still end inside the room.
    const spider = fanOffsets({ room, down: 5, up: 20, downOffset: 6, upOffset: 18, min: 4 });
    expect(5 * spider.downOffset + 19 * spider.upOffset).toBeLessThanOrEqual(room);
    expect(spider.upOffset).toBeGreaterThanOrEqual(4);
  });

  it("lays the cards down from the slot, face down first, the face-up ones indexed", () => {
    const cards = columnCards(
      cardPlace(10, 100, CARD),
      [7, 8],
      [9],
      { downOffset: 6, upOffset: 18 },
      CARD,
    );
    expect(cards.map((c) => [c.card, c.faceUp, c.index, c.y])).toEqual([
      [7, false, null, 100],
      [8, false, null, 106],
      [9, true, 0, 112],
    ]);
    expect(cards[2]).toMatchObject({ x: 10, w: 64, h: 88 });
  });
});

describe("places", () => {
  it("tell a point on them and how much two cover each other", () => {
    const a = cardPlace(0, 0, CARD);
    expect(contains(a, 63, 87)).toBe(true);
    expect(contains(a, 64, 0)).toBe(false);
    expect(overlap(a, cardPlace(32, 44, CARD))).toBe(32 * 44);
    expect(overlap(a, cardPlace(64, 0, CARD))).toBe(0);
  });
});
