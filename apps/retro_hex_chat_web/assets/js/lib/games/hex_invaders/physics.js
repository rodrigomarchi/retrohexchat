/**
 * Pure physics / game logic for Hex Invaders.
 * All functions are side-effect-free: state → state.
 * @module games/hex_invaders_physics
 */

import { PHASE, GAME_MODE, ALIEN_TYPE } from "./protocol.js";

// ── Canvas & Layout ──
export const CANVAS_W = 640;
export const CANVAS_H = 480;
export const HALF_W = 318; // playable width per side (640/2 - 2 for divider)
const DIVIDER_X = 320;

// ── Grid ──
export const GRID_COLS = 6;
export const GRID_ROWS = 5;
export const COOP_GRID_COLS = 11;
export const COOP_GRID_ROWS = 5;

// ── Cannon ──
const CANNON_W = 20;
const CANNON_Y_OFFSET = 450;
export const CANNON_SPEED = 3;

// ── Missiles ──
export const MISSILE_SPEED = 6;
const MISSILE_RADIUS = 4;

// ── Bombs ──
export const BOMB_SPEED = 3;
const BOMB_RADIUS = 4;

// ── Aliens ──
const ALIEN_W = 10;
const ALIEN_H = 8;
const ALIEN_SPACING_X = 34;
const ALIEN_SPACING_Y = 28;
const ALIEN_MARGIN_TOP = 50;
const ALIEN_MARGIN_LEFT = 20;
const ALIEN_STEP_X = 4;
const ALIEN_STEP_Y = 12;
const BASE_MOVE_INTERVAL = 45;
const MIN_MOVE_INTERVAL = 2;
const GROUND_Y = CANNON_Y_OFFSET - 15;

// ── Lives & Shields ──
export const INITIAL_LIVES = 3;
export const SHIELD_SEGMENTS = 4;
const SHIELD_W = 30;
const SHIELD_H = 12;

// ── UFO ──
const UFO_SPEED = 2;
const UFO_Y = 18;
const UFO_W = 24;
const UFO_SPAWN_INTERVAL = 1800; // ~30 sec at 60fps
const UFO_HIT_RADIUS = 14;

// ── Drop Queue ──
export const DROP_DELAY = 120; // ~2 sec at 60fps
const DROP_DELAY_BLITZ = 1; // 1 frame delay (effectively instant but avoids same-frame flood)
const MAX_DROPS = 6; // must match protocol.js MAX_DROPS

// ── Combo ──
export const COMBO_WINDOW = 90; // ~1.5 sec at 60fps
const COMBO_T1 = 3;
const COMBO_T2 = 5;
const COMBO_T3 = 8;
const COMBO_T1_BLITZ = 2;
const COMBO_T2_BLITZ = 4;
const COMBO_T3_BLITZ = 6;

// ── Waves ──
const MAX_WAVES_WAR = 10;
const MAX_WAVES_BLITZ = 5;
const MAX_WAVES_COOP = 10;

// ── Scoring ──
const SCORE_BASE = 10;
const SCORE_MID = 20;
const SCORE_TOP = 30;
const SCORE_REINFORCEMENT = 15;
const SCORE_ARMORED = 50;
// Bonus scores reserved for future wave-clear / survival bonuses
// const SCORE_WAVE_CLEAR = 200;
// const SCORE_SURVIVAL = 500;

// ── Bomb spawn timing ──
const BOMB_INTERVAL_BASE = 120; // frames between bombs
const BOMB_INTERVAL_MIN = 30;

// ── Hit detection radius ──
const ALIEN_HIT_RADIUS = 8;
const CANNON_HIT_RADIUS = 12;
const SHIELD_HIT_MARGIN = 4;

// ── Shield positions (computed per mode) ──
function computeShieldPositions(mode) {
  if (mode === GAME_MODE.COOP) {
    // 3 shields across full width
    return [
      { x: 130, y: 400 },
      { x: 320, y: 400 },
      { x: 510, y: 400 },
    ];
  }
  // 2 shields per side
  return [
    { x: 80, y: 400 },
    { x: 220, y: 400 },
    { x: DIVIDER_X + 80, y: 400 },
    { x: DIVIDER_X + 140, y: 400 },
  ];
}

