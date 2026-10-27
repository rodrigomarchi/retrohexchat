import { describe, expect, it } from "vitest";
import {
  CEILING,
  MODE,
  POINTS,
  SAFETY_TICKS,
} from "../../../../js/lib/games/hex_solitaire/protocol.js";
import {
  addPoints,
  recyclePoints,
  scoreMove,
  startClock,
  tickClock,
  timeBonus,
} from "../../../../js/lib/games/hex_solitaire/scoring.js";

const waste = { pile: "waste" };
const column = (col, index = 0) => ({ pile: "tableau", col, index });
const foundation = { pile: "foundation", suit: 0 };
const move = (from, to) => ({ from, to });

describe("the points of a move", () => {
  it("pays the classic table", () => {
    expect(scoreMove(move(waste, column(0)), false)).toBe(5);
    expect(scoreMove(move(waste, foundation), false)).toBe(10);
    expect(scoreMove(move(column(2), foundation), false)).toBe(10);
    expect(scoreMove(move(column(2), column(3)), false)).toBe(0);
    expect(scoreMove(move(foundation, column(3)), false)).toBe(-15);
  });

  it("adds five for the card a move turns over", () => {
    expect(scoreMove(move(column(2), column(3)), true)).toBe(5);
    expect(scoreMove(move(column(2), foundation), true)).toBe(15);
  });

  it("costs more to turn the stock over drawing one than drawing three", () => {
    expect(recyclePoints(MODE.DRAW1)).toBe(-100);
    expect(recyclePoints(MODE.DRAW3)).toBe(-20);
  });

  it("never lets the score fall below zero", () => {
    expect(addPoints(30, recyclePoints(MODE.DRAW1))).toBe(0);
    expect(addPoints(30, 5)).toBe(35);
  });

  it("loses five each time a card goes up and comes back, so nothing is earned by cycling", () => {
    expect(
      scoreMove(move(column(0), foundation), false) + scoreMove(move(foundation, column(0)), false),
    ).toBe(-5);
  });
});

describe("the clock", () => {
  it("stands still until the first move, then counts ticks", () => {
    let clock = { started: false, ticks: 0 };
    clock = tickClock(clock).clock;
    expect(clock.ticks).toBe(0);
    clock = startClock(clock);
    clock = tickClock(clock).clock;
    expect(clock.ticks).toBe(1);
    expect(startClock(clock)).toBe(clock);
  });

  it("costs two points every ten seconds of play", () => {
    let clock = startClock({ started: false, ticks: 0 });
    let penalty = 0;
    for (let i = 0; i < 1200; i++) {
      const step = tickClock(clock);
      clock = step.clock;
      penalty += step.points;
    }
    expect(penalty).toBe(2 * POINTS.TIME_PENALTY);
    expect(POINTS.TIME_PENALTY).toBe(-2);
  });

  it("calls time after the hour the safety clock allows", () => {
    const almost = { started: true, ticks: SAFETY_TICKS - 1 };
    expect(tickClock(almost).timeUp).toBe(true);
    expect(tickClock({ started: true, ticks: 10 }).timeUp).toBe(false);
    expect(SAFETY_TICKS).toBe(60 * 60 * 60);
  });
});

describe("the time bonus", () => {
  it("pays 700000 divided by the seconds a win took, from thirty seconds", () => {
    expect(timeBonus(29 * 60 + 59)).toBe(0);
    expect(timeBonus(30 * 60)).toBe(23_333);
    expect(timeBonus(100 * 60)).toBe(7_000);
  });
});

describe("the ceiling", () => {
  it("is the most a game can score: every move's points and the fastest bonus", () => {
    const foundationCards = 52 * POINTS.TO_FOUNDATION;
    const turnedOver = 21 * POINTS.FLIP;
    const stockToTable = 24 * POINTS.WASTE_TO_TABLEAU;
    expect(foundationCards + turnedOver + stockToTable + timeBonus(30 * 60)).toBe(CEILING);
    expect(CEILING).toBe(24_078);
  });
});
