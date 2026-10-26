import fc from "fast-check";
import { describe, it, expect } from "vitest";
import {
  aiRng,
  clamp,
  createReaction,
  edgeAware,
  finiteMotion,
  dutyFrame,
  interceptAt,
  normalizeAngle,
  normalizeDifficulty,
  randomUnit,
  reflect,
  rotationDelta,
  toward,
} from "../../../../js/lib/games/core/ai.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";

describe("normalizeDifficulty", () => {
  it("keeps a known difficulty, in any case", () => {
    expect(normalizeDifficulty("HARD")).toBe("hard");
    expect(normalizeDifficulty("easy", { easy: {}, normal: {} })).toBe("easy");
  });

  it("falls back to normal for anything else", () => {
    expect(normalizeDifficulty("insane")).toBe("normal");
    expect(normalizeDifficulty(undefined)).toBe("normal");
    expect(normalizeDifficulty("hard", { easy: {}, normal: {} })).toBe("normal");
    expect(normalizeDifficulty("toString", {})).toBe("normal");
  });
});

describe("clamp", () => {
  it("keeps a value within its bounds", () => {
    expect(clamp(5, 0, 3)).toBe(3);
    expect(clamp(-1, 0, 3)).toBe(0);
    expect(clamp(2, 0, 3)).toBe(2);
  });
});

describe("reflect", () => {
  it("folds a coordinate back between two walls, as a bouncing ball does", () => {
    expect(reflect(50, 10, 100)).toBe(50);
    expect(reflect(110, 10, 100)).toBe(90);
    expect(reflect(-10, 10, 100)).toBe(30);
    expect(reflect(200, 10, 100)).toBe(20);
  });

  it("answers the fallback for a coordinate that is not a number", () => {
    expect(reflect(NaN, 10, 100, 55)).toBe(55);
  });

  it("always lands between the walls", () => {
    fc.assert(
      fc.property(fc.double({ min: -1e6, max: 1e6, noNaN: true }), (value) => {
        const r = reflect(value, 10, 100);
        return r >= 10 && r <= 100;
      }),
    );
  });
});

describe("interceptAt", () => {
  it("is where a ball bouncing between two walls crosses the target line", () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 20, max: 400 }),
        fc.integer({ min: 1, max: 8 }),
        fc.integer({ min: 10, max: 100 }),
        fc.integer({ min: -9, max: 9 }),
        (target, vx, y0, vy) => {
          // A ball from x = 0 moving right by vx, y bouncing between 10 and 100.
          const frames = target / vx;
          if (!Number.isInteger(frames)) return true;
          let y = y0;
          let dy = vy;
          for (let i = 0; i < frames; i++) {
            y += dy;
            if (y > 100) [y, dy] = [200 - y, -dy];
            if (y < 10) [y, dy] = [20 - y, -dy];
          }
          return Math.abs(interceptAt(0, vx, target, y0, vy, 10, 100) - y) < 1e-9;
        },
      ),
    );
  });

  it("is null when the ball will never reach the line, or has passed it", () => {
    expect(interceptAt(0, 0, 100, 50, 1, 10, 100)).toBeNull();
    expect(interceptAt(150, 2, 100, 50, 1, 10, 100)).toBeNull();
  });
});

describe("toward", () => {
  it("presses the way to the target, nothing inside the dead zone", () => {
    expect(toward(100, 80, 4)).toEqual([true, false]);
    expect(toward(100, 120, 4)).toEqual([false, true]);
    expect(toward(100, 103, 4)).toEqual([false, false]);
    expect(toward(100, 96, 4)).toEqual([false, false]);
  });
});

describe("dutyFrame", () => {
  it("moves on the share of every ten frames the duty asks for", () => {
    const moving = Array.from({ length: 10 }, (_, f) => dutyFrame(f, 0.6));
    expect(moving).toEqual([true, true, true, true, true, true, false, false, false, false]);
    expect(dutyFrame(7, 1)).toBe(true);
  });
});

describe("randomUnit", () => {
  it("is a draw in [0, 1), and 0 for a draw that is not a number", () => {
    expect(randomUnit(() => 0.25)).toBe(0.25);
    expect(randomUnit(() => 1)).toBeLessThan(1);
    expect(randomUnit(() => -3)).toBe(0);
    expect(randomUnit(() => NaN)).toBe(0);
  });
});