// ── Events template ──
function emptyEvents() {
  return {
    alienKill: 0,
    alienType: ALIEN_TYPE.NONE,
    bombHit: false,
    shieldHit: false,
    cannonHit: 0,
    ufoKill: 0,
    ufoAppear: false,
    combo: 0,
    dropLand: false,
    waveCleared: false,
    death: 0,
    invaded: 0,
    armoredHit: 0,
  };
}

// ── State Creation ──

/**
 * Create initial game state for given mode and seed.
 * @param {number} mode - GAME_MODE enum
 * @param {number} seed - shared PRNG seed
 * @returns {object}
 */
export function createInitialState(mode, seed) {
  const shieldPositions = computeShieldPositions(mode);
  const shieldCount = mode === GAME_MODE.COOP ? 3 : 4;
  const shields = Array(shieldCount).fill(SHIELD_SEGMENTS);
  const cannon1Start = mode === GAME_MODE.COOP ? CANVAS_W / 3 : HALF_W / 2;
  const cannon2Start = mode === GAME_MODE.COOP ? (CANVAS_W * 2) / 3 : DIVIDER_X + HALF_W / 2;

  return {
    phase: PHASE.WAITING,
    wave: 0,
    countdown: 3,
    mode,
    seed,

    cannon1X: cannon1Start,
    cannon2X: cannon2Start,

    m1X: 0,
    m1Y: 0,
    m1Active: false,
    m2X: 0,
    m2Y: 0,
    m2Active: false,

    score1: 0,
    score2: 0,
    lives1: INITIAL_LIVES,
    lives2: INITIAL_LIVES,

    combo1Count: 0,
    combo1Timer: 0,
    combo2Count: 0,
    combo2Timer: 0,

    aliens1: [],
    aliens2: [],
    alien1Count: 0,
    alien2Count: 0,
    alien1DirRight: true,
    alien2DirRight: true,
    alien1MoveTimer: BASE_MOVE_INTERVAL,
    alien2MoveTimer: BASE_MOVE_INTERVAL,

    bombs: [],
    bombCount: 0,
    bombTimer: BOMB_INTERVAL_BASE,

    shields,
    _shieldPositions: shieldPositions,

    ufoX: 0,
    ufoActive: false,
    ufoDir: 1,
    ufoTimer: UFO_SPAWN_INTERVAL,

    drops: [],

    events: emptyEvents(),
  };
}

// ── Wave Creation ──

/**
 * Generate alien grid for a new wave.
 * @param {object} state
 * @param {number} waveNumber - 1-based
 * @returns {object}
 */
export function createWave(state, waveNumber) {
  const s = { ...state, wave: waveNumber };

  if (state.mode === GAME_MODE.COOP) {
    s.aliens1 = buildGrid(COOP_GRID_COLS, COOP_GRID_ROWS, ALIEN_MARGIN_LEFT, ALIEN_MARGIN_TOP);
    s.alien1Count = s.aliens1.length;
    s.aliens2 = [];
    s.alien2Count = 0;
  } else {
    s.aliens1 = buildGrid(GRID_COLS, GRID_ROWS, ALIEN_MARGIN_LEFT, ALIEN_MARGIN_TOP);
    s.alien1Count = s.aliens1.length;
    s.aliens2 = buildGrid(GRID_COLS, GRID_ROWS, DIVIDER_X + ALIEN_MARGIN_LEFT, ALIEN_MARGIN_TOP);
    s.alien2Count = s.aliens2.length;
  }

  s.alien1DirRight = true;
  s.alien2DirRight = true;
  s.alien1MoveTimer = getAlienSpeed(s.alien1Count, waveNumber);
  s.alien2MoveTimer = getAlienSpeed(s.alien2Count, waveNumber);

  return s;
}

