import { vi } from "vitest";

import { createRng } from "../../../js/lib/games/core/rng.js";

/**
 * mulberry32: a small, well-mixed 32-bit generator (bryc's catalogue of JS
 * PRNGs) — the games' own `createRng`. The same seed always gives the same
 * sequence.
 * @param {number} seed
 * @returns {() => number} draws in [0, 1)
 */
export function mulberry32(seed) {
  return createRng(seed).next;
}

/**
 * Make `Math.random` follow `seed` until the spy is restored.
 * @param {number} seed
 */
export function seedRandom(seed) {
  return vi.spyOn(Math, "random").mockImplementation(mulberry32(seed));
}
