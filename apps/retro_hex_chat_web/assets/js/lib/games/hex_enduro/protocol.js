/**
 * Binary protocol for Hex Enduro game state over WebRTC DataChannel.
 * All messages use DataView for zero-JSON binary encoding.
 * @module games/hex_enduro_protocol
 */

// Message types (shared with game_engine.js 0x80+ range)
export const MSG_TYPE = {
  GAME_STATE: 0x80,
  PLAYER_INPUT: 0x81,
  GAME_START: 0x82,
  GAME_END: 0x83,
  GAME_READY: 0x84,
};

// Game phase enum
export const PHASE = {
  WAITING: 0,
  COUNTDOWN: 1,
  RACING: 2,
  DAY_END: 3,
  FINISHED: 4,
};

// Input key enum
export const INPUT_KEY = {
  LEFT: 0,
  RIGHT: 1,
  ACCEL: 2,
  BRAKE: 3,
  TURBO: 4,
};

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

// --- Sizes ---
// [type(1)] = 1
// Header: [phase(1)][mode(1)][weather(1)][weatherTimer(2)][dayNumber(1)][countdown(1)]
//         [seed(4)][gameTimer(2)] = 13
// Player1: [lane(1)][speed(2)][fuel(2)][overtakes(2)][score(2)][boost(1)][zOffset(2)]
//          [laneTransition(1)][collisionTimer(1)] = 14
// Player2: same = 14
// AI cars: [aiCarCount(1)] + MAX_AI_CARS × [lane(1)+type(1)][zPos(2)][speed(1)] = 1 + 20×4 = 81
// Fuel stations: [fuelStationCount(1)] + MAX_FUEL_STATIONS × [lane(1)][zPos(2)] = 1 + 4×3 = 13
// Day progress: [dayOvertakeTarget(2)] = 2
// Events: [events(1)] = 1
// Slipstream: [p1Slipstream(1)][p2Slipstream(1)] = 2
// Total: 1 + 13 + 14 + 14 + 81 + 13 + 2 + 1 + 2 = 141
const GAME_STATE_SIZE = 141;
const PLAYER_INPUT_SIZE = 3;
const GAME_END_SIZE = 6;
const GAME_READY_SIZE = 1;

/**
 * Encode full game state for host -> peer transmission.
 * @param {object} state
 * @returns {ArrayBuffer}
 */