function buildGrid(cols, rows, offsetX, offsetY) {
  const aliens = [];
  for (let r = 0; r < rows; r++) {
    const type = r === 0 ? ALIEN_TYPE.TOP : r <= 1 ? ALIEN_TYPE.MID : ALIEN_TYPE.BASE;
    for (let c = 0; c < cols; c++) {
      aliens.push({
        type,
        x: offsetX + c * ALIEN_SPACING_X,
        y: offsetY + r * ALIEN_SPACING_Y,
        hp: 1,
      });
    }
  }
  return aliens;
}

// ── Cannon Movement ──

/**
 * Move a player's cannon horizontally.
 * @param {object} state
 * @param {number} player - 1 or 2
 * @param {number} direction - -1 (left) or 1 (right)
 * @returns {object}
 */
export function moveCannon(state, player, direction) {
  const s = { ...state };
  if (player === 1) {
    let nx = s.cannon1X + direction * CANNON_SPEED;
    if (s.mode === GAME_MODE.COOP) {
      nx = Math.max(CANNON_W / 2, Math.min(CANVAS_W - CANNON_W / 2, nx));
    } else {
      nx = Math.max(CANNON_W / 2, Math.min(HALF_W - CANNON_W / 2, nx));
    }
    s.cannon1X = nx;
  } else {
    let nx = s.cannon2X + direction * CANNON_SPEED;
    if (s.mode === GAME_MODE.COOP) {
      nx = Math.max(CANNON_W / 2, Math.min(CANVAS_W - CANNON_W / 2, nx));
    } else {
      nx = Math.max(DIVIDER_X + CANNON_W / 2, Math.min(CANVAS_W - CANNON_W / 2, nx));
    }
    s.cannon2X = nx;
  }
  return s;
}

// ── Missile Firing ──

/**
 * Fire a missile from a player's cannon (one at a time).
 * @param {object} state
 * @param {number} player - 1 or 2
 * @returns {object}
 */
export function fireMissile(state, player) {
  const s = { ...state };
  if (player === 1 && !s.m1Active) {
    s.m1Active = true;
    s.m1X = s.cannon1X;
    s.m1Y = CANNON_Y_OFFSET - 10;
  } else if (player === 2 && !s.m2Active) {
    s.m2Active = true;
    s.m2X = s.cannon2X;
    s.m2Y = CANNON_Y_OFFSET - 10;
  }
  return s;
}

// ── Missile Update ──

/**
 * Move active missiles upward; deactivate off-screen.
 * @param {object} state
 * @returns {object}
 */
export function updateMissiles(state) {
  const s = { ...state };
  if (s.m1Active) {
    s.m1Y -= MISSILE_SPEED;
    if (s.m1Y < 0) s.m1Active = false;
  }
  if (s.m2Active) {
    s.m2Y -= MISSILE_SPEED;
    if (s.m2Y < 0) s.m2Active = false;
  }
  return s;
}

// ── Alien Movement ──

/**
 * Move aliens for a given side when their timer fires.
 * @param {object} state
 * @param {number} side - 1 or 2
 * @returns {object}
 */
export function moveAliens(state, side) {
  const s = { ...state };
  const timerKey = side === 1 ? "alien1MoveTimer" : "alien2MoveTimer";
  const aliensKey = side === 1 ? "aliens1" : "aliens2";
  const dirKey = side === 1 ? "alien1DirRight" : "alien2DirRight";

  if (s[timerKey] > 1) {
    return s; // timer not yet fired
  }

  // Timer fired — move aliens
  const aliens = s[aliensKey].map((a) => ({ ...a }));
  const dirRight = s[dirKey];
  const step = dirRight ? ALIEN_STEP_X : -ALIEN_STEP_X;

  // Early return if no alive aliens
  const aliveCount = aliens.filter((a) => a.type !== ALIEN_TYPE.NONE).length;
  if (aliveCount === 0) {
    s[timerKey] = getAlienSpeed(0, s.wave);
    return s;
  }

  // Determine boundaries for this side
  const minX = 4;
  const maxX =
    side === 2 ? CANVAS_W - 4 : state.mode === GAME_MODE.COOP ? CANVAS_W - 4 : DIVIDER_X - 4;

  // Check if we need to reverse
  let needReverse = false;
  for (const a of aliens) {
    if (a.type === ALIEN_TYPE.NONE) continue;
    const nx = a.x + step;
    if (nx < minX || nx + ALIEN_W > maxX) {
      needReverse = true;
      break;
    }
  }

  if (needReverse) {
    // Descend and reverse direction
    for (const a of aliens) {
      if (a.type === ALIEN_TYPE.NONE) continue;
      a.y += ALIEN_STEP_Y;
    }
    s[dirKey] = !dirRight;
  } else {
    // Move laterally
    for (const a of aliens) {
      if (a.type === ALIEN_TYPE.NONE) continue;
      a.x += step;
    }
  }

  s[aliensKey] = aliens;
  s[timerKey] = getAlienSpeed(aliens.filter((a) => a.type !== ALIEN_TYPE.NONE).length, s.wave);

  return s;
}

