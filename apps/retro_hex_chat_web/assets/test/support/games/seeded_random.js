import { vi } from "vitest";

/**
 * mulberry32: a small, well-mixed 32-bit generator (bryc's catalogue of JS
 * PRNGs). The same seed always gives the same sequence.
 * @param {number} seed
 * @returns {() => number} draws in [0, 1)
 */
export function mulberry32(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Make `Math.random` follow `seed` until the spy is restored.
 * @param {number} seed
 */
export function seedRandom(seed) {
  return vi.spyOn(Math, "random").mockImplementation(mulberry32(seed));
}
