/**
 * Binary protocol for Hex Raid game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/hex_raid_protocol
 */

import { schema, bool, f32, flags, list, u8, u16, u32 } from "../core/codec.js";
import { MSG_TYPE } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

// Game phase enum
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  FLYING: 2,
  FINISHED: 5, // kept at 5 for protocol backward compat
};

// Game mode enum
export const GAME_MODE = {
  RIVER_DUEL: 0,
  PACIFIST: 1,
  BLITZ: 2,
};

// --- Entity limits ---
export const MAX_ENEMIES = 16;
export const MAX_FUEL = 3;
export const MAX_MINES = 4;

// Enemy type enum
export const ENEMY_TYPE = {
  NONE: 0,
  BOAT: 1,
  HELI: 2,
  JET: 3,
};

/** A jet: position, speed, fuel, lives and three flags. */
const jet = (j) => [
  u16(`${j}X`, { round: true }),
  u16(`${j}Y`, { round: true }),
  u8(`${j}Speed`),
  u8(`${j}Fuel`),
  u8(`${j}Lives`),
  flags([`${j}Alive`, `${j}Invuln`, `${j}Respawning`]),
];

/** A missile: position and whether it is in flight. */
const missile = (m) => [
  u16(`${m}X`, { round: true }),
  u16(`${m}Y`, { round: true }),
  bool(`${m}Active`),
];

/** The host's snapshot of the river, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  ...jet("jet1"),
  ...jet("jet2"),
  ...missile("m1"),
  ...missile("m2"),
  list("enemies", { capacity: MAX_ENEMIES, fixed: true, count: "enemyCount" }, [
    u8("type"),
    u16("x", { round: true }),
    u16("y", { round: true }),
    bool("alive"),
  ]),
  list("fuels", { capacity: MAX_FUEL, fixed: true, count: "fuelCount" }, [
    u16("x", { round: true }),
    u16("y", { round: true }),
    bool("available"),
  ]),
  list("mines", { capacity: MAX_MINES, fixed: true, count: "mineCount" }, [
    u16("x", { round: true }),
    u16("y", { round: true }),
    u8("owner"),
    bool("active"),
  ]),
  u16("bridgeY", { round: true }),
  u8("bridgeHp"),
  bool("bridgeActive"),
  u16("score1"),
  u16("score2"),
  u8("phase"),
  u8("countdown"),
  u8("section"),
  f32("scrollY"),
  u8("mode"),
  u32("seed"),
  u8("enemyCount", { clamp: [-Infinity, MAX_ENEMIES] }),
  u8("fuelCount", { clamp: [-Infinity, MAX_FUEL] }),
  u8("mineCount", { clamp: [-Infinity, MAX_MINES] }),
]);

/** How the match ended; the scores, alone among the games, go big-endian. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [
  u16("score1", { bigEndian: true }),
  u16("score2", { bigEndian: true }),
  u8("winner"),
]);
