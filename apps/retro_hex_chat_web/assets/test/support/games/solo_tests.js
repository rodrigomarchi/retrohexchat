import { expect, it } from "vitest";
import { matchPerTest } from "./harness.js";

/**
 * What the match tests of a one-player pointer game share: its matches on a
 * box of the page, one under way, End pressed mid-match, and the same match
 * played twice.
 */

/** The box a canvas lying down sits in on the page, at the game's own size. */
const LYING = Object.freeze({ left: 0, top: 0, width: 640, height: 480 });

/**
 * A `describe`'s matches of one game, on match seed 42, its canvas in `rect`:
 * `matchPerTest` for `Game`.
 */
export const soloMatches = (Game, gameId, rect = LYING) =>
  matchPerTest({ EngineClass: Game, gameId, mode: "solo", matchSeed: 42, rect });

/** A match `play` began on `options`, a tenth of a second in: the match and its host. */
export async function underway(play, options) {
  const match = await play(options);
  match.advance(100);
  return { match, host: match.engines.host };
}

/**
 * End pressed `after` ms into a match `start()` began: the points it held
 * reported once, ended early.
 * @param {string} title
 * @param {() => Promise<object>} start
 * @param {{ after?: number, points?: number }} [ending]
 */
export function itEndsEarly(title, start, { after = 500, points = 0 } = {}) {
  it(title, async () => {
    const match = await start();
    if (after) match.advance(after);
    match.engines.host.quit();
    expect(match.results.host).toEqual([{ score: { p1: points, p2: 0 }, ended_early: true }]);
  });
}

/**
 * The same seed and the same presses play the same match: `taps` (each
 * `[at, x, y]`, released 30 ms later, or a function that finds them) played
 * twice on `play`'s matches, two seconds each.
 */
export function itReplays(play, taps) {
  it("plays the same match for the same seed and the same presses", async () => {
    const points = typeof taps === "function" ? await taps() : taps;
    const script = points.flatMap(([at, x, y]) => [
      { at, side: "host", pointer: "down", x, y },
      { at: at + 30, side: "host", pointer: "up", x, y },
    ]);
    const finalState = async () => {
      const match = await play({ script });
      match.advance(2000);
      const state = JSON.stringify(match.engines.host.gameState);
      match.stop();
      match.restore();
      return state;
    };
    expect(await finalState()).toBe(await finalState());
  });
}
