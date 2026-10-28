import { describe, expect, it } from "vitest";
import { boardFlow } from "../../../../../js/lib/games/core/solo/board_game.js";
import {
  SAFETY_TICKS,
  scoreWithBonus,
  tickMatch,
  untilTimeUp,
} from "../../../../../js/lib/games/core/solo/clock.js";
import { PHASE, WIN_EVENT, ending } from "../../../../../js/lib/games/core/solo/phases.js";
import { laidFor, tableView } from "../../../../../js/lib/games/core/solo/view.js";

const GEOMETRY = {
  LANDSCAPE: { view: { width: 640, height: 480 } },
  PORTRAIT: { view: { width: 464, height: 720 } },
};
const canvasIn = (width, height) => ({ getBoundingClientRect: () => ({ width, height }) });

describe("a solo match's end", () => {
  const next = { phase: PHASE.PLAYING, events: 1 };

  it("celebrates a win, finishes a table left to itself, and closes one with no move left", () => {
    expect(ending(next, { won: true, finish: true, stuck: true })).toMatchObject({
      phase: PHASE.CELEBRATING,
      won: true,
      events: 1 | WIN_EVENT,
    });
    expect(ending(next, { won: false, finish: true })).toMatchObject({ phase: PHASE.AUTO_FINISH });
    expect(ending(next, { won: false, stuck: true })).toMatchObject({
      phase: PHASE.FINISHED,
      stuck: true,
    });
    expect(ending(next, { won: false })).toBe(next);
  });
});

describe("a solo match's clock", () => {
  it("runs only in play, and costs what time costs", () => {
    const playing = { phase: PHASE.PLAYING, clock: { started: true, ticks: 599 }, score: 10 };
    expect(tickMatch(playing).next).toMatchObject({ clock: { ticks: 600 }, score: 8, events: 0 });
    expect(tickMatch(playing, 0).next.score).toBe(10);
    const waiting = { ...playing, phase: PHASE.WAITING };
    expect(tickMatch(waiting).next.clock.ticks).toBe(599);
  });

  it("ends a match the hour runs out on, and adds a win's bonus", () => {
    expect(untilTimeUp({ phase: PHASE.PLAYING }, true).phase).toBe(PHASE.FINISHED);
    expect(untilTimeUp({ phase: PHASE.PLAYING }, false).phase).toBe(PHASE.PLAYING);
    const late = {
      phase: PHASE.PLAYING,
      clock: { started: true, ticks: SAFETY_TICKS - 1 },
      score: 0,
    };
    expect(tickMatch(late, 0).timeUp).toBe(true);
    // A game whose matches run longer calls time later.
    expect(tickMatch(late, 0, 3 * SAFETY_TICKS).timeUp).toBe(false);
    const won = { won: true, score: 100, clock: { ticks: 100 * 60 } };
    expect(scoreWithBonus(won)).toBe(7100);
    expect(scoreWithBonus({ ...won, won: false })).toBe(100);
  });
});

describe("the table a solo game is laid on", () => {
  it("stands up in a box taller than wide, for one geometry or one per game", () => {
    expect(tableView(GEOMETRY)(canvasIn(360, 600))).toEqual(GEOMETRY.PORTRAIT.view);
    expect(tableView(GEOMETRY)(canvasIn(800, 600))).toEqual(GEOMETRY.LANDSCAPE.view);
    const perGame = tableView((id) =>
      id === "big" ? { ...GEOMETRY, LANDSCAPE: { view: { width: 720, height: 480 } } } : GEOMETRY,
    );
    expect(perGame(canvasIn(800, 600), "big")).toEqual({ width: 720, height: 480 });
    expect(laidFor(GEOMETRY, { width: 464, height: 720 })).toBe(GEOMETRY.PORTRAIT);
  });
});

describe("a board game's flow", () => {
  const game = (overrides = {}) => ({
    frameCount: 0,
    fx: { list: [] },
    gameState: { phase: PHASE.CELEBRATING, events: 0, score: 7 },
    invalidate: () => {},
    finish: () => {},
    playSound: () => {},
    ...overrides,
  });
  const flow = (options = {}) =>
    boardFlow({
      tick: () => {},
      sounds: [],
      showTicks: () => 3,
      finalScore: (s) => s.score,
      ...options,
    });

  it("shows the end for its ticks, or until it settles", () => {
    const shown = game();
    const { CELEBRATING } = flow().states;
    CELEBRATING.enter(shown);
    CELEBRATING.tick(shown);
    CELEBRATING.tick(shown);
    expect(shown.gameState.phase).toBe(PHASE.CELEBRATING);
    CELEBRATING.tick(shown);
    expect(shown.gameState.phase).toBe(PHASE.FINISHED);

    const settled = game();
    const early = flow({ settled: () => true }).states.CELEBRATING;
    early.enter(settled);
    early.tick(settled);
    expect(settled.gameState.phase).toBe(PHASE.FINISHED);
  });

  it("tells the result once finished, after its own last word", () => {
    const order = [];
    const finished = game({ finish: ({ result }) => order.push(["finish", result]) });
    flow({ onFinish: () => order.push(["onFinish"]) }).states.FINISHED.enter(finished);
    expect(order[0]).toEqual(["onFinish"]);
    expect(order[1][0]).toBe("finish");
  });
});
