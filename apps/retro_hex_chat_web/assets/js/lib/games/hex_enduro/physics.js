/**
 * Pure physics / game logic for Hex Enduro.
 * All functions are side-effect-free: state -> state.
 * @module games/hex_enduro_physics
 */

import { PHASE, GAME_MODE, WEATHER, EVENT, MAX_AI_CARS, MAX_FUEL_STATIONS } from "./protocol.js";

// ── Canvas ──
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// ── Road geometry ──
export const HORIZON_Y = 150;
export const ROAD_BOTTOM_Y = 460;
export const ROAD_BOTTOM_WIDTH = 420;
export const ROAD_TOP_WIDTH = 16;
export const NUM_SEGMENTS = 60;

// ── Z-distance system ──
export const MAX_Z = 2000;
const COLLISION_ZONE = 40;
const PICKUP_ZONE = 50;
const OVERTAKE_ZONE = 30;

// ── Speed ──
export const SPEED_MIN = 0;
export const SPEED_MAX = 800;
export const SPEED_TURBO_MAX = 1000;
const ACCEL_RATE = 3;
const BRAKE_RATE = 8;
const DRAG_RATE = 1;
const COLLISION_PENALTY = 400;
export const COLLISION_TIMER_FRAMES = 60;
const COLLISION_MAX_SPEED = 300;
const EMPTY_FUEL_MAX_SPEED = 150;

// ── Lane ──
export const LANE_COUNT = 3;
const LANE_TRANSITION_SPEED = 20;
const LANE_TRANSITION_SNOW = 12;
const LANE_TRANSITION_MAX = 255;

// ── Fuel ──
export const FUEL_MAX = 1000;
const FUEL_DRAIN_BASE = 1;
const FUEL_DRAIN_TURBO = 3;
export const FUEL_STATION_REFILL = 300;
const FUEL_SPAWN_INTERVAL_MIN = 500;
const FUEL_SPAWN_INTERVAL_MAX = 900;

// ── Turbo ──
export const TURBO_DURATION = 180;
export const TURBO_COOLDOWN = 600;
export const TURBO_FUEL_COST = 150;

// ── Slipstream ──
const SLIPSTREAM_ZONE_Z = 200;
export const SLIPSTREAM_SPEED_BONUS = 50;

// ── AI Traffic ──
const AI_SPEED_MIN = 20;
const AI_SPEED_MAX = 60;
const AI_SPAWN_INTERVAL_BASE = 40;
const AI_SPAWN_INTERVAL_MIN = 15;

// ── Scoring ──
export const SCORE_AI_OVERTAKE = 1;
export const SCORE_PLAYER_OVERTAKE = 5;
export const SCORE_FUEL_PICKUP = 3;

// ── Weather durations (frames at 60fps) ──
// Day cycle: ~3.5 min = ~12600 frames
const WEATHER_DURATIONS = {
  [WEATHER.DAY]: 3150,
  [WEATHER.SNOW]: 2520,
  [WEATHER.FOG]: 2520,
  [WEATHER.NIGHT]: 2520,
  [WEATHER.DAWN]: 1890,
};
const WEATHER_SEQUENCE = [WEATHER.DAY, WEATHER.SNOW, WEATHER.FOG, WEATHER.NIGHT, WEATHER.DAWN];

// ── Day targets ──
const DAY_TARGETS = [200, 250, 300];
export const MAX_DAYS = 3;

// ── Timed modes ──
const NIGHT_RACE_DURATION = 10800; // 3 min at 60fps
const SPRINT_DURATION = 5400; // 90s at 60fps

// ── Speed modifiers by weather ──
const WEATHER_SPEED_MOD = {
  [WEATHER.DAY]: 1.0,
  [WEATHER.SNOW]: 0.85,
  [WEATHER.FOG]: 1.0,
  [WEATHER.NIGHT]: 0.95,
  [WEATHER.DAWN]: 1.0,
};

// ── Seeded PRNG (mulberry32) ──

/**
 * Create a seeded PRNG using mulberry32.
 * @param {number} seed - Uint32 seed
 * @returns {function(): number} Returns 0-1 float
 */
