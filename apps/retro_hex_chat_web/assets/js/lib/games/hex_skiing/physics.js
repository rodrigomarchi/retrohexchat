/**
 * Hex Skiing — Pure-function physics module.
 *
 * Top-down vertical scrolling descent. Two skiers race down the same
 * toxic mountain, dodging mutant trees and irradiated rocks, clearing
 * slalom gates, and outrunning an avalanche of radioactive debris.
 *
 * All functions are pure: (state, inputs) → newState.
 */

import { PHASE, GAME_MODE, SKIER_STATE, EVENT } from "./protocol.js";

// ── Canvas / world constants ───────────────────────────────────
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// Skier Y position on screen (fixed — world scrolls around them)
export const SKIER_SCREEN_Y = 380;

// ── Scroll / speed ─────────────────────────────────────────────
export const SCROLL_SPEED_BASE = 3.0; // px/frame when going straight
export const SCROLL_SPEED_LATERAL_LIGHT = 0.9; // multiplier
export const SCROLL_SPEED_LATERAL_HEAVY = 0.7;
export const SCROLL_SPEED_BOOST = 1.5;
export const LATERAL_THRESHOLD_LIGHT = 0.3; // |velX| fraction of max
export const LATERAL_THRESHOLD_HEAVY = 0.7;

// ── Lateral movement ───────────────────────────────────────────
export const LATERAL_ACCEL = 0.4; // px/frame² when key held
export const LATERAL_FRICTION = 0.88; // decel multiplier per frame
export const LATERAL_MAX = 5.0; // px/frame max lateral speed
export const ICE_FRICTION = 0.98; // almost no friction on ice

// ── Skier hitbox ───────────────────────────────────────────────
export const SKIER_W = 8;
export const SKIER_H = 12;

// ── Stun (collision recovery) ──────────────────────────────────
export const STUN_TREE = 90; // frames (~1.5s)
export const STUN_ROCK = 60; // frames (~1s)

// ── Boost ──────────────────────────────────────────────────────
export const BOOST_DURATION = 180; // frames (~3s)

// ── Ice patch ──────────────────────────────────────────────────
export const ICE_DURATION = 120; // frames (~2s)

// ── Blizzard ───────────────────────────────────────────────────
export const BLIZZARD_INTERVAL = 2700; // frames (~45s)
export const BLIZZARD_DURATION = 600; // frames (~10s)

// ── Obstacles ──────────────────────────────────────────────────
export const TREE_W = 10;
export const TREE_H = 14;
export const ROCK_W = 8;
export const ROCK_H = 8;
export const ICE_PATCH_W = 24;
export const ICE_PATCH_H = 16;

// Obstacle generation
export const CHUNK_SIZE = 600; // world-Y pixels per chunk
export const OBSTACLE_MARGIN = 30; // min px from edge

// ── Gates ──────────────────────────────────────────────────────
export const GATE_INTERVAL = 600; // world-Y between gates
export const GATE_BONUS = 2.0; // seconds subtracted from timer
export const GATE_H = 6; // hitbox height for clearing

// ── Avalanche ──────────────────────────────────────────────────
export const AVALANCHE_START_OFFSET = -100; // starts above viewport
export const AVALANCHE_ACCEL_INTERVAL = 1800; // frames (~30s) between speed bumps
export const AVALANCHE_ACCEL_AMOUNT = 0.15; // px/frame added each interval

// ── Course length ──────────────────────────────────────────────
export const COURSE_LENGTH = 18000; // world-Y for one run (~90s clean)

// ── Items ──────────────────────────────────────────────────────
export const ITEM_BOOST = 0;
export const ITEM_SPAWN_INTERVAL = 1800; // frames (~30s)
export const ITEM_W = 12;
export const ITEM_H = 12;

