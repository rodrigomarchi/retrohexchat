/**
 * Binary protocol for Hex Outlaw game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/hex_outlaw_protocol
 */

import { schema, bool, custom, u8, u16 } from "../core/codec.js";
import { MSG_TYPE, ROUND_STANDING_FIELDS, ROUNDS_GAME_END, phases } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

/** px/frame (~480px/s at 60fps, crosses in ~75 frames ≈ 1.25s). */
export const BULLET_SPEED_X = 8;

/** The match's phases, by their value on the wire. */
export const PHASE = phases("SPAWNING", "PLAYING", "HIT_PAUSE", "ROUND_OVER", "MATCH_OVER");

// Game mode enum
export const GAME_MODE = {
  QUICK_DRAW: 0,
  RICOCHET: 1,
  STAGECOACH: 2,
  NO_MANS_LAND: 3,
};

/**
 * A bullet's velocity in two bytes: the horizontal sign, whether it bounced,
 * and the vertical speed. Its horizontal speed is always BULLET_SPEED_X.
 */
const bulletVelocity = (b) =>
  custom({
    spec: { kind: "custom", names: [`${b}vx`, `${b}vy`, `${b}bounced`] },
    size: () => 2,
    write(view, offset, s) {
      view.setUint16(offset, packBulletVel(s[`${b}vx`], s[`${b}vy`], s[`${b}bounced`]), true);
      return offset + 2;
    },
    read(view, offset, out) {
      if (offset + 2 > view.byteLength) return -1;
      const { vx, vy, bounced } = unpackBulletVel(view.getUint16(offset, true), BULLET_SPEED_X);
      out[`${b}vx`] = vx;
      out[`${b}vy`] = vy;
      out[`${b}bounced`] = bounced;
      return offset + 2;
    },
  });

/** A gunslinger: position and whether they are mid-shot. */
const gunslinger = (p) => [
  u16(`${p}x`, { round: true }),
  u16(`${p}y`, { round: true }),
  bool(`${p}shooting`),
];

/** A bullet: position (never negative), velocity and whether it is in flight. */
const bullet = (b) => [
  u16(`${b}x`, { clamp: [0, Infinity], round: true }),
  u16(`${b}y`, { clamp: [0, Infinity], round: true }),
  bulletVelocity(b),
  bool(`${b}active`),
];

/** The host's snapshot of the standoff, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  ...gunslinger("p1"),
  ...gunslinger("p2"),
  ...bullet("b1"),
  ...bullet("b2"),
  u16("obsY", { round: true }),
  u8("obsDir"),
  ...ROUND_STANDING_FIELDS,
  u8("gameMode"),
  u8("hitPauseTimer"),
  u8("lastHitPlayer"),
]);

/** How the match ended: the rounds' end of every match played in rounds. */
export const GAME_END = ROUNDS_GAME_END;

/**
 * Encode bullet velocity components into 2 bytes.
 * Stores sign of vx (1 bit), abs vy as uint15 (scaled by 10 for precision).
 * Since vx magnitude is constant (BULLET_SPEED_X), we only need its sign.
 * vy range: [-10..10] px/frame → stored as int scaled by 100 for precision.
 * @param {number} vx
 * @param {number} vy
 * @param {boolean} bounced
 * @returns {number} 16-bit packed value
 */
function packBulletVel(vx, vy, bounced) {
  // bit 15: vx sign (0=positive/right, 1=negative/left)
  // bit 14: bounced flag
  // bits 13-0: vy as signed value + 8192 offset (14-bit range)
  const vxSign = vx < 0 ? 1 : 0;
  const bouncedBit = bounced ? 1 : 0;
  const vyScaled = Math.round(vy * 100) + 8192;
  const clamped = Math.max(0, Math.min(16383, vyScaled));
  return (vxSign << 15) | (bouncedBit << 14) | (clamped & 0x3fff);
}

/**
 * Unpack bullet velocity from 2-byte packed value.
 * @param {number} packed
 * @param {number} bulletSpeedX - absolute bullet speed X
 * @returns {{ vxSign: number, vy: number, bounced: boolean }}
 */
function unpackBulletVel(packed, bulletSpeedX) {
  const vxSign = (packed >> 15) & 1;
  const bounced = ((packed >> 14) & 1) === 1;
  const vyRaw = packed & 0x3fff;
  const vy = (vyRaw - 8192) / 100;
  const vx = vxSign === 1 ? -bulletSpeedX : bulletSpeedX;
  return { vx, vy, bounced };
}