/**
 * Calculate alien move interval based on alive count and wave.
 * Fewer aliens = faster. Higher wave = faster.
 * @param {number} alienCount
 * @param {number} wave
 * @returns {number} frames between moves
 */
export function getAlienSpeed(alienCount, wave) {
  if (alienCount <= 0) return MIN_MOVE_INTERVAL;
  const totalAliens = GRID_COLS * GRID_ROWS;
  const ratio = alienCount / totalAliens;
  const waveMultiplier = Math.max(0.5, 1 - (wave - 1) * 0.05);
  const interval = Math.floor(BASE_MOVE_INTERVAL * ratio * waveMultiplier);
  return Math.max(MIN_MOVE_INTERVAL, interval);
}

// ── Bomb Spawning ──

/**
 * Spawn alien bombs when timer reaches zero.
 * @param {object} state
 * @returns {object}
 */
export function spawnBombs(state) {
  const s = { ...state };
  if (s.phase !== PHASE.PLAYING || s.bombTimer > 0) return s;

  const bombs = [...s.bombs];

  // Pick a random alive alien from each active side to drop a bomb
  const spawnFromSide = (aliensKey, side) => {
    const alive = s[aliensKey].filter((a) => a.type !== ALIEN_TYPE.NONE);
    if (alive.length === 0) return;
    // Use a simple deterministic pick based on bomb count
    const idx = (s.bombCount + side) % alive.length;
    const a = alive[idx];
    bombs.push({ side, x: a.x + ALIEN_W / 2, y: a.y + ALIEN_H });
  };

  if (state.mode === GAME_MODE.COOP) {
    spawnFromSide("aliens1", 1);
  } else {
    spawnFromSide("aliens1", 1);
    spawnFromSide("aliens2", 2);
  }

  s.bombs = bombs;
  s.bombCount = bombs.length;

  // Reset timer — decreases with wave
  const interval = Math.max(BOMB_INTERVAL_MIN, BOMB_INTERVAL_BASE - s.wave * 10);
  s.bombTimer = interval;

  return s;
}

// ── Bomb Update ──

/**
 * Move bombs downward; remove off-screen.
 * @param {object} state
 * @returns {object}
 */
export function updateBombs(state) {
  const s = { ...state };
  s.bombs = s.bombs.map((b) => ({ ...b, y: b.y + BOMB_SPEED })).filter((b) => b.y < CANVAS_H);
  s.bombCount = s.bombs.length;
  return s;
}

// ── Collision: Missile vs Alien ──

function alienScore(type) {
  switch (type) {
    case ALIEN_TYPE.BASE:
      return SCORE_BASE;
    case ALIEN_TYPE.MID:
      return SCORE_MID;
    case ALIEN_TYPE.TOP:
      return SCORE_TOP;
    case ALIEN_TYPE.REINFORCEMENT:
      return SCORE_REINFORCEMENT;
    case ALIEN_TYPE.ARMORED:
      return SCORE_ARMORED;
    default:
      return 0;
  }
}

function getDropDelay(mode) {
  return mode === GAME_MODE.BLITZ ? DROP_DELAY_BLITZ : DROP_DELAY;
}

function getComboThresholds(mode) {
  if (mode === GAME_MODE.BLITZ) {
    return [COMBO_T1_BLITZ, COMBO_T2_BLITZ, COMBO_T3_BLITZ];
  }
  return [COMBO_T1, COMBO_T2, COMBO_T3];
}