// ── Round difficulty presets ───────────────────────────────────
const DIFFICULTY = [
  {
    // Round 1
    treeDensity: 4,
    rockDensity: 0,
    iceDensity: 0,
    avalancheBase: 0.5,
    gateWidth: 80,
  },
  {
    // Round 2
    treeDensity: 6,
    rockDensity: 2,
    iceDensity: 0,
    avalancheBase: 0.8,
    gateWidth: 60,
  },
  {
    // Round 3
    treeDensity: 8,
    rockDensity: 3,
    iceDensity: 2,
    avalancheBase: 1.2,
    gateWidth: 40,
  },
];

// ── Seeded PRNG (mulberry32) ───────────────────────────────────
export function mulberry32(seed) {
  let s = seed | 0;
  return function () {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ── State creation ─────────────────────────────────────────────

/**
 * Create the initial game state.
 * @param {number} mode - GAME_MODE enum
 * @param {number} seed - Uint32 RNG seed
 * @returns {object}
 */
export function createInitialState(mode, seed) {
  const round = 0;
  const diff = DIFFICULTY[0];

  return {
    phase: PHASE.WAITING,
    mode,
    round,
    countdown: 3,
    seed,

    scrollY: 0,
    avalancheY: AVALANCHE_START_OFFSET,
    avalancheSpeed: mode === GAME_MODE.CLEAN_RUN ? 0 : diff.avalancheBase,
    avalancheAccelTimer: 0,

    blizzardActive: false,
    blizzardTimer: 0,
    blizzardCooldown: BLIZZARD_INTERVAL,

    // Player 1 (host — left start)
    p1: {
      x: CANVAS_W / 2 - 40,
      velX: 0,
      state: SKIER_STATE.SKIING,
      timer: 0,
      boostTimer: 0,
      iceTimer: 0,
      stunTimer: 0,
      distance: 0,
    },

    // Player 2 (peer — right start)
    p2: {
      x: CANVAS_W / 2 + 40,
      velX: 0,
      state: SKIER_STATE.SKIING,
      timer: 0,
      boostTimer: 0,
      iceTimer: 0,
      stunTimer: 0,
      distance: 0,
    },

    events: 0,
    p1RoundWins: 0,
    p2RoundWins: 0,

    // Generated obstacle chunks
    obstacles: [],
    nextChunkY: 0,

    // Gates
    gates: [],
    nextGateY: GATE_INTERVAL,
    gateWidth: diff.gateWidth,

    // Items
    items: [],
    itemSpawnTimer: ITEM_SPAWN_INTERVAL,

    // RNG instance
    _rng: mulberry32(seed),
    _difficulty: diff,

    // Frame counter for avalanche accel
    frameCount: 0,
  };
}

// ── Packing helpers (state ↔ flat object for protocol) ─────────

/**
 * Flatten nested state for binary encoding.
 */
export function packState(state) {
  return {
    phase: state.phase,
    mode: state.mode,
    round: state.round,
    countdown: state.countdown,
    seed: state.seed,
    scrollY: state.scrollY,
    avalancheY: state.avalancheY,
    avalancheSpeed: state.avalancheSpeed,
    blizzardActive: state.blizzardActive,
    blizzardTimer: state.blizzardTimer,
    p1X: state.p1.x,
    p1VelX: state.p1.velX,
    p1State: state.p1.state,
    p1Timer: state.p1.timer,
    p1BoostTimer: state.p1.boostTimer,
    p1IceTimer: state.p1.iceTimer,
    p1StunTimer: state.p1.stunTimer,
    p1Distance: state.p1.distance,
    p2X: state.p2.x,
    p2VelX: state.p2.velX,
    p2State: state.p2.state,
    p2Timer: state.p2.timer,
    p2BoostTimer: state.p2.boostTimer,
    p2IceTimer: state.p2.iceTimer,
    p2StunTimer: state.p2.stunTimer,
    p2Distance: state.p2.distance,
    events: state.events,
    p1RoundWins: state.p1RoundWins,
    p2RoundWins: state.p2RoundWins,
    gateCount: state.gates.length,
    gates: state.gates.map((g) => ({
      x: g.x,
      y: g.y,
      width: g.width,
      clearedP1: g.clearedP1,
      clearedP2: g.clearedP2,
    })),
    itemCount: state.items.length,
    items: state.items.map((it) => ({
      type: it.type,
      x: it.x,
      y: it.y,
      collected: it.collected,
    })),
  };
}

/**
 * Unpack a flat decoded object back to nested state (peer side).
 */
export function unpackState(flat) {
  return {
    phase: flat.phase,
    mode: flat.mode,
    round: flat.round,
    countdown: flat.countdown,
    seed: flat.seed,
    scrollY: flat.scrollY,
    avalancheY: flat.avalancheY,
    avalancheSpeed: flat.avalancheSpeed,
    blizzardActive: flat.blizzardActive,
    blizzardTimer: flat.blizzardTimer,
    p1: {
      x: flat.p1X,
      velX: flat.p1VelX,
      state: flat.p1State,
      timer: flat.p1Timer,
      boostTimer: flat.p1BoostTimer,
      iceTimer: flat.p1IceTimer,
      stunTimer: flat.p1StunTimer,
      distance: flat.p1Distance,
    },
    p2: {
      x: flat.p2X,
      velX: flat.p2VelX,
      state: flat.p2State,
      timer: flat.p2Timer,
      boostTimer: flat.p2BoostTimer,
      iceTimer: flat.p2IceTimer,
      stunTimer: flat.p2StunTimer,
      distance: flat.p2Distance,
    },
    events: flat.events,
    p1RoundWins: flat.p1RoundWins,
    p2RoundWins: flat.p2RoundWins,
    gates: flat.gates || [],
    items: flat.items || [],
  };
}

// ── Physics update functions ───────────────────────────────────

/**
 * Get effective scroll speed for a skier based on their lateral velocity.
 */
export function getScrollSpeed(player) {
  if (player.stunTimer > 0) return 0;

  const absVelX = Math.abs(player.velX);
  const lateralFrac = absVelX / LATERAL_MAX;
  let multiplier = 1.0;

  if (lateralFrac > LATERAL_THRESHOLD_HEAVY) {
    multiplier = SCROLL_SPEED_LATERAL_HEAVY;
  } else if (lateralFrac > LATERAL_THRESHOLD_LIGHT) {
    multiplier = SCROLL_SPEED_LATERAL_LIGHT;
  }

  if (player.boostTimer > 0) {
    multiplier *= SCROLL_SPEED_BOOST;
  }

  return SCROLL_SPEED_BASE * multiplier;
}

/**
 * Update a single skier's lateral position based on input.
 */
export function updateSkier(player, input) {
  const p = { ...player };

  // Stunned: no movement
  if (p.stunTimer > 0) {
    p.stunTimer--;
    if (p.stunTimer === 0) {
      p.state = SKIER_STATE.SKIING;
    }
    // Timer doesn't tick while stunned
    return p;
  }

  // Apply lateral input
  if (input.left && !input.right) {
    p.velX -= LATERAL_ACCEL;
  } else if (input.right && !input.left) {
    p.velX += LATERAL_ACCEL;
  }

  // Friction
  const friction = p.iceTimer > 0 ? ICE_FRICTION : LATERAL_FRICTION;
  p.velX *= friction;

  // Clamp
  if (p.velX > LATERAL_MAX) p.velX = LATERAL_MAX;
  if (p.velX < -LATERAL_MAX) p.velX = -LATERAL_MAX;
  if (Math.abs(p.velX) < 0.05) p.velX = 0;

  // Apply position
  p.x += p.velX;

  // Clamp to canvas bounds
  const halfW = SKIER_W / 2;
  if (p.x < halfW) {
    p.x = halfW;
    p.velX = 0;
  }
  if (p.x > CANVAS_W - halfW) {
    p.x = CANVAS_W - halfW;
    p.velX = 0;
  }

  // Tick timers
  if (p.boostTimer > 0) {
    p.boostTimer--;
    if (p.boostTimer === 0) p.state = SKIER_STATE.SKIING;
  }
  if (p.iceTimer > 0) {
    p.iceTimer--;
  }

  // Advance timer (time in seconds at 60fps)
  const speed = getScrollSpeed(p);
  if (speed > 0) {
    p.timer += 1 / 60;
  }

  // Advance distance
  p.distance += speed;

  return p;
}

/**
 * Generate obstacles for a chunk of terrain.
 */
export function generateChunk(rng, chunkY, difficulty) {
  const obstacles = [];
  const { treeDensity, rockDensity, iceDensity } = difficulty;

  // Trees
  for (let i = 0; i < treeDensity; i++) {
    obstacles.push({
      type: "tree",
      x: OBSTACLE_MARGIN + rng() * (CANVAS_W - 2 * OBSTACLE_MARGIN),
      y: chunkY + rng() * CHUNK_SIZE,
      w: TREE_W,
      h: TREE_H,
    });
  }

  // Rocks
  for (let i = 0; i < rockDensity; i++) {
    obstacles.push({
      type: "rock",
      x: OBSTACLE_MARGIN + rng() * (CANVAS_W - 2 * OBSTACLE_MARGIN),
      y: chunkY + rng() * CHUNK_SIZE,
      w: ROCK_W,
      h: ROCK_H,
    });
  }

  // Ice patches
  for (let i = 0; i < iceDensity; i++) {
    obstacles.push({
      type: "ice",
      x: OBSTACLE_MARGIN + rng() * (CANVAS_W - 2 * OBSTACLE_MARGIN),
      y: chunkY + rng() * CHUNK_SIZE,
      w: ICE_PATCH_W,
      h: ICE_PATCH_H,
    });
  }

  return obstacles;
}

/**
 * Ensure enough obstacle chunks exist ahead of the scroll position.
 */
export function ensureChunks(state) {
  const lookAhead = state.scrollY + CANVAS_H + CHUNK_SIZE;
  if (state.nextChunkY >= lookAhead) return state;

  const newObstacles = [...state.obstacles];
  let nextY = state.nextChunkY;

  while (nextY < lookAhead) {
    const chunk = generateChunk(state._rng, nextY, state._difficulty);
    newObstacles.push(...chunk);
    nextY += CHUNK_SIZE;
  }

  // Remove obstacles that are far behind
  const cullY = state.scrollY - CHUNK_SIZE;
  const filtered = newObstacles.filter((o) => o.y > cullY);

  return { ...state, obstacles: filtered, nextChunkY: nextY };
}

/**
 * Generate a slalom gate if needed.
 */
export function ensureGates(state) {
  const lookAhead = state.scrollY + CANVAS_H;
  if (lookAhead < state.nextGateY) return state;

  const s = { ...state, gates: [...state.gates] };
  let nextY = s.nextGateY;

  while (nextY <= lookAhead) {
    const gateX = OBSTACLE_MARGIN + s._rng() * (CANVAS_W - 2 * OBSTACLE_MARGIN - s.gateWidth);
    s.gates.push({
      x: gateX,
      y: nextY,
      width: s.gateWidth,
      clearedP1: false,
      clearedP2: false,
    });
    nextY += GATE_INTERVAL;
  }

  // Cull old gates
  const cullY = s.scrollY - CHUNK_SIZE;
  s.gates = s.gates.filter((g) => g.y > cullY);
  s.nextGateY = nextY;

  return s;
}

/**
 * Spawn items on the course.
 */
export function updateItems(state) {
  if (state.mode === GAME_MODE.CLEAN_RUN) return state;

  const s = { ...state, items: [...state.items] };

  // Spawn timer
  s.itemSpawnTimer--;
  if (s.itemSpawnTimer <= 0) {
    s.itemSpawnTimer = ITEM_SPAWN_INTERVAL;
    const x = OBSTACLE_MARGIN + s._rng() * (CANVAS_W - 2 * OBSTACLE_MARGIN);
    const y = s.scrollY + CANVAS_H + 50; // spawn just below viewport
    s.items.push({ type: ITEM_BOOST, x, y, collected: 0 });
  }

  // Cull old items (keep collected items for one broadcast cycle)
  const cullY = s.scrollY - CHUNK_SIZE;
  s.items = s.items.filter((it) => it.y > cullY);

  return s;
}

/**
 * Check AABB collision between skier and an obstacle.
 */
function aabb(ax, ay, aw, ah, bx, by, bw, bh) {
  return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
}

/**
 * Check collisions for both skiers against all obstacles and items.
 * Returns updated state with events bitmask set.
 */
export function checkCollisions(state) {
  const s = { ...state };
  let events = s.events;

  const skierY = s.scrollY + SKIER_SCREEN_Y;

  for (const key of ["p1", "p2"]) {
    const player = { ...s[key] };
    if (player.stunTimer > 0) {
      s[key] = player;
      continue;
    }

    const sx = player.x - SKIER_W / 2;
    const sy = skierY - SKIER_H / 2;

    // Obstacle collisions
    for (const obs of s.obstacles) {
      const ox = obs.x - obs.w / 2;
      const oy = obs.y - obs.h / 2;

      if (aabb(sx, sy, SKIER_W, SKIER_H, ox, oy, obs.w, obs.h)) {
        if (obs.type === "tree") {
          player.stunTimer = STUN_TREE;
          player.state = SKIER_STATE.CRASHED;
          player.velX = 0;
          events |= EVENT.COLLISION_TREE;
        } else if (obs.type === "rock") {
          player.stunTimer = STUN_ROCK;
          player.state = SKIER_STATE.CRASHED;
          player.velX = 0;
          events |= EVENT.COLLISION_ROCK;
        } else if (obs.type === "ice" && player.iceTimer === 0) {
          player.iceTimer = ICE_DURATION;
          events |= EVENT.ICE_PATCH;
        }
      }
    }

    // Item collisions
    for (let i = 0; i < s.items.length; i++) {
      const it = s.items[i];
      if (it.collected !== 0) continue;
      const ix = it.x - ITEM_W / 2;
      const iy = it.y - ITEM_H / 2;
      if (aabb(sx, sy, SKIER_W, SKIER_H, ix, iy, ITEM_W, ITEM_H)) {
        s.items = [...s.items];
        s.items[i] = { ...it, collected: key === "p1" ? 1 : 2 };
        if (it.type === ITEM_BOOST) {
          player.boostTimer = BOOST_DURATION;
          player.state = SKIER_STATE.BOOSTED;
          events |= EVENT.SPEED_BOOST;
        }
      }
    }

    s[key] = player;
  }

  s.events = events;
  return s;
}

/**
 * Check if skiers pass through slalom gates.
 */
export function checkGates(state) {
  let s = { ...state };
  let events = s.events;
  const skierY = s.scrollY + SKIER_SCREEN_Y;

  const newGates = s.gates.map((g) => {
    const gate = { ...g };
    const gateTop = g.y - GATE_H / 2;
    const gateBot = g.y + GATE_H / 2;

    for (const key of ["p1", "p2"]) {
      const cleared = key === "p1" ? "clearedP1" : "clearedP2";
      if (gate[cleared]) continue;

      const player = s[key];
      const py = skierY;

      if (py >= gateTop && py <= gateBot) {
        const px = player.x;
        if (px >= gate.x && px <= gate.x + gate.width) {
          gate[cleared] = true;
          // Subtract gate bonus from timer
          s = {
            ...s,
            [key]: { ...s[key], timer: Math.max(0, s[key].timer - GATE_BONUS) },
          };
          events |= EVENT.GATE_CLEARED;
        }
      }
    }
    return gate;
  });

  return { ...s, gates: newGates, events };
}

/**
 * Update the avalanche position.
 */
export function updateAvalanche(state) {
  if (state.mode === GAME_MODE.CLEAN_RUN) return state;

  const s = { ...state };

  // The avalanche follows the scroll but at its own pace
  s.avalancheY += s.avalancheSpeed;

  // Accelerate over time
  s.avalancheAccelTimer++;
  if (s.avalancheAccelTimer >= AVALANCHE_ACCEL_INTERVAL) {
    s.avalancheAccelTimer = 0;
    s.avalancheSpeed += AVALANCHE_ACCEL_AMOUNT;
  }

  let events = s.events;

  // Avalanche screen position relative to the viewport
  const avalancheScreenY = s.avalancheY - s.scrollY;
  if (avalancheScreenY >= SKIER_SCREEN_Y - SKIER_H / 2) {
    events |= EVENT.ENGULFED;
  }

  s.events = events;
  return s;
}

/**
 * Update blizzard cycle.
 */
export function updateBlizzard(state) {
  if (state.mode === GAME_MODE.CLEAN_RUN) return state;

  const s = { ...state };

  if (s.blizzardActive) {
    s.blizzardTimer--;
    if (s.blizzardTimer <= 0) {
      s.blizzardActive = false;
      s.blizzardCooldown = BLIZZARD_INTERVAL;
      s.events |= EVENT.BLIZZARD_END;
    }
  } else {
    s.blizzardCooldown--;
    if (s.blizzardCooldown <= 0) {
      s.blizzardActive = true;
      s.blizzardTimer = BLIZZARD_DURATION;
      s.events |= EVENT.BLIZZARD_START;
    }
  }

  return s;
}

/**
 * Update scroll position based on the faster skier's speed.
 */
export function updateScroll(state) {
  const speed1 = getScrollSpeed(state.p1);
  const speed2 = getScrollSpeed(state.p2);
  // Scroll follows the faster skier
  const scrollSpeed = Math.max(speed1, speed2);
  return { ...state, scrollY: state.scrollY + scrollSpeed };
}

/**
 * Check for round/game end conditions.
 */
export function checkGameOver(state) {
  const s = { ...state };

  // Check avalanche engulf
  const avalancheScreenY = s.avalancheY - s.scrollY;
  const p1Engulfed = s.mode !== GAME_MODE.CLEAN_RUN && avalancheScreenY >= SKIER_SCREEN_Y - SKIER_H;
  const p2Engulfed = p1Engulfed; // Same avalanche position for both

  // In escape mode: individual engulf check based on stunTimer
  // Both get engulfed at same screen pos, but stunned player is "behind"
  let p1Out = false;
  let p2Out = false;

  if (p1Engulfed) {
    // If a player is stunned when avalanche arrives, they're engulfed
    if (s.p1.stunTimer > 0) p1Out = true;
    // If avalanche is well past skier position
    if (avalancheScreenY >= SKIER_SCREEN_Y + SKIER_H) p1Out = true;
  }
  if (p2Engulfed) {
    if (s.p2.stunTimer > 0) p2Out = true;
    if (avalancheScreenY >= SKIER_SCREEN_Y + SKIER_H) p2Out = true;
  }

  // Course completion (not in escape mode)
  if (s.mode !== GAME_MODE.AVALANCHE_ESCAPE) {
    const courseEnd = COURSE_LENGTH;
    const p1Finished = s.p1.distance >= courseEnd;
    const p2Finished = s.p2.distance >= courseEnd;

    if ((p1Finished && p2Finished) || p1Out || p2Out) {
      return endRound(s, p1Out, p2Out);
    }

    // If one finished, keep going until the other finishes or gets engulfed
    if (p1Finished || p2Finished) {
      // Give a grace period — if both don't finish within CANVAS_H more distance
      const maxDist = Math.max(s.p1.distance, s.p2.distance);
      if (maxDist >= courseEnd + CANVAS_H * 2) {
        return endRound(s, p1Out, p2Out);
      }
    }
  } else {
    // Escape mode: both engulfed = game over
    if (p1Out && p2Out) {
      return endRound(s, p1Out, p2Out);
    }
    // One engulfed = other wins
    if (p1Out || p2Out) {
      return endRound(s, p1Out, p2Out);
    }
  }

  return s;
}

/**
 * End the current round and determine winner.
 */
function endRound(state, p1Out, p2Out) {
  const s = { ...state };

  // Determine round winner
  let roundWinner = 0; // 0 = draw
  if (p1Out && !p2Out) {
    roundWinner = 2;
  } else if (p2Out && !p1Out) {
    roundWinner = 1;
  } else if (p1Out && p2Out) {
    // Both engulfed: who went further
    roundWinner = s.p1.distance > s.p2.distance ? 1 : 2;
    if (Math.abs(s.p1.distance - s.p2.distance) < 1) roundWinner = 0;
  } else {
    // Both finished: lower timer wins
    if (s.p1.timer < s.p2.timer) roundWinner = 1;
    else if (s.p2.timer < s.p1.timer) roundWinner = 2;
  }

  if (roundWinner === 1) s.p1RoundWins++;
  if (roundWinner === 2) s.p2RoundWins++;

  // Check match end
  if (s.mode === GAME_MODE.AVALANCHE_ESCAPE) {
    // Single round mode
    s.phase = PHASE.FINISHED;
    return s;
  }

  const winsNeeded = 2; // Best of 3
  if (s.p1RoundWins >= winsNeeded || s.p2RoundWins >= winsNeeded) {
    s.phase = PHASE.FINISHED;
    return s;
  }

  // Next round
  s.phase = PHASE.ROUND_END;
  return s;
}

/**
 * Reset state for a new round.
 */
export function startNextRound(state) {
  const nextRound = state.round + 1;
  const diff = DIFFICULTY[Math.min(nextRound, DIFFICULTY.length - 1)];

  return {
    ...state,
    phase: PHASE.COUNTDOWN,
    round: nextRound,
    countdown: 3,
    scrollY: 0,
    avalancheY: AVALANCHE_START_OFFSET,
    avalancheSpeed: state.mode === GAME_MODE.CLEAN_RUN ? 0 : diff.avalancheBase,
    avalancheAccelTimer: 0,
    blizzardActive: false,
    blizzardTimer: 0,
    blizzardCooldown: BLIZZARD_INTERVAL,
    p1: {
      x: CANVAS_W / 2 - 40,
      velX: 0,
      state: SKIER_STATE.SKIING,
      timer: 0,
      boostTimer: 0,
      iceTimer: 0,
      stunTimer: 0,
      distance: 0,
    },
    p2: {
      x: CANVAS_W / 2 + 40,
      velX: 0,
      state: SKIER_STATE.SKIING,
      timer: 0,
      boostTimer: 0,
      iceTimer: 0,
      stunTimer: 0,
      distance: 0,
    },
    events: 0,
    obstacles: [],
    nextChunkY: 0,
    gates: [],
    nextGateY: GATE_INTERVAL,
    gateWidth: diff.gateWidth,
    items: [],
    itemSpawnTimer: ITEM_SPAWN_INTERVAL,
    _rng: mulberry32(state.seed + nextRound * 1000),
    _difficulty: diff,
    frameCount: 0,
  };
}

/**
 * Determine the match winner (for GAME_END).
 */
export function determineWinner(state) {
  if (state.p1RoundWins > state.p2RoundWins) return 1;
  if (state.p2RoundWins > state.p1RoundWins) return 2;
  // Tiebreak: total time
  return 0;
}
