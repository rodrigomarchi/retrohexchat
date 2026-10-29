import { describe, expect, it } from "vitest";

const LEVELS = ["easy", "normal", "hard"];

/**
 * Declares the checks that an AI's difficulty table only ever gets stronger
 * from easy to hard: `stronger` names, for every column, the way it gets
 * stronger — "up" (more is stronger) or "down" — and each column must hold
 * still or move that way at every step. A switch counts as up when on.
 * @param {string} name - what the table is listed under
 * @param {Record<string, object>} table - the rows by difficulty
 * @param {Record<string, "up"|"down">} stronger
 */
export function describeStrengthOrder(name, table, stronger) {
  describe(`${name} difficulty table`, () => {
    it("names a direction for every column", () => {
      for (const level of LEVELS) {
        expect(Object.keys(table[level]).sort()).toEqual(Object.keys(stronger).sort());
      }
    });

    it.each(Object.entries(stronger))("never weakens %s from easy to hard", (column, way) => {
      const sign = way === "up" ? 1 : -1;
      const [easy, normal, hard] = LEVELS.map((level) => sign * Number(table[level][column]));
      expect(normal).toBeGreaterThanOrEqual(easy);
      expect(hard).toBeGreaterThanOrEqual(normal);
    });
  });
}
