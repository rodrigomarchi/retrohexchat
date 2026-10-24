import { describe, expect, it } from "vitest";
import { matchResult } from "../../../../js/lib/games/core/result.js";

describe("matchResult", () => {
  it("spells a result the one way the server reads for every game", () => {
    expect(matchResult(3, 1, 1)).toEqual({ score: { p1: 3, p2: 1 }, winner: 1 });
  });

  it("keeps a draw, and a co-op pair's win (0) or loss (-1), as numbers", () => {
    expect(matchResult(2, 2, 0)).toEqual({ score: { p1: 2, p2: 2 }, winner: 0 });
    expect(matchResult(40, 40, -1)).toEqual({ score: { p1: 40, p2: 40 }, winner: -1 });
  });
});