export function encodeGameState(state) {
  const buf = new ArrayBuffer(GAME_STATE_SIZE);
  const view = new DataView(buf);
  let o = 0;

  // Message type
  view.setUint8(o, MSG_TYPE.GAME_STATE);
  o += 1;

  // Header
  view.setUint8(o, state.phase & 0xff);
  o += 1;
  view.setUint8(o, state.mode & 0xff);
  o += 1;
  view.setUint8(o, state.weather & 0xff);
  o += 1;
  view.setUint16(o, state.weatherTimer & 0xffff, true);
  o += 2;
  view.setUint8(o, state.dayNumber & 0xff);
  o += 1;
  view.setUint8(o, state.countdown & 0xff);
  o += 1;
  view.setUint32(o, state.seed >>> 0, true);
  o += 4;
  view.setUint16(o, state.gameTimer & 0xffff, true);
  o += 2;

  // Player 1
  view.setUint8(o, state.p1Lane & 0xff);
  o += 1;
  view.setUint16(o, state.p1Speed & 0xffff, true);
  o += 2;
  view.setUint16(o, state.p1Fuel & 0xffff, true);
  o += 2;
  view.setUint16(o, state.p1Overtakes & 0xffff, true);
  o += 2;
  view.setUint16(o, state.p1Score & 0xffff, true);
  o += 2;
  view.setUint8(o, state.p1Boost & 0xff);
  o += 1;
  view.setUint16(o, state.p1ZOffset & 0xffff, true);
  o += 2;
  view.setUint8(o, state.p1LaneTransition & 0xff);
  o += 1;
  view.setUint8(o, state.p1CollisionTimer & 0xff);
  o += 1;

  // Player 2
  view.setUint8(o, state.p2Lane & 0xff);
  o += 1;
  view.setUint16(o, state.p2Speed & 0xffff, true);
  o += 2;
  view.setUint16(o, state.p2Fuel & 0xffff, true);
  o += 2;
  view.setUint16(o, state.p2Overtakes & 0xffff, true);
  o += 2;
  view.setUint16(o, state.p2Score & 0xffff, true);
  o += 2;
  view.setUint8(o, state.p2Boost & 0xff);
  o += 1;
  view.setUint16(o, state.p2ZOffset & 0xffff, true);
  o += 2;
  view.setUint8(o, state.p2LaneTransition & 0xff);
  o += 1;
  view.setUint8(o, state.p2CollisionTimer & 0xff);
  o += 1;

  // AI cars
  const ac = Math.min(state.aiCarCount || 0, MAX_AI_CARS);
  view.setUint8(o, ac);
  o += 1;
  for (let i = 0; i < MAX_AI_CARS; i++) {
    if (i < ac && state.aiCars[i]) {
      const car = state.aiCars[i];
      view.setUint8(o, ((car.lane & 0x03) | ((car.type & 0x03) << 2)) & 0xff);
      view.setUint16(o + 1, Math.round(car.zPos) & 0xffff, true);
      view.setUint8(o + 3, car.speed & 0xff);
    } else {
      view.setUint8(o, 0);
      view.setUint16(o + 1, 0, true);
      view.setUint8(o + 3, 0);
    }
    o += 4;
  }

  // Fuel stations
  const fc = Math.min(state.fuelStationCount || 0, MAX_FUEL_STATIONS);
  view.setUint8(o, fc);
  o += 1;
  for (let i = 0; i < MAX_FUEL_STATIONS; i++) {
    if (i < fc && state.fuelStations[i]) {
      const fs = state.fuelStations[i];
      view.setUint8(o, fs.lane & 0xff);
      view.setUint16(o + 1, Math.round(fs.zPos) & 0xffff, true);
    } else {
      view.setUint8(o, 0);
      view.setUint16(o + 1, 0, true);
    }
    o += 3;
  }

  // Day progress
  view.setUint16(o, state.dayOvertakeTarget & 0xffff, true);
  o += 2;

  // Events
  view.setUint8(o, state.events & 0xff);
  o += 1;

  // Slipstream
  view.setUint8(o, state.p1Slipstream & 0xff);
  o += 1;
  view.setUint8(o, state.p2Slipstream & 0xff);

  return buf;
}

/**
 * Decode game state from binary buffer.
 * @param {ArrayBuffer} buf
 * @returns {object|null}
 */
export function decodeGameState(buf) {
  if (buf.byteLength < GAME_STATE_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== MSG_TYPE.GAME_STATE) return null;

  let o = 1;

  // Header
  const phase = view.getUint8(o);
  o += 1;
  const mode = view.getUint8(o);
  o += 1;
  const weather = view.getUint8(o);
  o += 1;
  const weatherTimer = view.getUint16(o, true);
  o += 2;
  const dayNumber = view.getUint8(o);
  o += 1;
  const countdown = view.getUint8(o);
  o += 1;
  const seed = view.getUint32(o, true);
  o += 4;
  const gameTimer = view.getUint16(o, true);
  o += 2;

  // Player 1
  const p1Lane = view.getUint8(o);
  o += 1;
  const p1Speed = view.getUint16(o, true);
  o += 2;
  const p1Fuel = view.getUint16(o, true);
  o += 2;
  const p1Overtakes = view.getUint16(o, true);
  o += 2;
  const p1Score = view.getUint16(o, true);
  o += 2;
  const p1Boost = view.getUint8(o);
  o += 1;
  const p1ZOffset = view.getUint16(o, true);
  o += 2;
  const p1LaneTransition = view.getUint8(o);
  o += 1;
  const p1CollisionTimer = view.getUint8(o);
  o += 1;

  // Player 2
  const p2Lane = view.getUint8(o);
  o += 1;
  const p2Speed = view.getUint16(o, true);
  o += 2;
  const p2Fuel = view.getUint16(o, true);
  o += 2;
  const p2Overtakes = view.getUint16(o, true);
  o += 2;
  const p2Score = view.getUint16(o, true);
  o += 2;
  const p2Boost = view.getUint8(o);
  o += 1;
  const p2ZOffset = view.getUint16(o, true);
  o += 2;
  const p2LaneTransition = view.getUint8(o);
  o += 1;
  const p2CollisionTimer = view.getUint8(o);
  o += 1;

  // AI cars (clamp to valid range for safety)
  const aiCarCount = Math.min(view.getUint8(o), MAX_AI_CARS);
  o += 1;
  const aiCars = [];
  for (let i = 0; i < MAX_AI_CARS; i++) {
    const packed = view.getUint8(o);
    aiCars.push({
      lane: packed & 0x03,
      type: (packed >> 2) & 0x03,
      zPos: view.getUint16(o + 1, true),
      speed: view.getUint8(o + 3),
    });
    o += 4;
  }

  // Fuel stations (clamp to valid range for safety)
  const fuelStationCount = Math.min(view.getUint8(o), MAX_FUEL_STATIONS);
  o += 1;
  const fuelStations = [];
  for (let i = 0; i < MAX_FUEL_STATIONS; i++) {
    fuelStations.push({
      lane: view.getUint8(o),
      zPos: view.getUint16(o + 1, true),
    });
    o += 3;
  }

  // Day progress
  const dayOvertakeTarget = view.getUint16(o, true);
  o += 2;

  // Events
  const events = view.getUint8(o);
  o += 1;

  // Slipstream
  const p1Slipstream = view.getUint8(o);
  o += 1;
  const p2Slipstream = view.getUint8(o);

  return {
    phase,
    mode,
    weather,
    weatherTimer,
    dayNumber,
    countdown,
    seed,
    gameTimer,
    p1Lane,
    p1Speed,
    p1Fuel,
    p1Overtakes,
    p1Score,
    p1Boost,
    p1ZOffset,
    p1LaneTransition,
    p1CollisionTimer,
    p2Lane,
    p2Speed,
    p2Fuel,
    p2Overtakes,
    p2Score,
    p2Boost,
    p2ZOffset,
    p2LaneTransition,
    p2CollisionTimer,
    aiCarCount,
    aiCars: aiCars.slice(0, aiCarCount),
    fuelStationCount,
    fuelStations: fuelStations.slice(0, fuelStationCount),
    dayOvertakeTarget,
    events,
    p1Slipstream,
    p2Slipstream,
  };
}

