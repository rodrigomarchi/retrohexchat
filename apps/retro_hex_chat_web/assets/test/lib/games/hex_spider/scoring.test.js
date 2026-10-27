import { describe, expect, it } from "vitest";
import { CEILING, POINTS } from "../../../../js/lib/games/hex_spider/protocol.js";

describe("Hex Spider's points", () => {
  it("start at five hundred, cost one a move and pay a hundred a suit", () => {
    expect(POINTS).toMatchObject({ START: 500, MOVE: -1, COMPLETE: 100 });
  });

  it("top out at the start and the eight suits, whatever the variant", () => {
    expect(CEILING).toBe(500 + 8 * 100);
  });
});