/**
 * Check missile-alien collisions for both players.
 * Awards points, queues drops (in Invasion War/Blitz), increments combos.
 * @param {object} state
 * @returns {object}
 */
export function checkMissileAlienHits(state) {
  let s = { ...state, events: { ...state.events } };

  // Check P1 missile against P1 aliens (and shared grid in coop)
  s = _checkMissileVsAliens(s, 1, "aliens1", "alien1Count");
  // Check P2 missile against P2 aliens (not in coop — coop shares aliens1)
  if (state.mode === GAME_MODE.COOP) {
    s = _checkMissileVsAliens(s, 2, "aliens1", "alien1Count");
  } else {
    s = _checkMissileVsAliens(s, 2, "aliens2", "alien2Count");
  }

  return s;
}

function _checkMissileVsAliens(state, player, aliensKey, _countKey) {
  const s = { ...state };
  const mActiveKey = player === 1 ? "m1Active" : "m2Active";
  const mxKey = player === 1 ? "m1X" : "m2X";
  const myKey = player === 1 ? "m1Y" : "m2Y";
  const scoreKey = player === 1 ? "score1" : "score2";
  const comboCountKey = player === 1 ? "combo1Count" : "combo2Count";
  const comboTimerKey = player === 1 ? "combo1Timer" : "combo2Timer";

  if (!s[mActiveKey]) return s;

  const mx = s[mxKey];
  const my = s[myKey];
  const aliens = s[aliensKey].map((a) => ({ ...a }));
  let hit = false;

  for (let i = 0; i < aliens.length; i++) {
    const a = aliens[i];
    if (a.type === ALIEN_TYPE.NONE) continue;

    const dx = mx - (a.x + ALIEN_W / 2);
    const dy = my - (a.y + ALIEN_H / 2);
    if (
      Math.abs(dx) < MISSILE_RADIUS + ALIEN_HIT_RADIUS &&
      Math.abs(dy) < MISSILE_RADIUS + ALIEN_HIT_RADIUS
    ) {
      hit = true;
      a.hp -= 1;

      if (a.hp <= 0) {
        // Alien destroyed
        const prevType = a.type;
        s[scoreKey] += alienScore(prevType);
        a.type = ALIEN_TYPE.NONE;
        s.events.alienKill = player;
        s.events.alienType = prevType;

        // Combo tracking
        s[comboCountKey] += 1;
        s[comboTimerKey] = COMBO_WINDOW;

        // Check combo thresholds and trigger combo drops
        const [t1, t2, t3] = getComboThresholds(s.mode);
        if (s[comboCountKey] === t1) {
          s.events.combo = 1;
          if (s.mode !== GAME_MODE.COOP) {
            _queueDrop(s, ALIEN_TYPE.REINFORCEMENT, player === 1 ? 2 : 1);
          }
        } else if (s[comboCountKey] === t2) {
          s.events.combo = 2;
          if (s.mode !== GAME_MODE.COOP) {
            _queueDrop(s, ALIEN_TYPE.REINFORCEMENT, player === 1 ? 2 : 1);
            _queueDrop(s, ALIEN_TYPE.REINFORCEMENT, player === 1 ? 2 : 1);
            _queueDrop(s, ALIEN_TYPE.ARMORED, player === 1 ? 2 : 1);
          }
        } else if (s[comboCountKey] >= t3) {
          s.events.combo = 3;
          if (s.mode !== GAME_MODE.COOP) {
            for (let j = 0; j < 3; j++) {
              _queueDrop(s, ALIEN_TYPE.REINFORCEMENT, player === 1 ? 2 : 1);
            }
            _queueDrop(s, ALIEN_TYPE.ARMORED, player === 1 ? 2 : 1);
          }
        }

        // Queue standard drop (Invasion War / Blitz only)
        if (s.mode !== GAME_MODE.COOP) {
          _queueDrop(s, ALIEN_TYPE.REINFORCEMENT, player === 1 ? 2 : 1);
        }
      } else {
        // Armored: took damage but survived
        s.events.armoredHit = player;
      }

      s[mActiveKey] = false;
      break;
    }
  }

  if (hit) {
    s[aliensKey] = aliens;
  }

  return s;
}

