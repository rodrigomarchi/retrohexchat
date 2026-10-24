import { describe, it, expect, afterEach, vi } from "vitest";
import { mulberry32, seedRandom } from "./seeded_random.js";

describe("seeded random", () => {
  afterEach(() => vi.restoreAllMocks());

  it("draws the published mulberry32 sequence for seed 1", () => {
    const next = mulberry32(1);
    expect([next(), next(), next()]).toEqual([
      0.6270739405881613, 0.002735721180215478, 0.5274470399599522,
    ]);
  });

  it("gives the same sequence to two generators with the same seed", () => {
    const a = mulberry32(42);
    const b = mulberry32(42);
    for (let i = 0; i < 100; i++) expect(a()).toBe(b());
  });

  it("stays in [0, 1)", () => {
    const next = mulberry32(7);
    for (let i = 0; i < 10_000; i++) {
      const value = next();
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(1);
    }
  });

  it("makes Math.random follow the seed until restored", () => {
    const expected = mulberry32(3);
    seedRandom(3);
    expect(Math.random()).toBe(expected());
    expect(Math.random()).toBe(expected());
    vi.restoreAllMocks();
    expect(Math.random).not.toHaveProperty("mock");
  });
});
