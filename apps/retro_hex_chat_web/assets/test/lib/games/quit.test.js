import { describe, expect, it } from "vitest";
import { ENGINE_GAME_IDS } from "../../support/games/engines.js";
import { matchPerTest } from "../../support/games/harness.js";

/**
 * End pressed mid-match, in every game: the match is written down as it
 * stands, so each engine must tell its score at any moment of play.
 */
describe.each(ENGINE_GAME_IDS)("%s ended early", (gameId) => {
  const play = matchPerTest();

  it("reports the score as it stands, once", async () => {
    const match = await play({ gameId, mode: "solo", seed: 4 });
    match.advance(5000);
    expect(match.over()).toBe(false);

    expect(match.engines.host.quit()).toBe(true);
    match.advance(500);

    expect(match.results.host).toHaveLength(1);
    const [{ score, ended_early: endedEarly, ...rest }] = match.results.host;
    expect(endedEarly).toBe(true);
    expect(rest).toEqual({});
    for (const side of ["p1", "p2"]) {
      expect(Number.isInteger(score[side])).toBe(true);
      expect(score[side]).toBeGreaterThanOrEqual(0);
    }
  });
});