describe("createReaction", () => {
  it("takes a new sample once every `every` frames, and holds it between", () => {
    const reaction = createReaction();
    let n = 0;
    const seen = Array.from({ length: 7 }, () => reaction.sample(3, () => ++n));
    expect(seen).toEqual([1, 1, 1, 2, 2, 2, 3]);
  });

  it("samples again at once after a reset", () => {
    const reaction = createReaction();
    let n = 0;
    reaction.sample(10, () => ++n);
    reaction.reset();
    expect(reaction.sample(10, () => ++n)).toBe(2);
  });
});

describe("aiRng", () => {
  it("is the random function the AI was handed", () => {
    const rng = () => 0.5;
    expect(aiRng({ rng }, 7)).toBe(rng);
  });

  it("falls back to the core's seeded generator, from the options' seed or its own", () => {
    const a = aiRng({ seed: 9 }, 7);
    const b = createRng(9).next;
    expect([a(), a(), a()]).toEqual([b(), b(), b()]);
    const c = aiRng({}, 7);
    const d = createRng(7).next;
    expect([c(), c()]).toEqual([d(), d()]);
  });
});

describe("angles", () => {
  it("normalizeAngle brings an angle into [0, 2π), and a non-number to 0", () => {
    expect(normalizeAngle(-Math.PI / 2)).toBeCloseTo((3 * Math.PI) / 2);
    expect(normalizeAngle(5 * Math.PI)).toBeCloseTo(Math.PI);
    expect(normalizeAngle(NaN)).toBe(0);
  });

  it("rotationDelta is the shortest signed turn from one heading to another", () => {
    expect(rotationDelta(0, Math.PI / 2)).toBeCloseTo(Math.PI / 2);
    expect(rotationDelta(0.1, 2 * Math.PI - 0.1)).toBeCloseTo(-0.2);
    expect(rotationDelta(2 * Math.PI - 0.1, 0.1)).toBeCloseTo(0.2);
    fc.assert(
      fc.property(
        fc.double({ min: -100, max: 100, noNaN: true }),
        fc.double({ min: -100, max: 100, noNaN: true }),
        (a, b) => {
          const d = rotationDelta(a, b);
          return d >= -Math.PI - 1e-9 && d <= Math.PI + 1e-9;
        },
      ),
    );
  });
});

describe("edgeAware", () => {
  const { clampX, edgeRisk, maybeApplyMistake } = edgeAware(400, 20);

  it("keeps a spot inside the margins", () => {
    expect(clampX(5)).toBe(20);
    expect(clampX(200)).toBe(200);
    expect(clampX(395)).toBe(380);
  });

  it("rates a spot riskier the deeper it is into twice the margin", () => {
    expect(edgeRisk(200)).toBe(0);
    expect(edgeRisk(40)).toBe(0);
    expect(edgeRisk(24)).toBe(2);
    expect(edgeRisk(376)).toBe(2);
  });

  it("slips sideways by the configured pixels when the odds say so", () => {
    const config = { mistakeOdds: 0.5, mistakePixels: 30 };
    const target = { x: 100, reason: "fish" };
    const draws =
      (...values) =>
      () =>
        values.shift();

    expect(maybeApplyMistake(target, config, draws(0.9))).toBe(target);
    expect(maybeApplyMistake(target, config, draws(0.1, 0.2))).toEqual({
      x: 70,
      reason: "mistake",
    });
    expect(maybeApplyMistake(target, config, draws(0.1, 0.8))).toEqual({
      x: 130,
      reason: "mistake",
    });
    expect(maybeApplyMistake({ x: 390 }, config, draws(0.1, 0.8)).x).toBe(380);
    expect(maybeApplyMistake(null, config, draws(0.1))).toBeNull();
  });
});

describe("finiteMotion", () => {
  it("holds when position and velocity under the prefix are all numbers", () => {
    expect(finiteMotion({ ballX: 1, ballY: 2, ballVX: 0, ballVY: -1 }, "ball")).toBe(true);
    expect(
      finiteMotion({ fireballX: 1, fireballY: 2, fireballVX: 3, fireballVY: 4 }, "fireball"),
    ).toBe(true);
  });

  it("fails on a missing state, a missing field or a non-finite one", () => {
    expect(finiteMotion(null, "ball")).toBe(false);
    expect(finiteMotion({ ballX: 1, ballY: 2, ballVX: 0 }, "ball")).toBe(false);
    expect(finiteMotion({ ballX: 1, ballY: NaN, ballVX: 0, ballVY: 0 }, "ball")).toBe(false);
  });
});