function _queueDrop(state, type, targetSide) {
  if (state.drops.length >= MAX_DROPS) return; // cap at protocol limit
  state.drops = [...state.drops, { type, targetSide, timer: getDropDelay(state.mode) }];
}

// ── Collision: Missile vs UFO ──

/**
 * Check if any missile hits the UFO.
 * @param {object} state
 * @returns {object}
 */
export function checkMissileUFOHit(state) {
  const s = { ...state, events: { ...state.events } };
  if (!s.ufoActive) return s;

  const checkMissile = (player) => {
    const mActiveKey = player === 1 ? "m1Active" : "m2Active";
    const mxKey = player === 1 ? "m1X" : "m2X";
    const myKey = player === 1 ? "m1Y" : "m2Y";
    const scoreKey = player === 1 ? "score1" : "score2";

    if (!s[mActiveKey]) return;

    const dx = s[mxKey] - (s.ufoX + UFO_W / 2);
    const dy = s[myKey] - UFO_Y;
    if (Math.abs(dx) < UFO_HIT_RADIUS && Math.abs(dy) < UFO_HIT_RADIUS) {
      s.ufoActive = false;
      s[mActiveKey] = false;

      // Random score 100-300 (deterministic from seed + wave)
      const ufoScores = [100, 150, 200, 250, 300];
      const idx = (s.seed + s.wave + player) % ufoScores.length;
      s[scoreKey] += ufoScores[idx];
      s.events.ufoKill = player;

      // Queue armored drop for opponent
      if (s.mode !== GAME_MODE.COOP) {
        const target = player === 1 ? 2 : 1;
        s.drops = [
          ...s.drops,
          {
            type: ALIEN_TYPE.ARMORED,
            targetSide: target,
            timer: getDropDelay(s.mode),
          },
        ];
      }
    }
  };

  checkMissile(1);
  checkMissile(2);
  return s;
}

// ── Collision: Bomb vs Cannon ──

/**
 * Check if bombs hit player cannons.
 * @param {object} state
 * @returns {object}
 */
export function checkBombCannonHits(state) {
  const s = { ...state, events: { ...state.events } };
  const remaining = [];

  for (const b of s.bombs) {
    let hit = false;

    // Check P1 cannon
    if (
      Math.abs(b.x - s.cannon1X) < CANNON_HIT_RADIUS + BOMB_RADIUS &&
      Math.abs(b.y - CANNON_Y_OFFSET) < CANNON_HIT_RADIUS + BOMB_RADIUS &&
      s.lives1 > 0
    ) {
      // In COOP, bombs can only be from side 1 (shared aliens)
      // In split-screen, P1 bombs hit P1 cannon
      if (b.side === 1 || s.mode === GAME_MODE.COOP) {
        s.lives1 = Math.max(0, s.lives1 - 1);
        s.events.cannonHit = 1;
        hit = true;
      }
    }

    // Check P2 cannon
    if (
      !hit &&
      Math.abs(b.x - s.cannon2X) < CANNON_HIT_RADIUS + BOMB_RADIUS &&
      Math.abs(b.y - CANNON_Y_OFFSET) < CANNON_HIT_RADIUS + BOMB_RADIUS &&
      s.lives2 > 0
    ) {
      if (b.side === 2 || s.mode === GAME_MODE.COOP) {
        s.lives2 = Math.max(0, s.lives2 - 1);
        s.events.cannonHit = 2;
        hit = true;
      }
    }

    if (!hit) remaining.push(b);
  }

  s.bombs = remaining;
  s.bombCount = remaining.length;
  return s;
}

// ── Collision: Bomb vs Shield ──

/**
 * Check if bombs hit shields.
 * @param {object} state
 * @returns {object}
 */
