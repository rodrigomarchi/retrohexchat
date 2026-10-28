import { describe, expect, it } from "vitest";
import { clearPoints, sprintPoints } from "../../../../js/lib/games/hex_blocks/scoring.js";
import { SPRINT } from "../../../../js/lib/games/hex_blocks/protocol.js";

describe("the Marathon's points", () => {
  it("pays rows cleared at once more than one at a time, times the level", () => {
    expect(clearPoints(1, 1, 0)).toBe(100);
    expect(clearPoints(2, 1, 0)).toBe(300);
    expect(clearPoints(3, 1, 0)).toBe(600);
    expect(clearPoints(4, 1, 0)).toBe(1000);
    expect(clearPoints(4, 5, 0)).toBe(5000);
    expect(clearPoints(0, 5, 3)).toBe(0);
  });

  it("adds the run of clears in a row", () => {
    expect(clearPoints(1, 2, 3)).toBe(200 + 50 * 3 * 2);
  });
});

describe("the Sprint's points", () => {
  it("are 10,000 for thirty seconds, fewer the longer it takes", () => {
    expect(sprintPoints(1800)).toBe(10_000);
    expect(sprintPoints(3600)).toBe(5_000);
    expect(sprintPoints(600)).toBe(10_000);
    expect(sprintPoints(SPRINT.MIN_TICKS * 6)).toBe(1_666);
  });
});