/**
 * Encode player input for peer -> host transmission.
 * Layout: [type(1)][keyCode(1)][pressed(1)]
 * @param {number} keyCode - INPUT_KEY enum value
 * @param {boolean} pressed
 * @returns {ArrayBuffer}
 */
export function encodePlayerInput(keyCode, pressed) {
  const buf = new ArrayBuffer(PLAYER_INPUT_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
  view.setUint8(1, keyCode);
  view.setUint8(2, pressed ? 1 : 0);
  return buf;
}

/**
 * Decode player input from binary buffer.
 * @param {ArrayBuffer} buf
 * @returns {object|null}
 */
export function decodePlayerInput(buf) {
  if (buf.byteLength < PLAYER_INPUT_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== MSG_TYPE.PLAYER_INPUT) return null;
  return {
    keyCode: view.getUint8(1),
    pressed: view.getUint8(2) === 1,
  };
}

/**
 * Encode game end for host -> peer transmission.
 * Layout: [type(1)][score1Hi(1)][score1Lo(1)][score2Hi(1)][score2Lo(1)][winner(1)]
 * @param {object} result
 * @returns {ArrayBuffer}
 */
export function encodeGameEnd(result) {
  const buf = new ArrayBuffer(GAME_END_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_END);
  view.setUint16(1, (result.score1 || 0) & 0xffff, true);
  view.setUint16(3, (result.score2 || 0) & 0xffff, true);
  view.setUint8(5, Math.min(result.winner || 0, 2));
  return buf;
}

/**
 * Decode game end from binary buffer.
 * @param {ArrayBuffer} buf
 * @returns {object|null}
 */
export function decodeGameEnd(buf) {
  if (buf.byteLength < GAME_END_SIZE) return null;
  const view = new DataView(buf);
  if (view.getUint8(0) !== MSG_TYPE.GAME_END) return null;
  return {
    score1: view.getUint16(1, true),
    score2: view.getUint16(3, true),
    winner: Math.min(view.getUint8(5), 2),
  };
}

/**
 * Encode game ready signal (peer -> host).
 * Layout: [type(1)]
 * @returns {ArrayBuffer}
 */
export function encodeGameReady() {
  const buf = new ArrayBuffer(GAME_READY_SIZE);
  const view = new DataView(buf);
  view.setUint8(0, MSG_TYPE.GAME_READY);
  return buf;
}

/**
 * Get message type from raw buffer.
 * @param {ArrayBuffer} buf
 * @returns {number|null}
 */
export function getMessageType(buf) {
  if (buf.byteLength < 1) return null;
  return new DataView(buf).getUint8(0);
}
