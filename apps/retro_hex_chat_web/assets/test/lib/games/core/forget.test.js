import { describe, expect, it } from "vitest";
import { defineGame } from "../../../../js/lib/games/core/define_game.js";
import { definition, PHASE } from "../../../support/games/fake_game.js";
import { matchPerTest } from "../../../support/games/harness.js";

/** One step at 60 Hz, in ms. */
const STEP = 1000 / 60;

/**
 * The fake two-player game with an AI that counts what it forgot, and a
 * play phase that, on the fifth step of a round, hands over to a pause the
 * AI is never asked in — a point, a round's end — and back.
 */
function gameWithWatchedAI({ asksEveryStep }) {
  const ai = { forgets: 0, asks: 0 };
  const ask = (game) => {
    ai.asks += 1;
    game.updateOpponent();
  };
  const EngineClass = defineGame({
    ...definition,
    ai: {
      create: () => ({
        nextInputs: () => ({ right: false }),
        forget: () => {
          ai.forgets += 1;
        },
      }),
      difficulty: (d) => d || "normal",
    },
    flow: {
      ...definition.flow,
      phases: { ...PHASE, PAUSE: 9 },
      states: {
        ...definition.flow.states,
        PLAYING: {
          enter: (game) => {
            game.roundSteps = 0;
          },
          tick: (game) => {
            ask(game);
            game.roundSteps += 1;
            if (game.roundSteps === 5) game.gameState.phase = 9;
          },
        },
        PAUSE: {
          tick: (game) => {
            if (asksEveryStep) ask(game);
          },
          after: { ticks: 10 },
          next: "PLAYING",
        },
      },
    },
  });
  return { EngineClass, ai };
}

describe("the AI forgets on every phase change", () => {
  const start = matchPerTest({ gameId: "fake", mode: "solo" });

  it("whether it is asked only in play or on every step", async () => {
    for (const asksEveryStep of [false, true]) {
      const { EngineClass, ai } = gameWithWatchedAI({ asksEveryStep });
      const match = await start({ EngineClass });
      match.advance(1000);

      // COUNTDOWN, then PLAYING, PAUSE and PLAYING again, round after round:
      // one forget per phase entered, none in between.
      const phases = match.record().phases.filter((p) => p.side === "host").length;
      expect(ai.asks).toBeGreaterThan(0);
      expect(phases).toBeGreaterThanOrEqual(6);
      expect(ai.forgets).toBe(phases);
    }
  });

  it("nothing else makes it forget: a phase held for many steps keeps its memory", async () => {
    const { EngineClass, ai } = gameWithWatchedAI({ asksEveryStep: true });
    const match = await start({ EngineClass });
    match.advance(3 * STEP);
    const before = ai.forgets;
    match.advance(3 * STEP);
    expect(match.engines.host.gameState.phase).toBe(PHASE.COUNTDOWN);
    expect(ai.forgets).toBe(before);
  });
});
