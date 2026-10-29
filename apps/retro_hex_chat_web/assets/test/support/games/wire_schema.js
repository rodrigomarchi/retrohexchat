import { describe, expect, it } from "vitest";

import { hex } from "./channel_pair.js";

/**
 * A game's wire schema against the bytes the hand-written codec it replaced
 * wrote, so the wire a browser holding an older chunk speaks is the wire this
 * one speaks: every fixture's snapshot and end of match, byte for byte.
 * @param {string} game - the name the tests are listed under
 * @param {{ SNAPSHOT: object, GAME_END: object }} schema - the game's protocol
 * @param {{ snapshot: object[], gameEnd: object[] }} fixtures - `{ value, hex }` pairs
 */
export function describeWireSchema(game, { SNAPSHOT, GAME_END }, fixtures) {
  describe(`${game} wire schema`, () => {
    it.each(fixtures.snapshot)("writes the snapshot byte for byte (%#)", ({ value, hex: wire }) => {
      expect(hex(SNAPSHOT.encode(value))).toBe(wire);
    });

    it.each(fixtures.gameEnd)(
      "writes the end of the match byte for byte (%#)",
      ({ value, hex: wire }) => {
        expect(hex(GAME_END.encode(value))).toBe(wire);
      },
    );
  });
}
