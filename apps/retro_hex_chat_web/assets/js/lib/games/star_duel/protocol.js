/**
 * Binary protocol for Star Duel space combat game over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 *
 * GAME_STATE is variable-length: 51 bytes header + 18 bytes per missile (max 6).
 * Ship rotation is encoded as Uint16 = rotation * 10000 (0-62831 for 0-2pi).
 * Ship flags pack 5 booleans into a single byte (bits 0-4).
 *
 * @module games/star_duel_protocol
 */

// Message types (shared with game_engine.js 0x80+ range)
import { schema, custom, f32, list, struct, u8, u16 } from "../core/codec.js";

export const MSG_TYPE = {
  GAME_STATE: 0x80,
  GAME_START: 0x82,
  GAME_END: 0x83,
  GAME_READY: 0x84,
};

// Shared by every game: the readiness ping and reading a message's type.
export { encodeGameReady, getMessageType } from "../net_protocol.js";

// Game phase enum
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  SPAWNING: 2,
  PLAYING: 3,
  ROUND_OVER: 4,
  FINISHED: 5,
};

// Game mode enum
export const GAME_MODE = {
  OPEN_SPACE: 0,
  GRAVITY_WELL: 1,
  DEBRIS_FIELD: 2,
};

// --- Limits ---
const MAX_MISSILES = 6;
// --- Rotation encoding ---
const ROTATION_SCALE = 10000;

/**
 * Encode ship flags into a single byte.
 * bit0=alive, bit1=thrustActive, bit2=exploding, bit3=warping, bit4=invulnerable
 * @param {object} flags
 * @param {boolean} flags.alive
 * @param {boolean} flags.thrustActive
 * @param {boolean} flags.exploding
 * @param {boolean} flags.warping
 * @param {boolean} flags.invulnerable
 * @returns {number}
 */
export function encodeShipFlags(flags) {
  let byte = 0;
  if (flags.alive) byte |= 1;
  if (flags.thrustActive) byte |= 2;
  if (flags.exploding) byte |= 4;
  if (flags.warping) byte |= 8;
  if (flags.invulnerable) byte |= 16;
  return byte;
}

/**
 * Decode ship flags from a single byte.
 * @param {number} byte
 * @returns {{alive: boolean, thrustActive: boolean, exploding: boolean, warping: boolean, invulnerable: boolean}}
 */
export function decodeShipFlags(byte) {
  return {
    alive: (byte & 1) !== 0,
    thrustActive: (byte & 2) !== 0,
    exploding: (byte & 4) !== 0,
    warping: (byte & 8) !== 0,
    invulnerable: (byte & 16) !== 0,
  };
}

const TWO_PI = Math.PI * 2;

/** A ship's five flags in one byte; the ship may carry them as that byte already. */
const shipFlags = custom({
  spec: { kind: "custom", names: ["flags"] },
  size: () => 1,
  write(view, offset, ship) {
    const flags = ship.flags;
    view.setUint8(offset, typeof flags === "number" ? flags : encodeShipFlags(flags));
    return offset + 1;
  },
  read(view, offset, out) {
    if (offset + 1 > view.byteLength) return -1;
    out.flags = decodeShipFlags(view.getUint8(offset));
    return offset + 1;
  },
});

/** A ship: position, velocity, heading (normalised to one turn) and flags. */
const ship = (name) =>
  struct(name, [
    f32("x"),
    f32("y"),
    f32("vx"),
    f32("vy"),
    u16("rotation", {
      encode: (r) => Math.round((((r % TWO_PI) + TWO_PI) % TWO_PI) * ROTATION_SCALE),
      decode: (raw) => raw / ROTATION_SCALE,
    }),
    shipFlags,
  ]);

/** The host's snapshot of the duel, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  ship("ship1"),
  ship("ship2"),
  u8("score1"),
  u8("score2"),
  u8("phase", { decode: (raw) => Math.min(raw, 5) }),
  u8("countdown"),
  u8("mode", { decode: (raw) => Math.min(raw, 2) }),
  u8("missileCount", { from: (s) => Math.min((s.missiles || []).length, MAX_MISSILES) }),
  u16("asteroidSeed"),
  u8("invuln1"),
  u8("invuln2"),
  u8("warpCooldown1"),
  u8("warpCooldown2"),
  list("missiles", { capacity: MAX_MISSILES, countFrom: "missileCount" }, [
    f32("x"),
    f32("y"),
    f32("vx", { or: 0 }),
    f32("vy", { or: 0 }),
    u8("owner"),
    u8("age"),
  ]),
]);

/** How the match ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [u8("score1"), u8("score2"), u8("winner")]);
