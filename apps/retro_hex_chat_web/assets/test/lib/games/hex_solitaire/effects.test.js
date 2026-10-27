import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import {
  actionEffects,
  active,
  cascadeEffects,
  createEffects,
  dealEffects,
  flightAt,
  flipWidth,
  flying,
  settle,
  shakeAt,
  stepEffects,
} from "../../../../js/lib/games/hex_solitaire/effects.js";
import { layout } from "../../../../js/lib/games/hex_solitaire/layout.js";
import { CARD, EVENT, FX, MODE } from "../../../../js/lib/games/hex_solitaire/protocol.js";
import { applyMove, deal } from "../../../../js/lib/games/hex_solitaire/rules.js";

const card = (rank, suit) => suit * 13 + rank - 1;
function table({ waste = [], foundations = [[], [], [], []], columns = [] } = {}) {
  const tableau = Array.from({ length: 7 }, (_, i) => ({
    down: columns[i]?.down ?? [],
    up: columns[i]?.up ?? [],
  }));
  return { mode: MODE.DRAW1, stock: [], waste, fan: waste.length ? 1 : 0, foundations, tableau };
}
const random = () => createRng(9).next;

describe("the deal", () => {
  it("flies every card on the table out of the stock, one after another, and lands them", () => {
    const fx = createEffects();
    const dealt = deal(createRng(1).next, MODE.DRAW1);
    dealEffects(fx, dealt, 0);

    expect(flying(fx).size).toBe(28);
    const last = fx.list.at(-1);
    expect(last.start).toBe(27 * FX.dealStagger);
    expect(flightAt(last, last.start)).toEqual({
      x: layout(dealt).stock.x,
      y: layout(dealt).stock.y,
    });
    const landed = flightAt(last, last.start + last.ticks);
    expect(landed).toEqual({
      x: layout(dealt).columns[6].cards.at(-1).x,
      y: layout(dealt).columns[6].cards.at(-1).y,
    });

    stepEffects(fx, last.start + last.ticks);
    expect(active(fx)).toBe(false);
  });
});

describe("an action's effects", () => {
  const before = table({ columns: [{ down: [card(9, 2)], up: [card(1, 1)] }] });
  const move = { from: { pile: "tableau", col: 0, index: 0 }, to: { pile: "foundation", suit: 1 } };
  const after = applyMove(before, move).state;
  const events = EVENT.FOUNDATION | EVENT.FLIP;

  it("flies the card to its foundation, turns the one left and throws sparks", () => {
    const fx = createEffects();
    actionEffects(fx, {
      before,
      after,
      action: { type: "move", move },
      events,
      now: 10,
      random: random(),
    });
    const kinds = fx.list.map((e) => e.kind).sort();
    expect(kinds).toEqual(["flight", "flip", "sparks"]);
    const trip = fx.list.find((e) => e.kind === "flight");
    expect(flightAt(trip, 10 + trip.ticks)).toEqual({
      x: layout(after).foundations[1].x,
      y: layout(after).foundations[1].y,
    });
    const flip = fx.list.find((e) => e.kind === "flip");
    expect([flipWidth(flip, 10), flipWidth(flip, 10 + FX.flip / 2)]).toEqual([CARD.width, 12]);
  });

  it("flies a dropped card from where the finger let it go", () => {
    const fx = createEffects();
    const drag = { x: 300, y: 200, cards: [card(1, 1)], from: move.from };
    actionEffects(fx, {
      before,
      after,
      action: { type: "move", move },
      events,
      now: 0,
      drag,
      random: random(),
    });
    expect(
      flightAt(
        fx.list.find((e) => e.kind === "flight"),
        0,
      ),
    ).toEqual({ x: 300, y: 200 });
  });

  it("sends a refused drag back, and shakes a refused tap", () => {
    const fx = createEffects();
    const drag = { x: 300, y: 200, cards: [card(1, 1)], from: move.from };
    actionEffects(fx, {
      before,
      after: before,
      action: { type: "return", from: move.from },
      events: EVENT.RETURN,
      now: 0,
      drag,
      random: random(),
    });
    const back = fx.list[0];
    expect(flightAt(back, back.ticks)).toEqual({
      x: layout(before).columns[0].cards[1].x,
      y: layout(before).columns[0].cards[1].y,
    });

    actionEffects(fx, {
      before,
      after: before,
      action: { type: "refuse", from: move.from },
      events: EVENT.REFUSE,
      now: 50,
      random: random(),
    });
    const shake = fx.list.find((e) => e.kind === "shake");
    const pushes = Array.from({ length: FX.shake + 1 }, (_, i) => shakeAt(shake, 50 + i));
    expect(pushes.some((dx) => dx !== 0)).toBe(true);
    expect(pushes.at(-1)).toBe(0);
    expect(pushes.every(Number.isInteger)).toBe(true);
  });

  it("ends every movement at once when the next gesture comes", () => {
    const fx = createEffects();
    actionEffects(fx, {
      before,
      after,
      action: { type: "move", move },
      events,
      now: 0,
      random: random(),
    });
    settle(fx);
    expect(flying(fx).size).toBe(0);
    expect(fx.list.map((e) => e.kind)).toEqual(["sparks"]);
  });

  it("draws the same sparks for the same seed", () => {
    const one = createEffects();
    const two = createEffects();
    actionEffects(one, {
      before,
      after,
      action: { type: "move", move },
      events,
      now: 0,
      random: random(),
    });
    actionEffects(two, {
      before,
      after,
      action: { type: "move", move },
      events,
      now: 0,
      random: random(),
    });
    expect(one.list).toEqual(two.list);
  });

  it("puts the cards straight in their places with motion reduced", () => {
    const fx = createEffects({ reduced: true });
    actionEffects(fx, {
      before,
      after,
      action: { type: "move", move },
      events,
      now: 0,
      random: random(),
    });
    expect(flying(fx).size).toBe(0);
    expect(fx.list.map((e) => e.kind)).toEqual(["sparks"]);
  });
});

describe("the cascade of a win", () => {
  const won = table({
    foundations: [0, 1, 2, 3].map((s) => Array.from({ length: 13 }, (_, r) => card(r + 1, s))),
  });

  it("launches all 52 cards one after another, and they bounce off the felt until gone", () => {
    const fx = createEffects();
    cascadeEffects(fx, won, 0, random());
    const [cascade] = fx.list;
    expect(cascade.items).toHaveLength(52);
    expect(cascade.items[0].card).toBe(card(13, 0));
    let now = 0;
    while (active(fx) && now < 5000) stepEffects(fx, ++now);
    expect(active(fx)).toBe(false);
  });

  it("is a few sparks with motion reduced", () => {
    const fx = createEffects({ reduced: true });
    cascadeEffects(fx, won, 0, random());
    expect(fx.list.map((e) => e.kind)).toEqual(["sparks", "sparks", "sparks", "sparks"]);
  });
});
