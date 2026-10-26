/**
 * Binary protocol for Hex Invaders game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/hex_invaders_protocol
 */

import { schema, bool, custom, list, u8, u16, u32 } from "../core/codec.js";
import { MSG_TYPE } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

// Game phase enum
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  PLAYING: 2,
  WAVE_CLEAR: 3,
  WAVE_START: 4,
  FINISHED: 5,
};

// Game mode enum
export const GAME_MODE = {
  INVASION_WAR: 0,
  COOP: 1,
  BLITZ: 2,
};

// Alien type enum
export const ALIEN_TYPE = {
  NONE: 0,
  BASE: 1,
  MID: 2,
  TOP: 3,
  REINFORCEMENT: 4,
  ARMORED: 5,
};

// --- Entity limits ---
export const MAX_ALIENS = 36; // 30 grid + 6 reinforcement buffer per side
export const MAX_BOMBS = 8;
// ex_dna:disable-for-lines:10 this game's own wire fields
export const MAX_DROPS = 6;

/** A missile: position and whether it is in flight. */
const missile = (m) => [
  u16(`${m}X`, { round: true }),
  u16(`${m}Y`, { round: true }),
  bool(`${m}Active`),
];

/** One side's formation: every slot is written, those past the count as zeros. */
const aliens = (name, count) =>
  list(name, { capacity: MAX_ALIENS, fixed: true, count, trim: true }, [
    u8("type"),
    u16("x", { round: true }),
    u16("y", { round: true }),
  ]);

/** The four shields' health, one byte each. */
const shields = custom({
  spec: { kind: "custom", names: ["shields"] },
  size: () => 4,
  write(view, offset, s) {
    for (let i = 0; i < 4; i++) view.setUint8(offset + i, s.shields[i] || 0);
    return offset + 4;
  },
  read(view, offset, out) {
    if (offset + 4 > view.byteLength) return -1;
    out.shields = [0, 1, 2, 3].map((i) => view.getUint8(offset + i));
    return offset + 4;
  },
});

/** The host's snapshot of the invasion, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  u8("phase"),
  u8("wave"),
  u8("countdown"),
  u8("mode"),
  u32("seed"),
  u16("score1"),
  u16("score2"),
  u8("lives1"),
  u8("lives2"),
  u8("combo1Count"),
  u8("combo2Count"),
  u16("cannon1X", { round: true }),
  u16("cannon2X", { round: true }),
  ...missile("m1"),
  ...missile("m2"),
  aliens("aliens1", "alien1Count"),
  aliens("aliens2", "alien2Count"),
  u8("alien1Count", { clamp: [-Infinity, MAX_ALIENS] }),
  u8("alien2Count", { clamp: [-Infinity, MAX_ALIENS] }),
  bool("alien1DirRight"),
  bool("alien2DirRight"),
  list("bombs", { capacity: MAX_BOMBS, fixed: true, count: "bombCount", trim: true }, [
    u8("side"),
    u16("x", { round: true }),
    u16("y", { round: true }),
  ]),
  u8("bombCount", { clamp: [-Infinity, MAX_BOMBS] }),
  shields,
  u16("ufoX", { or: 0, round: true }),
  bool("ufoActive"),
  u8("ufoDir"),
  u8("dropCount", { from: (s) => Math.min((s.drops || []).length, MAX_DROPS) }),
  list("drops", { capacity: MAX_DROPS, fixed: true, trim: "dropCount" }, [
    u8("type"),
    u8("targetSide"),
    u8("timer"),
  ]),
]);

/** How the match ended; the scores go big-endian. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [
  u16("score1", { bigEndian: true }),
  u16("score2", { bigEndian: true }),
  u8("winner"),
]);
