import { describe, it, expect } from "vitest";
import { SNAPSHOT, GAME_END } from "../../../../js/lib/games/hex_hockey/protocol.js";
import { hex } from "../../../support/games/channel_pair.js";
import fixtures from "./fixtures/wire.json";

// Bytes written by the hand-written codec this schema replaced, so the wire a
// browser holding an older chunk speaks is the wire this one speaks.
describe("Hex Hockey wire schema", () => {
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
