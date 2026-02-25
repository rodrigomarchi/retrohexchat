/**
 * Hex Frost — Pure physics / game-logic functions.
 *
 * Every exported function is pure: (state, inputs) → newState.
 * No DOM, no canvas, no audio — only data transformations.
 */

import { PHASE, GAME_MODE, BLOCK_STATE, BAILEY_STATE, ENEMY_TYPE, EVENT } from "./protocol.js";

// ── Canvas & layout constants ──────────────────────────────────
export const CANVAS_W = 640;
export const CANVAS_H = 480;

// Shore (top platform where igloos live)
export const SHORE_Y = 40;
export const SHORE_H = 50;
export const SHORE_BOTTOM = SHORE_Y + SHORE_H; // 90

// 4 ice block rows
export const ROW_Y = [130, 195, 260, 325];
export const ROW_SPACING = 65;
export const NUM_ROWS = 4;

// Water below row 4
export const WATER_Y = 370;

// Ice blocks
export const BLOCK_W = 52;
export const BLOCK_H = 16;
export const BLOCKS_PER_ROW = 7;
export const BLOCK_GAP = 40; // gap between blocks

// Bailey (player character)
export const BAILEY_W = 12;
export const BAILEY_H = 16;
export const BAILEY_WALK_SPEED = 2.0;

// Jump mechanics
export const JUMP_DURATION = 20; // frames for a jump arc
export const JUMP_ARC_HEIGHT = 30; // px above midpoint

// Temperature
const TEMP_START_RACE = 45;
const TEMP_START_BLIZZARD = 60;
const TEMP_DROP_RACE = 1 / 60; // 1° per second at 60fps
const TEMP_DROP_BLIZZARD = 0.5 / 60;
const TEMP_LOW_THRESHOLD = 10;

// Igloo
const IGLOO_PIECES_RACE = 15;
const IGLOO_PIECES_BLIZZARD = 20;
export const IGLOO_W = 50;
export const IGLOO_H = 40;

// Scoring
const SCORE_BLOCK_CLAIM = 10;
const SCORE_BLOCK_STEAL = 20;
const SCORE_FISH = 200;
const SCORE_IGLOO_COMPLETE = 500;
const SCORE_TEMP_MULTIPLIER = 10;

// Lives
const INITIAL_LIVES = 3;
const RESPAWN_DELAY = 90; // frames

// Enemy sizes
export const BEAR_W = 20;
export const BEAR_H = 18;
export const CRAB_W = 14;
export const CRAB_H = 10;
export const GOOSE_W = 16;
export const GOOSE_H = 10;
export const CLAM_W = 12;
export const CLAM_H = 10;
export const FISH_W = 12;
export const FISH_H = 8;

// Enemy speeds
const BEAR_SPEED = 0.8;
const GOOSE_SPEED = 1.5;
const CLAM_CYCLE = 120; // frames per open/close cycle

// Round difficulty presets
const ROUND_PRESETS = [
  { blockSpeed: 0.6, enemies: [ENEMY_TYPE.BEAR], fishRate: 300 },
  { blockSpeed: 0.8, enemies: [ENEMY_TYPE.BEAR, ENEMY_TYPE.CRAB], fishRate: 280 },
  {
    blockSpeed: 1.0,
    enemies: [ENEMY_TYPE.BEAR, ENEMY_TYPE.CRAB, ENEMY_TYPE.GOOSE],
    fishRate: 260,
  },
  {
    blockSpeed: 1.3,
    enemies: [ENEMY_TYPE.BEAR, ENEMY_TYPE.CRAB, ENEMY_TYPE.GOOSE, ENEMY_TYPE.CLAM],
    fishRate: 240,
  },
  {
    blockSpeed: 1.7,
    enemies: [ENEMY_TYPE.BEAR, ENEMY_TYPE.CRAB, ENEMY_TYPE.GOOSE, ENEMY_TYPE.CLAM],
    fishRate: 220,
  },
];

// Rounds to win
const ROUNDS_TO_WIN = 3; // best of 5

// ── Seeded PRNG ────────────────────────────────────────────────

