import { describe, it, expect } from "vitest";
import {
  BASE_MSG,
  decodeInputEdge,
  decodeInputState,
  encodeInputEdge,
  encodeInputState,
  isNewerSeq,
  packInputs,
  unpackInputs,
} from "../../../js/lib/games/net_protocol.js";

const BITS = { up: 0, down: 1, fire: 2 };

describe("net_protocol", () => {
  it("round-trips an input mask", () => {
    const buf = encodeInputState(7, 0b101);
    expect(new DataView(buf).getUint8(0)).toBe(BASE_MSG.INPUT_STATE);
    expect(decodeInputState(buf)).toEqual({ seq: 7, mask: 0b101 });
  });

  it("round-trips a discrete command", () => {
    const buf = encodeInputEdge(9, 3);
    expect(new DataView(buf).getUint8(0)).toBe(BASE_MSG.INPUT_EDGE);
    expect(decodeInputEdge(buf)).toEqual({ seq: 9, code: 3 });
  });

  it("refuses a datagram of the wrong type or length", () => {
    expect(decodeInputState(encodeInputEdge(1, 1))).toBeNull();
    expect(decodeInputEdge(encodeInputState(1, 1))).toBeNull();
    expect(decodeInputState(new ArrayBuffer(2))).toBeNull();
  });

  it("packs and unpacks held inputs", () => {
    const mask = packInputs({ up: true, down: false, fire: true }, BITS);
    expect(mask).toBe(0b101);

    const target = {};
    unpackInputs(mask, BITS, target);
    expect(target).toEqual({ up: true, down: false, fire: true });
  });

  it("survives a full round trip through the wire", () => {
    const held = { up: false, down: true, fire: true };
    const decoded = decodeInputState(encodeInputState(1, packInputs(held, BITS)));
    expect(unpackInputs(decoded.mask, BITS, {})).toEqual(held);
  });

  describe("isNewerSeq", () => {
    it("accepts anything when nothing has been seen", () => {
      expect(isNewerSeq(0, null)).toBe(true);
      expect(isNewerSeq(500, undefined)).toBe(true);
    });

    it("accepts a newer sequence and rejects an older one", () => {
      expect(isNewerSeq(11, 10)).toBe(true);
      expect(isNewerSeq(9, 10)).toBe(false);
      expect(isNewerSeq(10, 10)).toBe(false);
    });

    it("keeps working across the 16-bit wrap", () => {
      // Unordered delivery plus a wrapping counter is exactly where a naive
      // comparison starts rejecting every datagram.
      expect(isNewerSeq(2, 65534)).toBe(true);
      expect(isNewerSeq(65534, 2)).toBe(false);
    });
  });
});