export function mulberry32(seed) {
  let s = seed | 0;
  return () => {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Get random int in [min, max] range from PRNG.
 */
function rngInt(rng, min, max) {
  return min + Math.floor(rng() * (max - min + 1));
}

// ── Initial State ──

/**
 * Create initial game state.
 * @param {number} mode - GAME_MODE enum
 * @param {number} seed - Uint32 seed for deterministic AI
 * @returns {object}
 */
export function createInitialState(mode, seed) {
  const weather = mode === GAME_MODE.NIGHT_RACE ? WEATHER.NIGHT : WEATHER.DAY;
  const weatherTimer = mode === GAME_MODE.CLASSIC_DUEL ? WEATHER_DURATIONS[WEATHER.DAY] : 0;

  let gameTimer = 0;
  if (mode === GAME_MODE.NIGHT_RACE) gameTimer = NIGHT_RACE_DURATION;
  if (mode === GAME_MODE.SPRINT) gameTimer = SPRINT_DURATION;

  return {
    phase: PHASE.WAITING,
    mode,
    seed,
    weather,
    weatherTimer,
    dayNumber: 1,
    countdown: 3,
    gameTimer,

    p1: createPlayerState(1),
    p2: createPlayerState(0),

    aiCars: [],
    aiSpawnTimer: AI_SPAWN_INTERVAL_BASE,

    fuelStations: [],
    fuelSpawnTimer: FUEL_SPAWN_INTERVAL_MAX,

    dayOvertakeTarget: DAY_TARGETS[0],
    events: 0,
    scrollOffset: 0,

    // Internal state not sent over protocol (host-only)
    _rngCounter: 0,
  };
}

function createPlayerState(lane) {
  return {
    lane,
    targetLane: lane,
    speed: 0,
    fuel: FUEL_MAX,
    overtakes: 0,
    score: 0,
    boost: 0,
    turboCooldown: 0,
    zOffset: 0,
    laneTransition: 0,
    collisionTimer: 0,
    slipstream: 0,
  };
}

// ── State Packing (for protocol) ──

/**
 * Pack game state into flat structure for protocol encoding.
 * @param {object} state
 * @returns {object} flat state
 */
export function packState(state) {
  return {
    phase: state.phase,
    mode: state.mode,
    weather: state.weather,
    weatherTimer: state.weatherTimer,
    dayNumber: state.dayNumber,
    countdown: state.countdown,
    seed: state.seed,
    gameTimer: state.gameTimer,

    p1Lane: state.p1.lane,
    p1Speed: state.p1.speed,
    p1Fuel: state.p1.fuel,
    p1Overtakes: state.p1.overtakes,
    p1Score: state.p1.score,
    p1Boost: state.p1.boost,
    p1ZOffset: state.p1.zOffset,
    p1LaneTransition: state.p1.laneTransition,
    p1CollisionTimer: state.p1.collisionTimer,

    p2Lane: state.p2.lane,
    p2Speed: state.p2.speed,
    p2Fuel: state.p2.fuel,
    p2Overtakes: state.p2.overtakes,
    p2Score: state.p2.score,
    p2Boost: state.p2.boost,
    p2ZOffset: state.p2.zOffset,
    p2LaneTransition: state.p2.laneTransition,
    p2CollisionTimer: state.p2.collisionTimer,

    aiCarCount: Math.min(state.aiCars.length, MAX_AI_CARS),
    aiCars: state.aiCars.slice(0, MAX_AI_CARS).map((car) => ({
      ...car,
      zPos: Math.max(0, Math.round(car.zPos)),
    })),

    fuelStationCount: Math.min(state.fuelStations.length, MAX_FUEL_STATIONS),
    fuelStations: state.fuelStations.slice(0, MAX_FUEL_STATIONS).map((fs) => ({
      ...fs,
      zPos: Math.max(0, Math.round(fs.zPos)),
    })),

    dayOvertakeTarget: state.dayOvertakeTarget,
    events: state.events,
    p1Slipstream: state.p1.slipstream,
    p2Slipstream: state.p2.slipstream,
  };
}

/**
 * Unpack flat protocol state back into nested structure for rendering.
 * @param {object} flat
 * @returns {object} nested state
 */
export function unpackState(flat) {
  return {
    phase: flat.phase,
    mode: flat.mode,
    weather: flat.weather,
    weatherTimer: flat.weatherTimer,
    dayNumber: flat.dayNumber,
    countdown: flat.countdown,
    seed: flat.seed,
    gameTimer: flat.gameTimer,

    p1: {
      lane: flat.p1Lane,
      speed: flat.p1Speed,
      fuel: flat.p1Fuel,
      overtakes: flat.p1Overtakes,
      score: flat.p1Score,
      boost: flat.p1Boost,
      zOffset: flat.p1ZOffset,
      laneTransition: flat.p1LaneTransition,
      collisionTimer: flat.p1CollisionTimer,
      slipstream: flat.p1Slipstream,
    },

    p2: {
      lane: flat.p2Lane,
      speed: flat.p2Speed,
      fuel: flat.p2Fuel,
      overtakes: flat.p2Overtakes,
      score: flat.p2Score,
      boost: flat.p2Boost,
      zOffset: flat.p2ZOffset,
      laneTransition: flat.p2LaneTransition,
      collisionTimer: flat.p2CollisionTimer,
      slipstream: flat.p2Slipstream,
    },

    aiCars: flat.aiCars,
    fuelStations: flat.fuelStations,
    dayOvertakeTarget: flat.dayOvertakeTarget,
    events: flat.events,
  };
}

// ── Lane Changing ──

/**
 * Request a lane change for a player.
 * @param {object} state
 * @param {string} playerKey - "p1" or "p2"
 * @param {number} direction - -1 (left) or +1 (right)
 * @returns {object}
 */
export function changeLane(state, playerKey, direction) {
  const p = state[playerKey];
  // Can't change lane while still transitioning
  if (p.lane !== p.targetLane) return state;

  const newLane = Math.max(0, Math.min(LANE_COUNT - 1, p.lane + direction));
  if (newLane === p.lane) return state;

  return {
    ...state,
    [playerKey]: { ...p, targetLane: newLane, laneTransition: 0 },
  };
}

/**
 * Update lane transition interpolation.
 * @param {object} state
 * @param {string} playerKey
 * @returns {object}
 */
export function updateLaneTransition(state, playerKey) {
  const p = state[playerKey];
  if (p.lane === p.targetLane) return state;

  const speed = state.weather === WEATHER.SNOW ? LANE_TRANSITION_SNOW : LANE_TRANSITION_SPEED;
  const newTransition = p.laneTransition + speed;

  if (newTransition >= LANE_TRANSITION_MAX) {
    return {
      ...state,
      [playerKey]: { ...p, lane: p.targetLane, laneTransition: 0 },
    };
  }

  return {
    ...state,
    [playerKey]: { ...p, laneTransition: newTransition },
  };
}

// ── Speed & Acceleration ──

/**
 * Get effective max speed for a player given current conditions.
 * @param {object} player
 * @param {number} weather
 * @returns {number}
 */
export function getEffectiveMaxSpeed(player, weather) {
  if (player.fuel <= 0) return EMPTY_FUEL_MAX_SPEED;
  if (player.collisionTimer > 0) return COLLISION_MAX_SPEED;

  const baseMax = player.boost > 0 ? SPEED_TURBO_MAX : SPEED_MAX;
  const weatherMod = WEATHER_SPEED_MOD[weather] || 1.0;
  const slipBonus = player.slipstream > 60 ? SLIPSTREAM_SPEED_BONUS : 0;

  return Math.round(baseMax * weatherMod) + slipBonus;
}

/**
 * Update player speed based on inputs.
 * @param {object} state
 * @param {string} playerKey
 * @param {object} inputs - {accel, brake}
 * @returns {object}
 */
export function updateSpeed(state, playerKey, inputs) {
  const p = state[playerKey];
  let speed = p.speed;
  const maxSpeed = getEffectiveMaxSpeed(p, state.weather);

  if (inputs.accel) {
    speed = Math.min(speed + ACCEL_RATE, maxSpeed);
  } else if (inputs.brake) {
    speed = Math.max(speed - BRAKE_RATE, SPEED_MIN);
  } else {
    speed = Math.max(speed - DRAG_RATE, SPEED_MIN);
  }

  // Clamp to current max (may have changed due to collision or fuel)
  speed = Math.min(speed, maxSpeed);

  return { ...state, [playerKey]: { ...p, speed } };
}

// ── Turbo Boost ──

/**
 * Attempt to activate turbo boost for a player.
 * @param {object} state
 * @param {string} playerKey
 * @returns {object}
 */
export function activateTurbo(state, playerKey) {
  const p = state[playerKey];
  if (p.boost > 0) return state;
  if (p.turboCooldown > 0) return state;
  if (p.fuel < TURBO_FUEL_COST) return state;
  // Sprint mode: no fuel cost
  const fuelCost = state.mode === GAME_MODE.SPRINT ? 0 : TURBO_FUEL_COST;

  return {
    ...state,
    [playerKey]: {
      ...p,
      boost: TURBO_DURATION,
      fuel: p.fuel - fuelCost,
      turboCooldown: TURBO_COOLDOWN,
    },
    events: state.events | EVENT.TURBO_ACTIVATE,
  };
}

// ── AI Traffic ──

/**
 * Get spawn interval based on day and weather.
 */
function getAISpawnInterval(dayNumber, weather) {
  const dayFactor = Math.max(0.5, 1 - (dayNumber - 1) * 0.15);
  let base = Math.round(AI_SPAWN_INTERVAL_BASE * dayFactor);
  // Fog: slightly fewer cars (appear suddenly so can't have too many)
  if (weather === WEATHER.FOG) base = Math.round(base * 1.3);
  return Math.max(AI_SPAWN_INTERVAL_MIN, base);
}

/**
 * Spawn and update AI cars.
 * @param {object} state
 * @returns {object}
 */
export function updateAICars(state) {
  const rng = mulberry32(state.seed + state._rngCounter);
  let aiCars = state.aiCars;

  // Move existing AI cars based on average player speed
  const avgSpeed = (state.p1.speed + state.p2.speed) / 2;
  aiCars = aiCars
    .map((car) => ({
      ...car,
      zPos: car.zPos - (avgSpeed - car.speed * 10) / 10,
    }))
    .filter((car) => car.zPos > -200 && car.zPos < MAX_Z + 200);

  // Spawn new AI car at horizon
  let spawnTimer = state.aiSpawnTimer - 1;
  if (spawnTimer <= 0 && aiCars.length < MAX_AI_CARS) {
    const lane = rngInt(rng, 0, LANE_COUNT - 1);
    const speed = rngInt(rng, AI_SPEED_MIN, AI_SPEED_MAX);
    const type = rngInt(rng, 0, 3);
    aiCars = [...aiCars, { lane, zPos: MAX_Z, speed, type }];
    spawnTimer = getAISpawnInterval(state.dayNumber, state.weather);
  }

  return {
    ...state,
    aiCars,
    aiSpawnTimer: spawnTimer,
    _rngCounter: state._rngCounter + 1,
  };
}

// ── Collision Detection ──

/**
 * Check collisions between players and AI cars.
 * @param {object} state
 * @returns {object}
 */
export function checkCollisions(state) {
  const s = { ...state, events: state.events };
  let p1 = { ...s.p1 };
  let p2 = { ...s.p2 };

  // Player vs AI cars
  for (const car of s.aiCars) {
    // P1 vs AI
    if (p1.collisionTimer <= 0 && car.lane === p1.lane && Math.abs(car.zPos) < COLLISION_ZONE) {
      p1 = {
        ...p1,
        speed: Math.max(0, p1.speed - COLLISION_PENALTY),
        collisionTimer: COLLISION_TIMER_FRAMES,
      };
      s.events |= EVENT.COLLISION;
    }
    // P2 vs AI
    if (p2.collisionTimer <= 0 && car.lane === p2.lane && Math.abs(car.zPos) < COLLISION_ZONE) {
      p2 = {
        ...p2,
        speed: Math.max(0, p2.speed - COLLISION_PENALTY),
        collisionTimer: COLLISION_TIMER_FRAMES,
      };
      s.events |= EVENT.COLLISION;
    }
  }

  // Player vs Player collision
  const relativeZ = Math.abs(p1.zOffset - p2.zOffset);
  if (
    p1.collisionTimer <= 0 &&
    p2.collisionTimer <= 0 &&
    p1.lane === p2.lane &&
    relativeZ < COLLISION_ZONE
  ) {
    // Faster player loses more speed
    const faster = p1.speed >= p2.speed ? "p1" : "p2";
    const penalty1 = faster === "p1" ? COLLISION_PENALTY : Math.round(COLLISION_PENALTY * 0.6);
    const penalty2 = faster === "p2" ? COLLISION_PENALTY : Math.round(COLLISION_PENALTY * 0.6);

    p1 = {
      ...p1,
      speed: Math.max(0, p1.speed - penalty1),
      collisionTimer: COLLISION_TIMER_FRAMES,
    };
    p2 = {
      ...p2,
      speed: Math.max(0, p2.speed - penalty2),
      collisionTimer: COLLISION_TIMER_FRAMES,
    };
    s.events |= EVENT.COLLISION;
  }

  return { ...s, p1, p2 };
}

// ── Overtake Detection ──

/**
 * Check AI car overtakes (car zPos crossing from positive to negative).
 * @param {object} state
 * @param {object} prevAiCars - previous frame's AI cars for comparison
 * @returns {object}
 */
export function checkOvertakes(state, prevAiCars) {
  const s = { ...state };
  let p1 = { ...s.p1 };
  let p2 = { ...s.p2 };

  for (const car of s.aiCars) {
    // Find matching previous car by approximate zPos
    const prev = prevAiCars.find(
      (pc) => pc.lane === car.lane && Math.abs(pc.zPos - car.zPos) < 100 && pc.zPos >= 0,
    );
    if (!prev) continue;
    if (car.zPos >= 0) continue;
    // Car just crossed behind — credit goes to faster player only
    const p1Faster = p1.speed > car.speed * 10;
    const p2Faster = p2.speed > car.speed * 10;
    if (p1Faster && p2Faster) {
      // Both faster: whoever is ahead gets credit
      if (p1.zOffset >= p2.zOffset) {
        p1 = { ...p1, overtakes: p1.overtakes + 1, score: p1.score + SCORE_AI_OVERTAKE };
      } else {
        p2 = { ...p2, overtakes: p2.overtakes + 1, score: p2.score + SCORE_AI_OVERTAKE };
      }
      s.events |= EVENT.OVERTAKE_AI;
    } else if (p1Faster) {
      p1 = { ...p1, overtakes: p1.overtakes + 1, score: p1.score + SCORE_AI_OVERTAKE };
      s.events |= EVENT.OVERTAKE_AI;
    } else if (p2Faster) {
      p2 = { ...p2, overtakes: p2.overtakes + 1, score: p2.score + SCORE_AI_OVERTAKE };
      s.events |= EVENT.OVERTAKE_AI;
    }
  }

  return { ...s, p1, p2 };
}

/**
 * Check player-vs-player overtake.
 * @param {object} state
 * @param {number} prevP1Z - previous p1 zOffset
 * @param {number} prevP2Z - previous p2 zOffset
 * @returns {object}
 */
export function checkPlayerOvertake(state, prevP1Z, prevP2Z) {
  let s = { ...state };
  const wasP1Ahead = prevP1Z > prevP2Z;
  const isP1Ahead = s.p1.zOffset > s.p2.zOffset;

  if (wasP1Ahead !== isP1Ahead && Math.abs(s.p1.zOffset - s.p2.zOffset) > OVERTAKE_ZONE) {
    if (isP1Ahead) {
      // P1 just overtook P2
      s = {
        ...s,
        p1: { ...s.p1, score: s.p1.score + SCORE_PLAYER_OVERTAKE },
        events: s.events | EVENT.OVERTAKE_PLAYER,
      };
    } else {
      // P2 just overtook P1
      s = {
        ...s,
        p2: { ...s.p2, score: s.p2.score + SCORE_PLAYER_OVERTAKE },
        events: s.events | EVENT.OVERTAKE_PLAYER,
      };
    }
  }

  return s;
}

// ── Fuel System ──

/**
 * Drain fuel based on speed and boost state.
 * @param {object} state
 * @param {string} playerKey
 * @returns {object}
 */
export function updateFuel(state, playerKey) {
  if (state.mode === GAME_MODE.SPRINT) return state;

  const p = state[playerKey];
  if (p.speed <= 0) return state; // no drain when stationary
  const drainRate =
    p.boost > 0 ? FUEL_DRAIN_TURBO : Math.max(FUEL_DRAIN_BASE, Math.floor(p.speed / 200));
  const newFuel = Math.max(0, p.fuel - drainRate);

  return { ...state, [playerKey]: { ...p, fuel: newFuel } };
}

/**
 * Spawn fuel stations on the road.
 * @param {object} state
 * @returns {object}
 */
export function spawnFuelStations(state) {
  if (state.mode === GAME_MODE.SPRINT) return state;

  let spawnTimer = state.fuelSpawnTimer - 1;
  if (spawnTimer <= 0 && state.fuelStations.length < MAX_FUEL_STATIONS) {
    const rng = mulberry32(state.seed + state._rngCounter + 9999);
    const lane = rngInt(rng, 0, LANE_COUNT - 1);
    const fuelStations = [...state.fuelStations, { lane, zPos: MAX_Z }];
    spawnTimer = rngInt(rng, FUEL_SPAWN_INTERVAL_MIN, FUEL_SPAWN_INTERVAL_MAX);
    return { ...state, fuelStations, fuelSpawnTimer: spawnTimer };
  }

  return { ...state, fuelSpawnTimer: spawnTimer };
}

function captureFuel(player) {
  return {
    ...player,
    fuel: Math.min(FUEL_MAX, player.fuel + FUEL_STATION_REFILL),
    score: player.score + SCORE_FUEL_PICKUP,
  };
}

/**
 * Move fuel stations toward players and check pickups.
 * @param {object} state
 * @returns {object}
 */
export function updateFuelStations(state) {
  if (state.mode === GAME_MODE.SPRINT) return state;

  const avgSpeed = (state.p1.speed + state.p2.speed) / 2;
  let p1 = { ...state.p1 };
  let p2 = { ...state.p2 };
  let events = state.events;

  const fuelStations = state.fuelStations
    .map((fs) => ({ ...fs, zPos: fs.zPos - avgSpeed / 10 }))
    .filter((fs) => {
      if (Math.abs(fs.zPos) < PICKUP_ZONE) {
        // Player ahead (higher zOffset) captures first — no P1 bias
        const p1InLane = p1.lane === fs.lane;
        const p2InLane = p2.lane === fs.lane;
        let captured = false;

        if (p1InLane && p2InLane) {
          // Both in lane: whoever is ahead gets it
          if (p1.zOffset >= p2.zOffset) {
            p1 = captureFuel(p1);
            events |= EVENT.FUEL_PICKUP;
          } else {
            p2 = captureFuel(p2);
            events |= EVENT.FUEL_PICKUP;
          }
          captured = true;
        } else if (p1InLane) {
          p1 = captureFuel(p1);
          events |= EVENT.FUEL_PICKUP;
          captured = true;
        } else if (p2InLane) {
          p2 = captureFuel(p2);
          events |= EVENT.FUEL_PICKUP;
          captured = true;
        }
        return !captured;
      }
      return fs.zPos > -200;
    });

  return { ...state, fuelStations, p1, p2, events };
}

// ── Slipstream ──

/**
 * Update slipstream state between players.
 * @param {object} state
 * @returns {object}
 */
export function updateSlipstream(state) {
  let p1 = { ...state.p1 };
  let p2 = { ...state.p2 };
  let events = state.events;

  const sameLane = p1.lane === p2.lane;
  const relativeZ = Math.abs(p1.zOffset - p2.zOffset);
  const closeEnough = relativeZ < SLIPSTREAM_ZONE_Z && relativeZ > COLLISION_ZONE;

  if (sameLane && closeEnough) {
    const p1Behind = p1.zOffset < p2.zOffset;
    if (p1Behind) {
      p1 = { ...p1, slipstream: Math.min(255, p1.slipstream + 2) };
      p2 = { ...p2, slipstream: 0 };
    } else {
      p2 = { ...p2, slipstream: Math.min(255, p2.slipstream + 2) };
      p1 = { ...p1, slipstream: 0 };
    }
    events |= EVENT.SLIPSTREAM;
  } else {
    p1 = { ...p1, slipstream: Math.max(0, p1.slipstream - 3) };
    p2 = { ...p2, slipstream: Math.max(0, p2.slipstream - 3) };
  }

  return { ...state, p1, p2, events };
}

// ── Weather System ──

/**
 * Update weather conditions.
 * @param {object} state
 * @returns {object}
 */
export function updateWeather(state) {
  // Night Race: permanent night, no transitions
  if (state.mode === GAME_MODE.NIGHT_RACE) return state;
  // Sprint: permanent day, no transitions
  if (state.mode === GAME_MODE.SPRINT) return state;

  const timer = state.weatherTimer - 1;
  if (timer <= 0) {
    const idx = WEATHER_SEQUENCE.indexOf(state.weather);
    const nextIdx = (idx + 1) % WEATHER_SEQUENCE.length;
    const nextWeather = WEATHER_SEQUENCE[nextIdx];

    // Completing DAWN -> starts new day
    const newDay = nextWeather === WEATHER.DAY ? state.dayNumber + 1 : state.dayNumber;
    const newTarget = newDay <= MAX_DAYS ? DAY_TARGETS[newDay - 1] : DAY_TARGETS[MAX_DAYS - 1];

    return {
      ...state,
      weather: nextWeather,
      weatherTimer: WEATHER_DURATIONS[nextWeather],
      dayNumber: newDay,
      dayOvertakeTarget: newTarget,
      events: state.events | EVENT.WEATHER_CHANGE,
    };
  }

  return { ...state, weatherTimer: timer };
}

// ── Z-Offset Tracking ──

/**
 * Update player z-offsets based on their speeds.
 * @param {object} state
 * @returns {object}
 */
export function updateZOffsets(state) {
  return {
    ...state,
    p1: { ...state.p1, zOffset: state.p1.zOffset + Math.round(state.p1.speed / 50) },
    p2: { ...state.p2, zOffset: state.p2.zOffset + Math.round(state.p2.speed / 50) },
  };
}

// ── Timers ──

/**
 * Tick down per-frame timers.
 * @param {object} state
 * @returns {object}
 */
export function tickTimers(state) {
  const p1 = { ...state.p1 };
  const p2 = { ...state.p2 };

  if (p1.boost > 0) p1.boost -= 1;
  if (p1.turboCooldown > 0) p1.turboCooldown -= 1;
  if (p1.collisionTimer > 0) p1.collisionTimer -= 1;

  if (p2.boost > 0) p2.boost -= 1;
  if (p2.turboCooldown > 0) p2.turboCooldown -= 1;
  if (p2.collisionTimer > 0) p2.collisionTimer -= 1;

  let gameTimer = state.gameTimer;
  if (
    (state.mode === GAME_MODE.NIGHT_RACE || state.mode === GAME_MODE.SPRINT) &&
    state.phase === PHASE.RACING
  ) {
    gameTimer = Math.max(0, gameTimer - 1);
  }

  // Scroll offset for road stripe animation
  const avgSpeed = (p1.speed + p2.speed) / 2;
  const scrollOffset = (state.scrollOffset + avgSpeed / 50) % 1000;

  return { ...state, p1, p2, gameTimer, scrollOffset };
}

// ── Game Over Conditions ──

/**
 * Check if game should end.
 * @param {object} state
 * @returns {object}
 */
export function checkGameOver(state) {
  if (state.phase !== PHASE.RACING) return state;

  // Classic: after 3 full days (dayNumber transitions past MAX_DAYS)
  if (state.mode === GAME_MODE.CLASSIC_DUEL && state.dayNumber > MAX_DAYS) {
    return { ...state, phase: PHASE.FINISHED, events: state.events | EVENT.DAY_END };
  }

  // Timed modes: timer reaches 0
  if (
    (state.mode === GAME_MODE.NIGHT_RACE || state.mode === GAME_MODE.SPRINT) &&
    state.gameTimer <= 0
  ) {
    return { ...state, phase: PHASE.FINISHED };
  }

  return state;
}

/**
 * Determine winner from final state.
 * @param {object} state
 * @returns {number} 0=draw, 1=P1 wins, 2=P2 wins
 */
export function determineWinner(state) {
  if (state.p1.score > state.p2.score) return 1;
  if (state.p2.score > state.p1.score) return 2;
  // Tiebreaker: more overtakes
  if (state.p1.overtakes > state.p2.overtakes) return 1;
  if (state.p2.overtakes > state.p1.overtakes) return 2;
  return 0; // draw
}

// ── Event Management ──

/**
 * Clear events bitmask at start of frame.
 * @param {object} state
 * @returns {object}
 */
export function clearEvents(state) {
  return { ...state, events: 0 };
}