function mulberry32(seed) {
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
 * Create the initial game state for a new match.
 * @param {number} mode - GAME_MODE enum
 * @param {number} seed - random seed
 * @returns {object} nested game state
 */
export function createInitialState(mode, seed) {
  const rng = mulberry32(seed);
  const piecesNeeded = mode === GAME_MODE.BLIZZARD ? IGLOO_PIECES_BLIZZARD : IGLOO_PIECES_RACE;
  const temp = mode === GAME_MODE.BLIZZARD ? TEMP_START_BLIZZARD : TEMP_START_RACE;

  return {
    phase: PHASE.WAITING,
    mode,
    round: 1,
    countdown: 3,
    seed,
    temperature: temp,
    piecesNeeded,

    p1: createBailey(160, 1),
    p2: createBailey(480, 2),

    blockRows: createBlockRows(rng, 0),
    enemies: createEnemiesForRound(rng, 1, mode),
    fish: [],

    events: 0,
    frameCount: 0,
    rng,

    // Respawn timers
    p1RespawnTimer: 0,
    p2RespawnTimer: 0,

    // Fish spawn timer
    fishSpawnTimer: 0,

    // Igloo flash animations (visual-only state)
    p1IglooFlash: 0,
    p2IglooFlash: 0,

    // Round end info
    roundWinner: 0,
  };
}

function createBailey(x, playerNum) {
  return {
    x,
    row: -1, // -1 = on shore
    facing: 1, // 1 = right, -1 = left
    state: BAILEY_STATE.IDLE,
    jumpProgress: 0,
    jumpFromRow: -1,
    jumpToRow: 0,
    lives: INITIAL_LIVES,
    score: 0,
    iglooPieces: 0,
    iglooComplete: false,
    roundWins: 0,
    playerNum,
  };
}

function createBlockRows(rng, _roundIdx) {
  const rows = [];
  for (let r = 0; r < NUM_ROWS; r++) {
    const direction = r % 2 === 0 ? 1 : -1;
    const blocks = [];
    const totalWidth = BLOCKS_PER_ROW * (BLOCK_W + BLOCK_GAP);
    for (let b = 0; b < BLOCKS_PER_ROW; b++) {
      blocks.push({
        x: b * (BLOCK_W + BLOCK_GAP) + rng() * BLOCK_GAP * 0.3,
        state: BLOCK_STATE.WHITE,
      });
    }
    rows.push({ direction, offset: 0, blocks, totalWidth });
  }
  return rows;
}

function createEnemiesForRound(rng, round, mode) {
  const enemies = [];
  const preset =
    mode === GAME_MODE.BLIZZARD
      ? ROUND_PRESETS[4] // all enemies for blizzard
      : ROUND_PRESETS[Math.min(round - 1, ROUND_PRESETS.length - 1)];

  // Bears always on shore
  if (preset.enemies.includes(ENEMY_TYPE.BEAR)) {
    enemies.push({
      type: ENEMY_TYPE.BEAR,
      x: 200 + rng() * 200,
      row: -1,
      state: 1, // direction: 1=right
      timer: 0,
    });
    if (round >= 3 || mode === GAME_MODE.BLIZZARD) {
      enemies.push({
        type: ENEMY_TYPE.BEAR,
        x: 50 + rng() * 100,
        row: -1,
        state: -1,
        timer: 0,
      });
    }
  }

  // Crabs on ice blocks
  if (preset.enemies.includes(ENEMY_TYPE.CRAB)) {
    const crabCount = Math.min(round, 3);
    for (let i = 0; i < crabCount; i++) {
      enemies.push({
        type: ENEMY_TYPE.CRAB,
        x: rng() * CANVAS_W,
        row: Math.floor(rng() * NUM_ROWS),
        state: rng() > 0.5 ? 1 : -1,
        timer: 0,
      });
    }
  }

  // Geese fly between rows
  if (preset.enemies.includes(ENEMY_TYPE.GOOSE)) {
    const gooseCount = Math.min(round - 2, 2);
    for (let i = 0; i < gooseCount; i++) {
      enemies.push({
        type: ENEMY_TYPE.GOOSE,
        x: rng() * CANVAS_W,
        row: Math.floor(rng() * (NUM_ROWS - 1)),
        state: rng() > 0.5 ? 1 : -1,
        timer: 0,
      });
    }
  }

  // Clams on blocks
  if (preset.enemies.includes(ENEMY_TYPE.CLAM)) {
    const clamCount = Math.min(round - 3, 2);
    for (let i = 0; i < clamCount; i++) {
      enemies.push({
        type: ENEMY_TYPE.CLAM,
        x: rng() * CANVAS_W,
        row: Math.floor(rng() * NUM_ROWS),
        state: 0, // 0=closed, 1=open
        timer: Math.floor(rng() * CLAM_CYCLE),
      });
    }
  }

  return enemies;
}

// ── Block movement ─────────────────────────────────────────────

/**
 * Update all block rows — move blocks horizontally.
 */
export function updateBlocks(state) {
  const preset =
    state.mode === GAME_MODE.BLIZZARD
      ? ROUND_PRESETS[4]
      : ROUND_PRESETS[Math.min(state.round - 1, ROUND_PRESETS.length - 1)];
  const speed = preset.blockSpeed;

  const rows = state.blockRows.map((row) => {
    const newOffset = row.offset + row.direction * speed;
    return { ...row, offset: newOffset };
  });

  return { ...state, blockRows: rows };
}

/**
 * Get the absolute X position of a block given the row offset.
 */
export function getBlockAbsX(block, row) {
  const totalWidth = BLOCKS_PER_ROW * (BLOCK_W + BLOCK_GAP);
  const x = (((block.x + row.offset) % totalWidth) + totalWidth) % totalWidth;
  // Shift so blocks span the visible area with some offscreen buffer
  return x - BLOCK_GAP;
}

// ── Bailey movement ────────────────────────────────────────────

/**
 * Update a bailey's position based on inputs.
 */
export function updateBailey(state, playerKey, inputs) {
  const player = state[playerKey];
  if (player.state === BAILEY_STATE.DEAD || player.state === BAILEY_STATE.ENTERING_IGLOO) {
    return state;
  }

  // Handle jump in progress
  if (player.state === BAILEY_STATE.JUMPING) {
    return updateJump(state, playerKey);
  }

  // Handle falling (splash respawn)
  if (player.state === BAILEY_STATE.FALLING) {
    return state; // Handled by respawn timer
  }

  const newPlayer = { ...player };
  let events = state.events;

  // Horizontal movement
  if (inputs.left) {
    newPlayer.x -= BAILEY_WALK_SPEED;
    newPlayer.facing = -1;
    newPlayer.state = BAILEY_STATE.WALKING;
  } else if (inputs.right) {
    newPlayer.x += BAILEY_WALK_SPEED;
    newPlayer.facing = 1;
    newPlayer.state = BAILEY_STATE.WALKING;
  } else {
    newPlayer.state = BAILEY_STATE.IDLE;
  }

  // Clamp to canvas
  newPlayer.x = Math.max(BAILEY_W / 2, Math.min(CANVAS_W - BAILEY_W / 2, newPlayer.x));

  // If on a block row, keep player on the moving block
  if (newPlayer.row >= 0 && newPlayer.row < NUM_ROWS) {
    const row = state.blockRows[newPlayer.row];
    const onBlock = findBlockUnder(newPlayer.x, row);
    if (!onBlock) {
      // Fell off block — fall in water
      newPlayer.state = BAILEY_STATE.FALLING;
      events |= EVENT.SPLASH;
    }
  }

  // Initiate jump
  if (inputs.up && newPlayer.state !== BAILEY_STATE.JUMPING) {
    const targetRow = newPlayer.row === -1 ? 0 : newPlayer.row - 1;
    if (targetRow >= -1) {
      newPlayer.state = BAILEY_STATE.JUMPING;
      newPlayer.jumpFromRow = newPlayer.row;
      newPlayer.jumpToRow = targetRow;
      newPlayer.jumpProgress = 0;
      events |= EVENT.JUMP;
    }
  } else if (inputs.down && newPlayer.state !== BAILEY_STATE.JUMPING) {
    const targetRow = newPlayer.row + 1;
    if (targetRow < NUM_ROWS) {
      newPlayer.state = BAILEY_STATE.JUMPING;
      newPlayer.jumpFromRow = newPlayer.row;
      newPlayer.jumpToRow = targetRow;
      newPlayer.jumpProgress = 0;
      events |= EVENT.JUMP;
    } else if (newPlayer.row === -1) {
      // From shore, jump down to row 0
      newPlayer.state = BAILEY_STATE.JUMPING;
      newPlayer.jumpFromRow = -1;
      newPlayer.jumpToRow = 0;
      newPlayer.jumpProgress = 0;
      events |= EVENT.JUMP;
    }
  }

  return { ...state, [playerKey]: newPlayer, events };
}

function updateJump(state, playerKey) {
  const player = state[playerKey];
  const progress = player.jumpProgress + 1 / JUMP_DURATION;
  let events = state.events;

  if (progress >= 1) {
    // Landing
    const targetRow = player.jumpToRow;
    const newPlayer = {
      ...player,
      row: targetRow,
      jumpProgress: 0,
      state: BAILEY_STATE.IDLE,
    };

    if (targetRow === -1) {
      // Landing on shore — safe
      events |= EVENT.LAND;
      return { ...state, [playerKey]: newPlayer, events };
    }

    // Check if landing on a block
    const row = state.blockRows[targetRow];
    const block = findBlockUnder(newPlayer.x, row);
    if (block) {
      events |= EVENT.LAND;
      // Handle block landing (claim/steal/undo)
      return handleBlockLanding(
        { ...state, [playerKey]: newPlayer, events },
        playerKey,
        targetRow,
        block.index,
      );
    } else {
      // Missed the block — fall in water!
      newPlayer.state = BAILEY_STATE.FALLING;
      events |= EVENT.SPLASH;
      return { ...state, [playerKey]: newPlayer, events };
    }
  }

  return {
    ...state,
    [playerKey]: { ...player, jumpProgress: progress },
  };
}

/**
 * Get the Y position of a bailey accounting for jump arc.
 */
export function getBaileyY(player) {
  if (player.state === BAILEY_STATE.JUMPING) {
    const fromY = getRowY(player.jumpFromRow);
    const toY = getRowY(player.jumpToRow);
    const t = player.jumpProgress;
    const linearY = fromY + (toY - fromY) * t;
    const arc = -JUMP_ARC_HEIGHT * 4 * t * (1 - t);
    return linearY + arc;
  }
  return getRowY(player.row);
}

function getRowY(row) {
  if (row === -1) return SHORE_Y + SHORE_H / 2;
  return ROW_Y[row];
}

/**
 * Find the block under a given x position in a row.
 * Returns { index, block, absX } or null.
 */
function findBlockUnder(x, row) {
  for (let i = 0; i < row.blocks.length; i++) {
    const absX = getBlockAbsX(row.blocks[i], row);
    if (x >= absX && x <= absX + BLOCK_W) {
      return { index: i, block: row.blocks[i], absX };
    }
  }
  return null;
}

// ── Block landing mechanics ────────────────────────────────────

function handleBlockLanding(state, playerKey, rowIdx, blockIdx) {
  const player = state[playerKey];
  const playerNum = player.playerNum; // 1 or 2
  const otherKey = playerKey === "p1" ? "p2" : "p1";
  const block = state.blockRows[rowIdx].blocks[blockIdx];
  let events = state.events;

  let newPieces = player.iglooPieces;
  let otherPieces = state[otherKey].iglooPieces;
  let newScore = player.score;
  let newBlockState = block.state;

  if (block.state === BLOCK_STATE.WHITE) {
    // Claim: white → own color, gain piece
    newBlockState = playerNum === 1 ? BLOCK_STATE.BLUE_P1 : BLOCK_STATE.BLUE_P2;
    newPieces = Math.min(newPieces + 1, state.piecesNeeded);
    newScore += SCORE_BLOCK_CLAIM;
    events |= EVENT.BLOCK_CLAIM | EVENT.IGLOO_PIECE;
  } else if (
    (block.state === BLOCK_STATE.BLUE_P1 && playerNum === 1) ||
    (block.state === BLOCK_STATE.BLUE_P2 && playerNum === 2)
  ) {
    // Undo: own block → white, lose piece
    newBlockState = BLOCK_STATE.WHITE;
    newPieces = Math.max(newPieces - 1, 0);
    events |= EVENT.BLOCK_UNDO | EVENT.IGLOO_LOSE;
  } else {
    // Steal: opponent's block → own color
    if (state.mode === GAME_MODE.PEACEFUL) {
      // Peaceful mode: no stealing, treat as neutral
      return state;
    }
    newBlockState = playerNum === 1 ? BLOCK_STATE.BLUE_P1 : BLOCK_STATE.BLUE_P2;
    newPieces = Math.min(newPieces + 1, state.piecesNeeded);
    otherPieces = Math.max(otherPieces - 1, 0);
    newScore += SCORE_BLOCK_STEAL;
    events |= EVENT.BLOCK_STEAL | EVENT.IGLOO_PIECE | EVENT.IGLOO_LOSE;
  }

  // Update block
  const newRows = state.blockRows.map((row, ri) => {
    if (ri !== rowIdx) return row;
    return {
      ...row,
      blocks: row.blocks.map((b, bi) => {
        if (bi !== blockIdx) return b;
        return { ...b, state: newBlockState };
      }),
    };
  });

  // Check igloo completion
  let iglooComplete = player.iglooComplete;
  if (newPieces >= state.piecesNeeded && !iglooComplete) {
    iglooComplete = true;
    events |= EVENT.IGLOO_COMPLETE;
    newScore += SCORE_IGLOO_COMPLETE;
  }

  // Igloo flash timers
  const flashKey = playerKey === "p1" ? "p1IglooFlash" : "p2IglooFlash";
  const otherFlashKey = playerKey === "p1" ? "p2IglooFlash" : "p1IglooFlash";
  const flashUpdates = {};
  if (events & EVENT.IGLOO_PIECE) flashUpdates[flashKey] = 15; // gold flash
  if (events & EVENT.IGLOO_LOSE && otherPieces < state[otherKey].iglooPieces) {
    flashUpdates[otherFlashKey] = 15; // red flash on opponent
  }

  return {
    ...state,
    blockRows: newRows,
    [playerKey]: {
      ...player,
      iglooPieces: newPieces,
      iglooComplete,
      score: newScore,
    },
    [otherKey]: {
      ...state[otherKey],
      iglooPieces: otherPieces,
    },
    events,
    ...flashUpdates,
  };
}

// ── Enemy updates ──────────────────────────────────────────────

/**
 * Update enemy positions and behaviors.
 */
export function updateEnemies(state) {
  const enemies = state.enemies.map((enemy) => {
    switch (enemy.type) {
      case ENEMY_TYPE.BEAR:
        return updateBear(enemy);
      case ENEMY_TYPE.CRAB:
        return updateCrab(enemy, state);
      case ENEMY_TYPE.GOOSE:
        return updateGoose(enemy);
      case ENEMY_TYPE.CLAM:
        return updateClam(enemy);
      default:
        return enemy;
    }
  });
  return { ...state, enemies };
}

function updateBear(bear) {
  let x = bear.x + bear.state * BEAR_SPEED;
  let dir = bear.state;
  if (x <= 10 || x >= CANVAS_W - BEAR_W - 10) {
    dir = -dir;
    x = Math.max(10, Math.min(x, CANVAS_W - BEAR_W - 10));
  }
  return { ...bear, x, state: dir };
}

function updateCrab(crab, state) {
  // Crabs move with the block row
  const row = state.blockRows[crab.row];
  const preset =
    state.mode === GAME_MODE.BLIZZARD
      ? ROUND_PRESETS[4]
      : ROUND_PRESETS[Math.min(state.round - 1, ROUND_PRESETS.length - 1)];
  let x = crab.x + row.direction * preset.blockSpeed + crab.state * 0.3;
  // Wrap
  if (x < -CRAB_W) x = CANVAS_W + CRAB_W;
  if (x > CANVAS_W + CRAB_W) x = -CRAB_W;
  return { ...crab, x };
}

function updateGoose(goose) {
  let x = goose.x + goose.state * GOOSE_SPEED;
  if (x < -GOOSE_W) x = CANVAS_W + GOOSE_W;
  if (x > CANVAS_W + GOOSE_W) x = -GOOSE_W;
  return { ...goose, x };
}

function updateClam(clam) {
  const timer = (clam.timer + 1) % CLAM_CYCLE;
  // Open for first half, closed for second half
  const isOpen = timer < CLAM_CYCLE / 2 ? 1 : 0;
  let events = 0;
  if (isOpen === 0 && clam.state === 1) {
    events = 1; // snap event flag
  }
  return { ...clam, timer, state: isOpen, _snapEvent: events };
}

// ── Enemy collision ────────────────────────────────────────────

/**
 * Check if a player collides with any enemy.
 */
export function checkEnemyCollisions(state, playerKey) {
  const player = state[playerKey];
  if (
    player.state === BAILEY_STATE.DEAD ||
    player.state === BAILEY_STATE.FALLING ||
    player.state === BAILEY_STATE.ENTERING_IGLOO
  ) {
    return state;
  }

  const py = getBaileyY(player);
  const px = player.x - BAILEY_W / 2;

  for (const enemy of state.enemies) {
    let ey, ew, eh;

    switch (enemy.type) {
      case ENEMY_TYPE.BEAR:
        if (player.row !== -1) continue; // Bears only on shore
        ey = SHORE_Y + SHORE_H / 2 - BEAR_H / 2;
        ew = BEAR_W;
        eh = BEAR_H;
        break;
      case ENEMY_TYPE.CRAB:
        if (player.row !== enemy.row) continue;
        ey = ROW_Y[enemy.row] - CRAB_H / 2;
        ew = CRAB_W;
        eh = CRAB_H;
        break;
      case ENEMY_TYPE.GOOSE: {
        // Geese fly between rows — check if player is jumping near them
        const gooseY = ROW_Y[enemy.row] + ROW_SPACING / 2 - GOOSE_H / 2;
        if (Math.abs(py - gooseY) > GOOSE_H + BAILEY_H / 2) continue;
        ey = gooseY;
        ew = GOOSE_W;
        eh = GOOSE_H;
        break;
      }
      case ENEMY_TYPE.CLAM:
        if (enemy.state === 0) continue; // Closed = safe
        if (player.row !== enemy.row) continue;
        ey = ROW_Y[enemy.row] - CLAM_H / 2;
        ew = CLAM_W;
        eh = CLAM_H;
        break;
      default:
        continue;
    }

    // AABB collision
    if (
      px < enemy.x + ew &&
      px + BAILEY_W > enemy.x &&
      py - BAILEY_H / 2 < ey + eh &&
      py + BAILEY_H / 2 > ey
    ) {
      // Hit!
      const events = state.events | EVENT.ENEMY_HIT;
      const newPlayer = {
        ...player,
        state: BAILEY_STATE.DEAD,
        lives: player.lives - 1,
      };
      const respawnKey = playerKey === "p1" ? "p1RespawnTimer" : "p2RespawnTimer";
      return {
        ...state,
        [playerKey]: newPlayer,
        [respawnKey]: RESPAWN_DELAY,
        events,
      };
    }
  }

  // Check bear proximity for audio
  let events = state.events;
  if (player.row === -1) {
    for (const enemy of state.enemies) {
      if (enemy.type === ENEMY_TYPE.BEAR) {
        if (Math.abs(player.x - enemy.x) < 60) {
          events |= EVENT.BEAR_NEAR;
          break;
        }
      }
    }
  }

  // Check clam snap events
  for (const enemy of state.enemies) {
    if (enemy.type === ENEMY_TYPE.CLAM && enemy._snapEvent) {
      events |= EVENT.CLAM_SNAP;
      break;
    }
  }

  return { ...state, events };
}

// ── Fish ───────────────────────────────────────────────────────

/**
 * Spawn fish periodically.
 */
export function spawnFish(state) {
  const preset =
    state.mode === GAME_MODE.BLIZZARD
      ? ROUND_PRESETS[4]
      : ROUND_PRESETS[Math.min(state.round - 1, ROUND_PRESETS.length - 1)];

  const timer = state.fishSpawnTimer + 1;
  if (timer < preset.fishRate || state.fish.length >= 4) {
    return { ...state, fishSpawnTimer: timer };
  }

  const fish = [
    ...state.fish,
    {
      x: state.rng() > 0.5 ? -FISH_W : CANVAS_W + FISH_W,
      row: Math.floor(state.rng() * (NUM_ROWS - 1)),
      direction: state.rng() > 0.5 ? 1 : -1,
      collected: 0, // 0=active, 1=p1, 2=p2
    },
  ];

  return { ...state, fish, fishSpawnTimer: 0 };
}

/**
 * Update fish positions and check collection.
 */
export function updateFish(state) {
  let events = state.events;
  const fish = [];

  for (const f of state.fish) {
    if (f.collected > 0) continue; // Already collected

    const x = f.x + f.direction * 1.2;
    // Remove if offscreen
    if (x < -FISH_W * 2 || x > CANVAS_W + FISH_W * 2) continue;

    // Fish Y is between rows
    const fishY = ROW_Y[f.row] + ROW_SPACING / 2;

    // Check collection by each player
    let collected = 0;
    for (const key of ["p1", "p2"]) {
      const player = state[key];
      if (player.state === BAILEY_STATE.DEAD || player.state === BAILEY_STATE.FALLING) {
        continue;
      }
      const py = getBaileyY(player);
      const px = player.x;
      if (
        Math.abs(px - x) < (FISH_W + BAILEY_W) / 2 &&
        Math.abs(py - fishY) < (FISH_H + BAILEY_H) / 2
      ) {
        collected = player.playerNum;
        events |= EVENT.FISH_COLLECT;
        break;
      }
    }

    if (collected > 0) {
      const pKey = collected === 1 ? "p1" : "p2";
      state = {
        ...state,
        [pKey]: {
          ...state[pKey],
          score: state[pKey].score + SCORE_FISH,
        },
      };
    } else {
      fish.push({ ...f, x });
    }
  }

  return { ...state, fish, events };
}

// ── Temperature ────────────────────────────────────────────────

/**
 * Update temperature countdown.
 */
export function updateTemperature(state) {
  const drop = state.mode === GAME_MODE.BLIZZARD ? TEMP_DROP_BLIZZARD : TEMP_DROP_RACE;
  // Round 5: 1.5× speed
  const multiplier = state.round >= 5 && state.mode !== GAME_MODE.BLIZZARD ? 1.5 : 1;
  const newTemp = Math.max(0, state.temperature - drop * multiplier);

  let events = state.events;
  if (newTemp <= TEMP_LOW_THRESHOLD && state.temperature > TEMP_LOW_THRESHOLD) {
    events |= EVENT.TEMP_LOW;
  }
  if (newTemp <= 0 && state.temperature > 0) {
    events |= EVENT.TEMP_ZERO;
  }

  return { ...state, temperature: newTemp, events };
}

// ── Respawn ────────────────────────────────────────────────────

/**
 * Handle respawn timers for dead/fallen players.
 */
export function handleRespawns(state) {
  let newState = state;

  for (const key of ["p1", "p2"]) {
    const timerKey = key === "p1" ? "p1RespawnTimer" : "p2RespawnTimer";
    const player = newState[key];

    if (
      (player.state === BAILEY_STATE.DEAD || player.state === BAILEY_STATE.FALLING) &&
      newState[timerKey] > 0
    ) {
      const timer = newState[timerKey] - 1;
      if (timer <= 0) {
        // Respawn on shore
        newState = {
          ...newState,
          [key]: {
            ...player,
            x: player.playerNum === 1 ? 160 : 480,
            row: -1,
            state: BAILEY_STATE.IDLE,
            jumpProgress: 0,
          },
          [timerKey]: 0,
        };
      } else {
        newState = { ...newState, [timerKey]: timer };
      }
    }
  }

  return newState;
}

// ── Igloo & round logic ────────────────────────────────────────

/**
 * Check if a player can enter their igloo (on shore + igloo complete).
 */
export function checkIglooEntry(state) {
  let events = state.events;

  for (const key of ["p1", "p2"]) {
    const player = state[key];
    if (
      player.iglooComplete &&
      player.row === -1 &&
      player.state === BAILEY_STATE.IDLE &&
      player.lives > 0
    ) {
      // Check position near own igloo
      const iglooX = key === "p1" ? 40 : CANVAS_W - IGLOO_W - 40;
      if (Math.abs(player.x - (iglooX + IGLOO_W / 2)) < IGLOO_W) {
        events |= EVENT.IGLOO_ENTER;
        const tempBonus = Math.round(state.temperature * SCORE_TEMP_MULTIPLIER);
        return {
          ...state,
          [key]: {
            ...player,
            state: BAILEY_STATE.ENTERING_IGLOO,
            score: player.score + tempBonus,
          },
          events,
          roundWinner: player.playerNum,
        };
      }
    }
  }

  return { ...state, events };
}

/**
 * Check if the current round should end.
 */
export function checkRoundEnd(state) {
  // Someone entered their igloo
  if (state.roundWinner > 0) {
    const winnerKey = state.roundWinner === 1 ? "p1" : "p2";
    return {
      ...state,
      phase: PHASE.ROUND_END,
      [winnerKey]: {
        ...state[winnerKey],
        roundWins: state[winnerKey].roundWins + 1,
      },
    };
  }

  // Temperature reached 0
  if (state.temperature <= 0) {
    // Player with more igloo pieces wins the round
    let winner = 0;
    if (state.p1.iglooPieces > state.p2.iglooPieces) winner = 1;
    else if (state.p2.iglooPieces > state.p1.iglooPieces) winner = 2;
    // tie = no one wins

    const result = { ...state, phase: PHASE.ROUND_END, roundWinner: winner };
    if (winner > 0) {
      const winnerKey = winner === 1 ? "p1" : "p2";
      result[winnerKey] = {
        ...result[winnerKey],
        roundWins: result[winnerKey].roundWins + 1,
      };
    }
    return result;
  }

  // Both players out of lives
  if (state.p1.lives <= 0 && state.p2.lives <= 0) {
    return { ...state, phase: PHASE.ROUND_END, roundWinner: 0 };
  }

  return state;
}

/**
 * Start the next round (or finish the match).
 */
export function startNextRound(state) {
  // Check if match is decided
  const maxRounds = state.mode === GAME_MODE.BLIZZARD ? 1 : 5;
  if (
    state.round >= maxRounds ||
    state.p1.roundWins >= ROUNDS_TO_WIN ||
    state.p2.roundWins >= ROUNDS_TO_WIN
  ) {
    return { ...state, phase: PHASE.FINISHED };
  }

  const newRound = state.round + 1;
  const rng = state.rng;
  const temp = state.mode === GAME_MODE.BLIZZARD ? TEMP_START_BLIZZARD : TEMP_START_RACE;

  return {
    ...state,
    phase: PHASE.COUNTDOWN,
    round: newRound,
    countdown: 3,
    temperature: temp,
    p1: {
      ...state.p1,
      x: 160,
      row: -1,
      facing: 1,
      state: BAILEY_STATE.IDLE,
      jumpProgress: 0,
      iglooPieces: 0,
      iglooComplete: false,
      lives: INITIAL_LIVES,
    },
    p2: {
      ...state.p2,
      x: 480,
      row: -1,
      facing: 1,
      state: BAILEY_STATE.IDLE,
      jumpProgress: 0,
      iglooPieces: 0,
      iglooComplete: false,
      lives: INITIAL_LIVES,
    },
    blockRows: createBlockRows(rng, newRound - 1),
    enemies: createEnemiesForRound(rng, newRound, state.mode),
    fish: [],
    roundWinner: 0,
    p1RespawnTimer: 0,
    p2RespawnTimer: 0,
    p1IglooFlash: 0,
    p2IglooFlash: 0,
    fishSpawnTimer: 0,
  };
}

/**
 * Determine the overall match winner.
 * @returns {number} 0=draw, 1=P1, 2=P2
 */
export function determineWinner(state) {
  if (state.p1.roundWins > state.p2.roundWins) return 1;
  if (state.p2.roundWins > state.p1.roundWins) return 2;
  // Tiebreak by total score
  if (state.p1.score > state.p2.score) return 1;
  if (state.p2.score > state.p1.score) return 2;
  return 0;
}

// ── Flash timers ───────────────────────────────────────────────

/**
 * Tick down igloo flash timers.
 */
export function updateFlashTimers(state) {
  return {
    ...state,
    p1IglooFlash: Math.max(0, state.p1IglooFlash - 1),
    p2IglooFlash: Math.max(0, state.p2IglooFlash - 1),
  };
}

// ── Pack / unpack (nested ↔ flat for protocol) ─────────────────

/**
 * Pack nested state into a flat object for binary encoding.
 */
export function packState(state) {
  const s = {
    phase: state.phase,
    mode: state.mode,
    round: state.round,
    countdown: state.countdown,
    seed: state.seed,
    temperature: state.temperature,

    p1X: state.p1.x,
    p1Row: state.p1.row + 1, // shift so -1 becomes 0
    p1Facing: state.p1.facing === 1 ? 1 : 0,
    p1State: state.p1.state,
    p1JumpProgress: state.p1.jumpProgress,
    p1JumpFromRow: state.p1.jumpFromRow + 1,
    p1JumpToRow: state.p1.jumpToRow + 1,
    p1Lives: state.p1.lives,
    p1Score: state.p1.score,
    p1IglooPieces: state.p1.iglooPieces,
    p1IglooComplete: state.p1.iglooComplete,
    p1RoundWins: state.p1.roundWins,

    p2X: state.p2.x,
    p2Row: state.p2.row + 1,
    p2Facing: state.p2.facing === 1 ? 1 : 0,
    p2State: state.p2.state,
    p2JumpProgress: state.p2.jumpProgress,
    p2JumpFromRow: state.p2.jumpFromRow + 1,
    p2JumpToRow: state.p2.jumpToRow + 1,
    p2Lives: state.p2.lives,
    p2Score: state.p2.score,
    p2IglooPieces: state.p2.iglooPieces,
    p2IglooComplete: state.p2.iglooComplete,
    p2RoundWins: state.p2.roundWins,

    events: state.events,
  };

  // Block rows
  for (let r = 0; r < NUM_ROWS; r++) {
    const row = state.blockRows[r];
    s[`row${r}Direction`] = row.direction;
    s[`row${r}Offset`] = row.offset;
    s[`row${r}BlockCount`] = row.blocks.length;
    s[`row${r}Blocks`] = row.blocks.map((b) => ({
      x: getBlockAbsX(b, row),
      state: b.state,
    }));
  }

  // Enemies
  s.enemyCount = state.enemies.length;
  s.enemies = state.enemies.map((e) => ({
    type: e.type,
    x: e.x,
    row: e.row + 1, // shift -1 → 0
    state: e.type === ENEMY_TYPE.CLAM ? e.state : e.state === -1 ? 0 : 1,
    timer: e.timer,
  }));

  // Fish
  s.fishCount = state.fish.length;
  s.fish = state.fish.map((f) => ({
    x: f.x,
    row: f.row,
    collected: f.collected,
  }));

  return s;
}

/**
 * Unpack a flat decoded state into nested format for rendering.
 */
export function unpackState(s) {
  const state = {
    phase: s.phase,
    mode: s.mode,
    round: s.round,
    countdown: s.countdown,
    seed: s.seed,
    temperature: s.temperature,

    p1: {
      x: s.p1X,
      row: s.p1Row - 1,
      facing: s.p1Facing === 1 ? 1 : -1,
      state: s.p1State,
      jumpProgress: s.p1JumpProgress,
      jumpFromRow: s.p1JumpFromRow - 1,
      jumpToRow: s.p1JumpToRow - 1,
      lives: s.p1Lives,
      score: s.p1Score,
      iglooPieces: s.p1IglooPieces,
      iglooComplete: s.p1IglooComplete,
      roundWins: s.p1RoundWins,
      playerNum: 1,
    },
    p2: {
      x: s.p2X,
      row: s.p2Row - 1,
      facing: s.p2Facing === 1 ? 1 : -1,
      state: s.p2State,
      jumpProgress: s.p2JumpProgress,
      jumpFromRow: s.p2JumpFromRow - 1,
      jumpToRow: s.p2JumpToRow - 1,
      lives: s.p2Lives,
      score: s.p2Score,
      iglooPieces: s.p2IglooPieces,
      iglooComplete: s.p2IglooComplete,
      roundWins: s.p2RoundWins,
      playerNum: 2,
    },

    blockRows: [],
    enemies: [],
    fish: [],
    events: s.events,

    p1IglooFlash: 0,
    p2IglooFlash: 0,
  };

  // Block rows
  for (let r = 0; r < NUM_ROWS; r++) {
    state.blockRows.push({
      direction: s[`row${r}Direction`],
      offset: 0, // Peer uses absolute positions
      blocks: (s[`row${r}Blocks`] || []).map((b) => ({
        x: b.x,
        state: b.state,
      })),
      totalWidth: BLOCKS_PER_ROW * (BLOCK_W + BLOCK_GAP),
    });
  }

  // Enemies
  state.enemies = (s.enemies || []).map((e) => ({
    type: e.type,
    x: e.x,
    row: e.row - 1,
    state: e.type === ENEMY_TYPE.CLAM ? e.state : e.state === 0 ? -1 : 1,
    timer: e.timer,
  }));

  // Fish
  state.fish = (s.fish || []).map((f) => ({
    x: f.x,
    row: f.row,
    collected: f.collected,
  }));

  return state;
}
