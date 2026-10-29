/**
 * Binary protocol for Hex Enduro game state over WebRTC DataChannel.
 * Each message is declared once as a schema on the core codec, which writes
 * and reads it from that one field list.
 * @module games/hex_enduro_protocol
 */

import { schema, bits, list, u8, u16, u32 } from "../core/codec.js";
import { MSG_TYPE, phases } from "../core/protocol_base.js";

export * from "../core/protocol_base.js";

/** The match's phases, by their value on the wire. */
export const PHASE = phases("RACING", "DAY_END", "FINISHED");

// Game mode enum
export const GAME_MODE = {
  CLASSIC_DUEL: 0,
  NIGHT_RACE: 1,
  SPRINT: 2,
};

// Weather condition enum
export const WEATHER = {
  DAY: 0,
  SNOW: 1,
  FOG: 2,
  NIGHT: 3,
  DAWN: 4,
};

// AI car type enum (visual variety)
export const CAR_TYPE = {
  SEDAN: 0,
  TRUCK: 1,
  SPORTS: 2,
  VAN: 3,
};

// Event flags bitmask
export const EVENT = {
  OVERTAKE_AI: 1 << 0,
  OVERTAKE_PLAYER: 1 << 1,
  COLLISION: 1 << 2,
  FUEL_PICKUP: 1 << 3,
  TURBO_ACTIVATE: 1 << 4,
  WEATHER_CHANGE: 1 << 5,
  DAY_END: 1 << 6,
  SLIPSTREAM: 1 << 7,
};

// --- Entity limits ---
export const MAX_AI_CARS = 20;
export const MAX_FUEL_STATIONS = 4;

/** A driver: lane, speed, fuel, overtakes, score, boost and where they are. */
const driver = (p) => [
  u8(`${p}Lane`),
  u16(`${p}Speed`),
  u16(`${p}Fuel`),
  u16(`${p}Overtakes`),
  u16(`${p}Score`),
  u8(`${p}Boost`),
  u16(`${p}ZOffset`),
  u8(`${p}LaneTransition`),
  u8(`${p}CollisionTimer`),
];

/** The host's snapshot of the race, sent every step. */
export const SNAPSHOT = schema(MSG_TYPE.GAME_STATE, [
  u8("phase"),
  u8("mode"),
  u8("weather"),
  u16("weatherTimer"),
  u8("dayNumber"),
  u8("countdown"),
  u32("seed"),
  u16("gameTimer"),
  ...driver("p1"),
  ...driver("p2"),
  u8("aiCarCount", {
    clamp: [-Infinity, MAX_AI_CARS],
    decode: (raw) => Math.min(raw, MAX_AI_CARS),
  }),
  list("aiCars", { capacity: MAX_AI_CARS, fixed: true, count: "aiCarCount", trim: true }, [
    bits([
      ["lane", 2],
      ["type", 2],
    ]),
    u16("zPos", { round: true }),
    u8("speed"),
  ]),
  u8("fuelStationCount", {
    clamp: [-Infinity, MAX_FUEL_STATIONS],
    decode: (raw) => Math.min(raw, MAX_FUEL_STATIONS),
  }),
  list(
    "fuelStations",
    { capacity: MAX_FUEL_STATIONS, fixed: true, count: "fuelStationCount", trim: true },
    [u8("lane"), u16("zPos", { round: true })],
  ),
  u16("dayOvertakeTarget"),
  u8("events"),
  u8("p1Slipstream"),
  u8("p2Slipstream"),
]);

/** How the race ended. */
export const GAME_END = schema(MSG_TYPE.GAME_END, [
  u16("score1", { or: 0 }),
  u16("score2", { or: 0 }),
  u8("winner", { or: 0, clamp: [-Infinity, 2], decode: (raw) => Math.min(raw, 2) }),
]);
