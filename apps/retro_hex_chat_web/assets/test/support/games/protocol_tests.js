import { describe, expect, it } from "vitest";

/**
 * The checks the games' wire protocol tests share: a message written and
 * read back, its leading type byte, and the buffers a schema must refuse.
 */

/**
 * `value` written by `schema` and read back.
 * @param {{ encode: (value: object) => ArrayBuffer, decode: (buf: ArrayBuffer) => object|null }} schema
 * @param {object} value
 * @returns {object|null}
 */
export function roundTrip(schema, value) {
  return schema.decode(schema.encode(value));
}

/**
 * The type byte a message starts with.
 * @param {ArrayBuffer} buf
 * @returns {number}
 */
export function typeByte(buf) {
  return new DataView(buf).getUint8(0);
}

/**
 * A zeroed message `length` bytes long that starts with the type byte `type`.
 * @param {number} length
 * @param {number} type
 * @returns {ArrayBuffer}
 */
export function messageOfType(length, type) {
  const buf = new ArrayBuffer(length);
  new DataView(buf).setUint8(0, type);
  return buf;
}

/**
 * Each of `values`, put in field `key` of `make({ [key]: value })`, comes
 * back unchanged from a round trip.
 * @param {object} schema
 * @param {(overrides: object) => object} make
 * @param {string} key
 * @param {Iterable<unknown>} values
 */
export function expectEachRoundTrips(schema, make, key, values) {
  for (const value of values) {
    expect(roundTrip(schema, make({ [key]: value }))[key]).toBe(value);
  }
}

/**
 * `schema` reads nothing from a buffer of any of `lengths`, all shorter than
 * its message.
 * @param {object} schema
 * @param {...number} lengths
 */
export function expectRejectsShort(schema, ...lengths) {
  for (const length of lengths) expect(schema.decode(new ArrayBuffer(length))).toBeNull();
}

/**
 * `schema` reads nothing from a message of its full `length` that carries
 * another message's type byte.
 * @param {object} schema
 * @param {number} length
 * @param {number} wrongType
 */
export function expectRejectsType(schema, length, wrongType) {
  expect(schema.decode(messageOfType(length, wrongType))).toBeNull();
}

/**
 * The ready announcement is a single byte: its type.
 * @param {() => ArrayBuffer} encodeGameReady
 * @param {number} type - GAME_READY
 */
export function expectGameReady(encodeGameReady, type) {
  const buf = encodeGameReady();
  expect(buf.byteLength).toBe(1);
  expect(typeByte(buf)).toBe(type);
}

/**
 * Every message type sits in the games' range, 0x80 and up.
 * @param {Record<string, number>} MSG_TYPE
 */
export function expectGameMessageRange(MSG_TYPE) {
  for (const type of Object.values(MSG_TYPE)) expect(type).toBeGreaterThanOrEqual(0x80);
}

/**
 * Each listed field of `value` comes back from a round trip within 0.05.
 * @param {object} schema
 * @param {object} value
 * @param {string[]} keys
 */
export function expectCloseAfterRoundTrip(schema, value, keys) {
  const decoded = roundTrip(schema, value);
  for (const key of keys) expect(decoded[key]).toBeCloseTo(value[key], 1);
}

/**
 * Declares the framing tests of one message schema: with a `sample`, that it
 * writes `bytes` bytes and leads with the type byte `type`; with `short`,
 * that buffers of those lengths read as nothing; with `wrongType`, that a
 * full-length buffer (`length`) of that type reads as nothing.
 * @param {object} schema
 * @param {object} frame
 * @param {object} [frame.sample] - a value to write
 * @param {number} [frame.bytes]
 * @param {number} [frame.type]
 * @param {number[]} [frame.short]
 * @param {number} [frame.length]
 * @param {number} [frame.wrongType]
 */
export function itFramesMessages(schema, { sample, bytes, type, short, length, wrongType }) {
  if (sample && bytes !== undefined) {
    it(`produces exactly ${bytes} bytes`, () => {
      expect(schema.encode(sample).byteLength).toBe(bytes);
    });
  }
  if (sample && type !== undefined) {
    it(`sets type byte to 0x${type.toString(16)}`, () => {
      expect(typeByte(schema.encode(sample))).toBe(type);
    });
  }
  if (short) {
    it("returns null for buffer too small", () => expectRejectsShort(schema, ...short));
  }
  if (wrongType !== undefined) {
    it("returns null for wrong message type", () => expectRejectsType(schema, length, wrongType));
  }
}

/**
 * Declares a round-trip test for each listed field: every one of its values
 * comes back unchanged, in a state made by `make` with the field's `with`.
 * @param {object} schema
 * @param {(overrides: object) => object} make
 * @param {Record<string, unknown[] | { values: unknown[], with: object }>} fields
 */
