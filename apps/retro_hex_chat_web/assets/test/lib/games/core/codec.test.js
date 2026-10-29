import { describe, it, expect } from "vitest";
import fc from "fast-check";
import {
  schema,
  u8,
  i8,
  u16,
  i16,
  u32,
  f32,
  bool,
  bits,
  flags,
  bitmap,
  list,
  struct,
  custom,
} from "../../../../js/lib/games/core/codec.js";

const bytes = (buf) => [...new Uint8Array(buf)];

describe("codec", () => {
  describe("the message type", () => {
    it("is the first byte, and decode refuses any other", () => {
      const msg = schema(0x80, [u8("a")]);
      expect(bytes(msg.encode({ a: 7 }))).toEqual([0x80, 7]);
      expect(msg.decode(new Uint8Array([0x81, 7]).buffer)).toBeNull();
      expect(msg.type).toBe(0x80);
    });
  });

  describe("integers", () => {
    it("write little-endian", () => {
      const msg = schema(1, [u16("a"), i16("b"), u32("c")]);
      expect(bytes(msg.encode({ a: 0x1234, b: -2, c: 0x01020304 }))).toEqual([
        1, 0x34, 0x12, 0xfe, 0xff, 0x04, 0x03, 0x02, 0x01,
      ]);
    });

    it("write big-endian when asked", () => {
      const msg = schema(1, [u16("score", { bigEndian: true })]);
      expect(bytes(msg.encode({ score: 0x1234 }))).toEqual([1, 0x12, 0x34]);
      expect(msg.decode(msg.encode({ score: 0x1234 }))).toEqual({ score: 0x1234 });
    });

    it("wrap around on overflow, as DataView does", () => {
      const msg = schema(1, [u8("a"), u16("b"), i8("c")]);
      expect(bytes(msg.encode({ a: 256 + 5, b: -1, c: 200 }))).toEqual([1, 5, 0xff, 0xff, 200]);
      expect(msg.decode(msg.encode({ a: 261, b: -1, c: 200 }))).toEqual({ a: 5, b: 65535, c: -56 });
    });

    it("treat a missing value as DataView does: integers 0, floats NaN", () => {
      const msg = schema(1, [u8("a"), u16("b"), f32("c")]);
      const wire = msg.encode({});
      expect(bytes(wire).slice(0, 4)).toEqual([1, 0, 0, 0]);
      expect(msg.decode(wire).c).toBeNaN();
    });

    it("round when asked, and truncate otherwise, as DataView does", () => {
      const msg = schema(1, [u16("rounded", { round: true }), u16("raw")]);
      expect(msg.decode(msg.encode({ rounded: 10.6, raw: 10.6 }))).toEqual({
        rounded: 11,
        raw: 10,
      });
    });

    it("scale: write round(value * scale), read value / scale", () => {
      const msg = schema(1, [i16("x", { scale: 10 }), u8("p", { scale: 255 })]);
      const wire = msg.encode({ x: -12.34, p: 0.5 });
      expect(bytes(wire)).toEqual([1, 0x85, 0xff, 128]);
      expect(msg.decode(wire)).toEqual({ x: -12.3, p: 128 / 255 });
    });

    it("or: write the fallback in place of anything falsy, as `value || fallback`", () => {
      const msg = schema(1, [i8("dir", { or: 1 }), i8("other", { or: 1 })]);
      expect(msg.decode(msg.encode({ dir: 0, other: -1 }))).toEqual({ dir: 1, other: -1 });
      expect(msg.decode(msg.encode({}))).toEqual({ dir: 1, other: 1 });
    });

    it("from: compute the value from the whole object", () => {
      const msg = schema(1, [u8("count", { from: (obj) => obj.items.length })]);
      expect(bytes(msg.encode({ items: [1, 2, 3] }))).toEqual([1, 3]);
    });

    it("encode and decode: transform on the way out and back", () => {
      const msg = schema(1, [
        u8("timer", { encode: (v) => Math.min(255, v >> 2), decode: (raw) => raw << 2 }),
        u8("phase", { decode: (raw) => Math.min(raw, 5) }),
      ]);
      expect(bytes(msg.encode({ timer: 40, phase: 9 }))).toEqual([1, 10, 9]);
      expect(msg.decode(msg.encode({ timer: 40, phase: 9 }))).toEqual({ timer: 40, phase: 5 });
    });

    it("clamp before writing, when asked", () => {
      const msg = schema(1, [u8("count", { clamp: [0, 36] })]);
      expect(msg.decode(msg.encode({ count: 50 }))).toEqual({ count: 36 });
    });
  });

  describe("floats", () => {
    it("write float32 little-endian and read back at float32 precision", () => {
      const msg = schema(1, [f32("x")]);
      expect(msg.decode(msg.encode({ x: 0.1 })).x).toBe(Math.fround(0.1));
    });
  });

  describe("bool", () => {
    it("writes 1 for anything truthy and 0 otherwise, and reads a boolean", () => {
      const msg = schema(1, [bool("a"), bool("b"), bool("c")]);
      expect(bytes(msg.encode({ a: true, b: 5, c: undefined }))).toEqual([1, 1, 1, 0]);
      expect(msg.decode(msg.encode({ a: true, b: 0 }))).toEqual({ a: true, b: false, c: false });
    });
  });

  describe("flags", () => {
    it("packs booleans into one byte, the first name in bit 0", () => {
      const msg = schema(1, [flags(["thrust", "shield", "dead"])]);
      expect(bytes(msg.encode({ thrust: true, dead: true }))).toEqual([1, 0b101]);
      expect(msg.decode(msg.encode({ shield: true }))).toEqual({
        thrust: false,
        shield: true,
        dead: false,
      });
    });
  });

  describe("bits", () => {
    it("packs small integers into one byte, the first in the lowest bits, each masked to its width", () => {
      const msg = schema(1, [
        bits([
          ["punch", 2],
          ["arm", 1],
        ]),
      ]);
      expect(bytes(msg.encode({ punch: 2, arm: 1 }))).toEqual([1, 0b110]);
      expect(bytes(msg.encode({ punch: 7, arm: 2 }))).toEqual([1, 0b011]);
      expect(msg.decode(msg.encode({ punch: 1, arm: 1 }))).toEqual({ punch: 1, arm: 1 });
    });
  });

  describe("bitmap", () => {
    it("packs an array of booleans, most significant bit first", () => {
      const msg = schema(1, [bitmap("alive", 10)]);
      const alive = [true, false, false, false, false, false, false, true, true, false];
      expect(bytes(msg.encode({ alive }))).toEqual([1, 0b10000001, 0b10000000]);
      expect(msg.decode(msg.encode({ alive })).alive).toEqual(alive);
    });
  });

  describe("bitmap of objects", () => {
    it("reads one key of each item when writing, and names the booleans read back", () => {
      const msg = schema(1, [bitmap("blocks", 3, { key: "alive", as: "blocksAlive" })]);
      const wire = msg.encode({ blocks: [{ alive: true }, undefined, { alive: true }] });
      expect(bytes(wire)).toEqual([1, 0b10100000]);
      expect(msg.decode(wire)).toEqual({ blocksAlive: [true, false, true] });
    });
  });

  describe("struct", () => {
    it("writes the fields of a nested object in order", () => {
      const msg = schema(1, [struct("p1", [u8("lives"), u16("score")]), u8("round")]);
      const state = { p1: { lives: 3, score: 500 }, round: 2 };
      expect(bytes(msg.encode(state))).toEqual([1, 3, 0xf4, 0x01, 2]);
      expect(msg.decode(msg.encode(state))).toEqual(state);
    });
  });

  describe("struct read back flat", () => {
    it("writes from the nested object and reads back as name + field", () => {
      const msg = schema(1, [struct("p1", [u8("x"), u8("dir")], { flat: true })]);
      const wire = msg.encode({ p1: { x: 4, dir: 2 } });
      expect(bytes(wire)).toEqual([1, 4, 2]);
      expect(msg.decode(wire)).toEqual({ p1x: 4, p1dir: 2 });
    });
  });

  describe("list", () => {
    const alien = [u8("type"), u16("x", { round: true })];

    it("fixed: always writes every slot, zeroing those past the count", () => {
      const msg = schema(1, [list("aliens", { capacity: 3, fixed: true, count: "n" }, alien)]);
      const wire = msg.encode({
        n: 1,
        aliens: [
          { type: 2, x: 10.4 },
          { type: 9, x: 9 },
        ],
      });
      expect(bytes(wire)).toEqual([1, 2, 10, 0, 0, 0, 0, 0, 0, 0]);
      expect(msg.decode(wire).aliens).toEqual([
        { type: 2, x: 10 },
        { type: 0, x: 0 },
        { type: 0, x: 0 },
      ]);
    });

    it("fixed with trim: decodes only `count` entries, even when the count comes later", () => {
      const msg = schema(1, [
        list("aliens", { capacity: 3, fixed: true, count: "n", trim: true }, [u8("type")]),
        u8("n", { clamp: [-Infinity, 3] }),
      ]);
      const wire = msg.encode({ n: 2, aliens: [{ type: 7 }, { type: 8 }, { type: 9 }] });
      expect(bytes(wire)).toEqual([1, 7, 8, 0, 2]);
      expect(msg.decode(wire)).toEqual({ aliens: [{ type: 7 }, { type: 8 }], n: 2 });
    });

    it("fixed with trim naming a field: that field cuts the list on the way back only", () => {
      const msg = schema(1, [
        u8("shown", { from: (obj) => Math.min(obj.drops.length, 2) }),
        list("drops", { capacity: 3, fixed: true, trim: "shown" }, [u8("t")]),
      ]);
      const wire = msg.encode({ drops: [{ t: 4 }, { t: 5 }, { t: 6 }] });
      expect(bytes(wire)).toEqual([1, 2, 4, 5, 6]);
      expect(msg.decode(wire)).toEqual({ shown: 2, drops: [{ t: 4 }, { t: 5 }] });
    });

    it("fixed without a count: writes the items it has, then zeros", () => {
      const msg = schema(1, [list("aliens", { capacity: 2, fixed: true }, alien)]);
      expect(bytes(msg.encode({ aliens: [{ type: 1, x: 1 }] }))).toEqual([1, 1, 1, 0, 0, 0, 0]);
    });

    it("variable: writes the count, then that many entries, capped at capacity", () => {
      const msg = schema(1, [list("fish", { capacity: 2 }, [u8("x")])]);
      const wire = msg.encode({ fish: [{ x: 5 }, { x: 6 }, { x: 7 }] });
      expect(bytes(wire)).toEqual([1, 2, 5, 6]);
      expect(msg.decode(wire)).toEqual({ fish: [{ x: 5 }, { x: 6 }] });
    });

    it("variable: refuses a message whose count is beyond the capacity", () => {
      const msg = schema(1, [list("fish", { capacity: 2 }, [u8("x")])]);
      expect(msg.decode(new Uint8Array([1, 3, 5, 6, 7]).buffer)).toBeNull();
    });

    it("countFrom: an earlier field carries the count, and the list has no prefix", () => {
      const msg = schema(1, [
        u8("n", { from: (obj) => Math.min(obj.xs.length, 2) }),
        u8("other"),
        list("xs", { capacity: 2, countFrom: "n" }, [u8("v")]),
      ]);
      const wire = msg.encode({ other: 9, xs: [{ v: 4 }, { v: 5 }, { v: 6 }] });
      expect(bytes(wire)).toEqual([1, 2, 9, 4, 5]);
      expect(msg.decode(wire)).toEqual({ n: 2, other: 9, xs: [{ v: 4 }, { v: 5 }] });
      expect(msg.decode(new Uint8Array([1, 3, 9, 4, 5, 6]).buffer)).toBeNull();
    });

    it("variable with a named count: reads it from the object and writes it back", () => {
      const msg = schema(1, [list("fish", { capacity: 4, count: "fishCount" }, [u8("x")])]);
      const wire = msg.encode({ fishCount: 1, fish: [{ x: 5 }, { x: 6 }] });
      expect(bytes(wire)).toEqual([1, 1, 5]);
      expect(msg.decode(wire)).toEqual({ fishCount: 1, fish: [{ x: 5 }] });
    });
  });

  describe("custom", () => {
    it("lets a game write a layout nothing else describes", () => {
      const pair = custom({
        size: () => 2,
        write: (view, offset, obj) => {
          view.setUint8(offset, obj.a);
          view.setUint8(offset + 1, obj.a * 2);
          return offset + 2;
        },
        read: (view, offset, out) => {
          out.a = view.getUint8(offset);
          return offset + 2;
        },
      });
      const msg = schema(1, [pair, u8("b")]);
      expect(bytes(msg.encode({ a: 3, b: 4 }))).toEqual([1, 3, 6, 4]);
      expect(msg.decode(msg.encode({ a: 3, b: 4 }))).toEqual({ a: 3, b: 4 });
    });
  });

  describe("decoding", () => {
    const msg = schema(1, [u8("n"), list("xs", { capacity: 8 }, [u16("x")])]);

    it("refuses a buffer that ends early", () => {
      const wire = msg.encode({ n: 1, xs: [{ x: 1 }, { x: 2 }] });
      expect(msg.decode(wire.slice(0, wire.byteLength - 1))).toBeNull();
      expect(msg.decode(new ArrayBuffer(0))).toBeNull();
    });

    it("decodeInto fills the object it is given and says whether it could", () => {
      const target = { kept: true };
      expect(msg.decodeInto(msg.encode({ n: 4, xs: [] }), target)).toBe(true);
      expect(target).toEqual({ kept: true, n: 4, xs: [] });
      expect(msg.decodeInto(new ArrayBuffer(1), target)).toBe(false);
    });

    it("byteLength is the length of what encode writes", () => {
      const state = { n: 1, xs: [{ x: 1 }, { x: 2 }, { x: 3 }] };
      expect(msg.byteLength(state)).toBe(msg.encode(state).byteLength);
    });
  });

  describe("introspection", () => {
    it("says what each field is, so tests can generate values for it", () => {
      const msg = schema(1, [
        u16("y", { round: true }),
        i16("x", { scale: 10 }),
        bool("on"),
        flags(["a", "b"]),
        bitmap("blocks", 4),
        struct("p1", [u8("lives")]),
        list("xs", { capacity: 2, fixed: true, count: "n" }, [f32("v")]),
      ]);

      // A number's spec: every option at its default unless named.
      const number = (kind, name, options = {}) => ({
        kind,
        name,
        round: false,
        scale: null,
        clamp: null,
        or: null,
        from: null,
        encode: null,
        decode: null,
        bigEndian: false,
        ...options,
      });

      expect(msg.fields.map((field) => field.spec)).toEqual([
        number("u16", "y", { round: true }),
        number("i16", "x", { scale: 10 }),
        { kind: "bool", name: "on" },
        { kind: "flags", names: ["a", "b"] },
        { kind: "bitmap", name: "blocks", count: 4, key: null, as: null },
        { kind: "struct", name: "p1", flat: false, fields: [number("u8", "lives")] },
        {
          kind: "list",
          name: "xs",
          capacity: 2,
          fixed: true,
          count: "n",
          countFrom: null,
          trim: false,
          fields: [number("f32", "v")],
        },
      ]);
    });
  });

  describe("properties", () => {
    const shape = schema(0x80, [
      u8("phase"),
      i16("x", { scale: 10 }),
      f32("speed"),
      bool("serving"),
      flags(["a", "b"]),
      bitmap("blocks", 12),
      struct("p1", [u8("lives"), u16("score")]),
      list("enemies", { capacity: 5 }, [u8("type"), i16("y")]),
      list("slots", { capacity: 3, fixed: true }, [u8("kind")]),
    ]);

    const state = fc.record({
      phase: fc.integer({ min: 0, max: 255 }),
      x: fc.integer({ min: -3000, max: 3000 }).map((n) => n / 10),
      speed: fc.float({ noNaN: true, noDefaultInfinity: true }).map(Math.fround),
      serving: fc.boolean(),
      a: fc.boolean(),
      b: fc.boolean(),
      blocks: fc.array(fc.boolean(), { minLength: 12, maxLength: 12 }),
      p1: fc.record({
        lives: fc.integer({ min: 0, max: 255 }),
        score: fc.integer({ min: 0, max: 65535 }),
      }),
      enemies: fc.array(
        fc.record({
          type: fc.integer({ min: 0, max: 255 }),
          y: fc.integer({ min: -32768, max: 32767 }),
        }),
        { maxLength: 5 },
      ),
      slots: fc.array(fc.record({ kind: fc.integer({ min: 0, max: 255 }) }), {
        minLength: 3,
        maxLength: 3,
      }),
    });

    it("decode(encode(state)) gives the state back, for any state in range", () => {
      fc.assert(
        fc.property(state, (s) => {
          const back = shape.decode(shape.encode(s));
          expect({ ...back, x: Math.round(back.x * 10) }).toEqual({
            ...s,
            x: Math.round(s.x * 10),
          });
        }),
      );
    });

    it("byteLength always matches encode", () => {
      fc.assert(fc.property(state, (s) => shape.byteLength(s) === shape.encode(s).byteLength));
    });

    it("decoding any bytes at all never throws", () => {
      fc.assert(
        fc.property(fc.uint8Array({ maxLength: 64 }), (raw) => {
          // Behind the right type byte, so the fields themselves are read.
          const buf = new Uint8Array([0x80, ...raw]).buffer;
          const decoded = shape.decode(buf);
          return decoded === null || typeof decoded === "object";
        }),
      );
    });
  });
});
