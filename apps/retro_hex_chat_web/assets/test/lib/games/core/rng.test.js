import fc from "fast-check";
import { describe, expect, it } from "vitest";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";

const draws = (next, n) => Array.from({ length: n }, () => next());

describe("createRng", () => {
  it("is mulberry32: the same seed draws the same sequence as the harness's", () => {
    expect(draws(createRng(1).next, 5)).toEqual(draws(mulberry32(1), 5));
    expect(draws(createRng(0xdeadbeef).next, 5)).toEqual(draws(mulberry32(0xdeadbeef), 5));
  });

  it("draws in [0, 1)", () => {
    for (const value of draws(createRng(7).next, 1000)) {
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });

  it("hands out next as a plain function, for code that takes a random function", () => {
    const { next } = createRng(3);
    expect(draws(next, 3)).toEqual(draws(mulberry32(3), 3));
  });

  it("keeps int within its bounds, both included, and range within [min, max)", () => {
    fc.assert(
      fc.property(
        fc.integer(),
        fc.integer({ min: -1000, max: 1000 }),
        fc.nat(1000),
        (seed, min, span) => {
          const rng = createRng(seed);
          const i = rng.int(min, min + span);
          const r = rng.range(min, min + span + 1);
          return (
            Number.isInteger(i) && i >= min && i <= min + span && r >= min && r < min + span + 1
          );
        },
      ),
    );
  });

  it("picks an item of the list", () => {
    const rng = createRng(11);
    const list = ["a", "b", "c"];
    for (let i = 0; i < 50; i++) expect(list).toContain(rng.pick(list));
  });

  it("forks a stream of its own, without moving the one it forked from", () => {
    const parent = createRng(5);
    const twin = createRng(5);
    const fx = parent.fork("fx");
    draws(fx.next, 10);

    expect(draws(parent.next, 5)).toEqual(draws(twin.next, 5));
  });

  it("forks the same stream for the same label at the same point, another for another label", () => {
    const a = createRng(9).fork("fx");
    const b = createRng(9).fork("fx");
    const c = createRng(9).fork("ai");
    const first = draws(a.next, 5);

    expect(draws(b.next, 5)).toEqual(first);
    expect(draws(c.next, 5)).not.toEqual(first);
  });
});