export function itRoundTripsEach(schema, make, fields) {
  for (const [key, field] of Object.entries(fields)) {
    const { values, with: base = {} } = Array.isArray(field) ? { values: field } : field;
    it(`handles every ${key} value`, () => {
      expectEachRoundTrips(schema, (overrides) => make({ ...base, ...overrides }), key, values);
    });
  }
}

/**
 * Declares the tests of a game's handshake helpers: the one-byte ready
 * announcement, and getMessageType reading the leading type byte.
 * @param {{ encodeGameReady: () => ArrayBuffer, getMessageType: (buf: ArrayBuffer) => number|null, MSG_TYPE: Record<string, number> }} protocol
 */
export function describeHandshake({ encodeGameReady, getMessageType, MSG_TYPE }) {
  describe("GAME_READY", () => {
    it("produces 1 byte with type GAME_READY", () => {
      expectGameReady(encodeGameReady, MSG_TYPE.GAME_READY);
      expect(getMessageType(encodeGameReady())).toBe(MSG_TYPE.GAME_READY);
    });
  });

  describe("getMessageType", () => {
    it("reads the type byte at the head of a message", () => {
      expect(getMessageType(messageOfType(1, MSG_TYPE.GAME_STATE))).toBe(MSG_TYPE.GAME_STATE);
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });
  });
}

/**
 * The messages around a match that the duels — Pixel Tanks, Star Duel, Hex
 * Outlaw and Hex Boxing — check the same way: the end of the match written
 * and read back and framed, the handshake, and every message type in the
 * games' range.
 * @param {{ GAME_END: object, MSG_TYPE: Record<string, number>, encodeGameReady: () => ArrayBuffer, getMessageType: (buf: ArrayBuffer) => number|null }} protocol
 * @param {object} result - a finished match's end-of-match fields
 */
export function describeMatchMessages(protocol, result) {
  const { GAME_END, MSG_TYPE } = protocol;

  describe("game end encode/decode", () => {
    it("roundtrips a result", () => {
      expect(roundTrip(GAME_END, result)).toEqual(result);
    });

    itFramesMessages(GAME_END, {
      sample: result,
      type: MSG_TYPE.GAME_END,
      short: [0, 2],
      length: GAME_END.encode(result).byteLength,
      wrongType: MSG_TYPE.GAME_STATE,
    });
  });

  describeHandshake(protocol);

  it("keeps every message type in the games' range", () => {
    expectGameMessageRange(MSG_TYPE);
  });
}

/**
 * Declares the tests of a scored match's end with each score in two bytes —
 * Hex Invaders, Hex Raid and Hex Enduro: the scores (none, a byte's boundary,
 * the most two bytes hold) and the winner (none too) come back, it is six
 * bytes behind its type byte, and a short or mistyped buffer reads as nothing.
 * @param {{ GAME_END: object, MSG_TYPE: Record<string, number> }} protocol
 */
export function describeTwoByteScoreEnd({ GAME_END, MSG_TYPE }) {
  describe("GAME_END encode/decode", () => {
    it.each([
      [0, 0],
      [256, 255],
      [1240, 980],
      [65535, 65535],
    ])("round-trips scores %i and %i", (score1, score2) => {
      const decoded = roundTrip(GAME_END, { score1, score2, winner: 1 });
      expect([decoded.score1, decoded.score2]).toEqual([score1, score2]);
    });

    it.each([0, 1, 2])("round-trips winner %i", (winner) => {
      expect(roundTrip(GAME_END, { score1: 100, score2: 100, winner }).winner).toBe(winner);
    });

    itFramesMessages(GAME_END, {
      sample: { score1: 100, score2: 200, winner: 1 },
      bytes: 6,
      type: MSG_TYPE.GAME_END,
      short: [2, 3],
      length: 6,
      wrongType: MSG_TYPE.GAME_STATE,
    });
  });
}

/**
 * An enum's values are its names numbered from 0, in order, `count` of them.
 * @param {Record<string, number>} values
 * @param {number} count
 */
export function expectNumbered(values, count) {
  expect(Object.values(values)).toEqual([...Array(count).keys()]);
}

/**
 * The messages of a match whose snapshot carries its phase and mode and
 * whose end two-byte scores — Hex Invaders and Hex Enduro: the end
 * (`describeTwoByteScoreEnd`), the handshake, and every phase and mode
 * written and read back in a snapshot made by `make(overrides)`.
 * @param {{ SNAPSHOT: object, GAME_END: object, PHASE: object, GAME_MODE: object, MSG_TYPE: object, encodeGameReady: Function, getMessageType: Function }} protocol
 * @param {(overrides: object) => object} make
 */
export function describeModeMatchMessages(protocol, make) {
  describeTwoByteScoreEnd(protocol);
  describeHandshake(protocol);

  describe("GAME_STATE all phases round-trip", () => {
    itRoundTripsEach(protocol.SNAPSHOT, make, {
      phase: Object.values(protocol.PHASE),
      mode: Object.values(protocol.GAME_MODE),
    });
  });
}
