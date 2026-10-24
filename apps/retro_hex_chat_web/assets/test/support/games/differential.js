import { expect } from "vitest";
import fc from "fast-check";
import { hex } from "./channel_pair.js";

/**
 * Require a new encoder to write exactly the bytes an old one writes, and the
 * new decoder to read back exactly what the old one reads, for every value
 * `arbitrary` generates.
 *
 * @param {object} pair
 * @param {fc.Arbitrary<object>} pair.arbitrary
 * @param {(value: object) => ArrayBuffer} pair.oldEncode
 * @param {(value: object) => ArrayBuffer} pair.newEncode
 * @param {(buf: ArrayBuffer) => unknown} pair.oldDecode
 * @param {(buf: ArrayBuffer) => unknown} pair.newDecode
 * @param {number} [pair.runs]
 */
export function expectSameWire({
  arbitrary,
  oldEncode,
  newEncode,
  oldDecode,
  newDecode,
  runs = 1000,
}) {
  fc.assert(
    fc.property(arbitrary, (value) => {
      const wire = oldEncode(value);
      expect(hex(newEncode(value))).toBe(hex(wire));
      expect(newDecode(wire)).toEqual(oldDecode(wire));
    }),
    { numRuns: runs },
  );
}
