import { describe, it, expect } from "vitest";
import fc from "fast-check";
import { arbitraryFor } from "./arbitrary.js";
import { schema, u8, i16, bool, flags, list, struct } from "../../../js/lib/games/core/codec.js";

describe("arbitraryFor", () => {
  const msg = schema(1, [
    u8("phase"),
    i16("x", { scale: 10 }),
    bool("on"),
    flags(["a", "b"]),
    struct("p1", [u8("lives")]),
    list("xs", { capacity: 2, count: "n" }, [u8("v")]),
  ]);

  it("generates objects with every field the schema names", () => {
    fc.assert(
      fc.property(arbitraryFor(msg), (s) => {
        expect(Object.keys(s).sort()).toEqual(["a", "b", "n", "on", "p1", "phase", "x", "xs"]);
        expect(typeof s.p1.lives).toBe("number");
      }),
      { numRuns: 50 },
    );
  });

  it("uses an override for a field when given one", () => {
    fc.assert(
      fc.property(arbitraryFor(msg, { phase: fc.constant(3) }), (s) => s.phase === 3),
      { numRuns: 20 },
    );
  });

  it("generates values the schema encodes", () => {
    fc.assert(
      fc.property(arbitraryFor(msg), (s) => msg.encode(s).byteLength === msg.byteLength(s)),
      { numRuns: 100 },
    );
  });
});
