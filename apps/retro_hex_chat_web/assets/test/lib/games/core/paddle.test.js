import { describe, expect, it } from "vitest";
import { paddleBounce } from "../../../../js/lib/games/core/paddle.js";

const RULES = { maxAngle: Math.PI / 3, increment: 0.5, maxSpeed: 6 };

describe("paddleBounce", () => {
  it("sends a ball met at the middle straight back, a little faster", () => {
    expect(paddleBounce(50, 50, 20, 4, RULES)).toEqual({ speed: 4.5, across: 4.5, along: 0 });
  });

  it("turns a ball met at an end by the most it allows, and no more past it", () => {
    const end = paddleBounce(70, 50, 20, 4, RULES);
    expect(end.across).toBeCloseTo(4.5 * Math.cos(Math.PI / 3));
    expect(end.along).toBeCloseTo(4.5 * Math.sin(Math.PI / 3));
    expect(paddleBounce(90, 50, 20, 4, RULES)).toEqual(end);
    expect(paddleBounce(30, 50, 20, 4, RULES).along).toBeCloseTo(-end.along);
  });

  it("never speeds the ball past its ceiling", () => {
    expect(paddleBounce(50, 50, 20, 5.8, RULES).speed).toBe(6);
  });
});