export function checkBombShieldHits(state) {
  const s = { ...state, events: { ...state.events } };
  const shields = [...s.shields];
  const positions = s._shieldPositions;
  const remaining = [];

  for (const b of s.bombs) {
    let hit = false;
    for (let i = 0; i < positions.length; i++) {
      if (shields[i] <= 0) continue;
      const sp = positions[i];
      if (
        Math.abs(b.x - sp.x) < SHIELD_W / 2 + SHIELD_HIT_MARGIN &&
        Math.abs(b.y - sp.y) < SHIELD_H / 2 + SHIELD_HIT_MARGIN
      ) {
        shields[i] -= 1;
        s.events.shieldHit = true;
        hit = true;
        break;
      }
    }
    if (!hit) remaining.push(b);
  }

  s.shields = shields;
  s.bombs = remaining;
  s.bombCount = remaining.length;
  return s;
}

// ── Alien Reached Ground ──

/**
 * Check if any alive alien has reached the ground line.
 * Triggers instant game over event.
 * @param {object} state
 * @returns {object}
 */
export function checkAlienReachedGround(state) {
  const s = { ...state, events: { ...state.events } };

  // Check P1 aliens
  for (const a of s.aliens1) {
    if (a.type !== ALIEN_TYPE.NONE && a.y >= GROUND_Y) {
      s.events.invaded = 1;
      return s;
    }
  }

  // Check P2 aliens (not in coop)
  if (s.mode !== GAME_MODE.COOP) {
    for (const a of s.aliens2) {
      if (a.type !== ALIEN_TYPE.NONE && a.y >= GROUND_Y) {
        s.events.invaded = 2;
        return s;
      }
    }
  }

  return s;
}

// ── Drop Queue Processing ──

/**
 * Process pending alien drops: decrement timers, materialize when ready.
 * @param {object} state
 * @returns {object}
 */
export function processDropQueue(state) {
  const s = { ...state };
  const remaining = [];
  const aliens1 = [...s.aliens1.map((a) => ({ ...a }))];
  const aliens2 = [...s.aliens2.map((a) => ({ ...a }))];
  let ac1 = s.alien1Count;
  let ac2 = s.alien2Count;

  for (const drop of s.drops) {
    const d = { ...drop, timer: drop.timer - 1 };
    if (d.timer <= 0) {
      // Materialize: add alien to the target side at the lowest row position
      const alien = {
        type: d.type,
        x: 0,
        y: 0,
        hp: d.type === ALIEN_TYPE.ARMORED ? 2 : 1,
      };

      if (d.targetSide === 1 || s.mode === GAME_MODE.COOP) {
        // Find lowest row position for P1/coop grid
        const maxY = aliens1.reduce(
          (m, a) => (a.type !== ALIEN_TYPE.NONE ? Math.max(m, a.y) : m),
          ALIEN_MARGIN_TOP,
        );
        alien.y = Math.min(maxY + ALIEN_SPACING_Y, GROUND_Y - ALIEN_SPACING_Y);
        alien.x =
          ALIEN_MARGIN_LEFT +
          (ac1 % (s.mode === GAME_MODE.COOP ? COOP_GRID_COLS : GRID_COLS)) * ALIEN_SPACING_X;
        aliens1.push(alien);
        ac1 += 1;
      } else {
        const maxY = aliens2.reduce(
          (m, a) => (a.type !== ALIEN_TYPE.NONE ? Math.max(m, a.y) : m),
          ALIEN_MARGIN_TOP,
        );
        alien.y = Math.min(maxY + ALIEN_SPACING_Y, GROUND_Y - ALIEN_SPACING_Y);
        alien.x = DIVIDER_X + ALIEN_MARGIN_LEFT + (ac2 % GRID_COLS) * ALIEN_SPACING_X;
        aliens2.push(alien);
        ac2 += 1;
      }

      s.events.dropLand = true;
    } else {
      remaining.push(d);
    }
  }

  s.drops = remaining;
  s.aliens1 = aliens1;
  s.aliens2 = aliens2;
  s.alien1Count = ac1;
  s.alien2Count = ac2;
  return s;
}

// ── UFO ──

/**
 * Update UFO: spawn, move, deactivate off-screen.
 * @param {object} state
 * @returns {object}
 */
export function updateUFO(state) {
  const s = { ...state, events: { ...state.events } };

  if (s.ufoActive) {
    s.ufoX += s.ufoDir * UFO_SPEED;
    if (s.ufoX < -UFO_W || s.ufoX > CANVAS_W) {
      s.ufoActive = false;
      s.ufoTimer = UFO_SPAWN_INTERVAL;
    }
  } else if (s.ufoTimer <= 0 && s.phase === PHASE.PLAYING) {
    // Spawn UFO
    s.ufoActive = true;
    s.ufoDir = (s.seed + s.wave) % 2 === 0 ? 1 : -1;
    s.ufoX = s.ufoDir === 1 ? -UFO_W : CANVAS_W + UFO_W;
    s.events.ufoAppear = true;
    s.ufoTimer = UFO_SPAWN_INTERVAL;
  }

  return s;
}

// ── Combo System ──

/**
 * Decay combo timers; reset combo when window expires.
 * @param {object} state
 * @returns {object}
 */
export function updateCombos(state) {
  const s = { ...state };

  if (s.combo1Timer > 0) {
    s.combo1Timer -= 1;
    if (s.combo1Timer <= 0) {
      s.combo1Count = 0;
      s.combo1Timer = 0;
    }
  }

  if (s.combo2Timer > 0) {
    s.combo2Timer -= 1;
    if (s.combo2Timer <= 0) {
      s.combo2Count = 0;
      s.combo2Timer = 0;
    }
  }

  return s;
}

// ── Wave Clear ──

/**
 * Check if all aliens are destroyed on relevant sides.
 * @param {object} state
 * @returns {boolean}
 */
export function checkWaveClear(state) {
  const allDead1 = state.aliens1.every((a) => a.type === ALIEN_TYPE.NONE);

  if (state.mode === GAME_MODE.COOP) {
    return allDead1;
  }

  const allDead2 = state.aliens2.every((a) => a.type === ALIEN_TYPE.NONE);
  return allDead1 && allDead2;
}

// ── Game Over ──

/**
 * Check game over conditions.
 * @param {object} state
 * @returns {{ ended: boolean, winner: number }}
 */
export function checkGameOver(state) {
  // Invasion event (aliens reached ground)
  if (state.events.invaded === 1) {
    return { ended: true, winner: state.mode === GAME_MODE.COOP ? 0 : 2 };
  }
  if (state.events.invaded === 2) {
    return { ended: true, winner: 1 };
  }

  if (state.mode === GAME_MODE.COOP) {
    // Both dead = game over
    if (state.lives1 <= 0 && state.lives2 <= 0) {
      return { ended: true, winner: 0 }; // 0 = no winner in coop
    }
    // Max waves cleared
    if (state.wave >= MAX_WAVES_COOP && checkWaveClear(state)) {
      return { ended: true, winner: 0 }; // survived!
    }
    return { ended: false, winner: 0 };
  }

  // Split-screen modes
  if (state.lives1 <= 0) {
    return { ended: true, winner: 2 };
  }
  if (state.lives2 <= 0) {
    return { ended: true, winner: 1 };
  }

  // Max waves
  const maxWaves = state.mode === GAME_MODE.BLITZ ? MAX_WAVES_BLITZ : MAX_WAVES_WAR;
  if (state.wave >= maxWaves && checkWaveClear(state)) {
    // Higher score wins
    const winner = state.score1 > state.score2 ? 1 : state.score2 > state.score1 ? 2 : 1;
    return { ended: true, winner };
  }

  return { ended: false, winner: 0 };
}

// ── Timers ──

/**
 * Decrement all frame-based timers.
 * @param {object} state
 * @returns {object}
 */
export function tickTimers(state) {
  const s = { ...state };
  if (s.bombTimer > 0) s.bombTimer -= 1;
  if (!s.ufoActive && s.ufoTimer > 0) s.ufoTimer -= 1;
  if (s.alien1MoveTimer > 0) s.alien1MoveTimer -= 1;
  if (s.alien2MoveTimer > 0) s.alien2MoveTimer -= 1;
  return s;
}

// ── Events ──

/**
 * Reset all event flags for the next frame.
 * @param {object} state
 * @returns {object}
 */
export function clearEvents(state) {
  return { ...state, events: emptyEvents() };
}
