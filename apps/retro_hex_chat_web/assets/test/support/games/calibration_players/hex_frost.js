/**
 * A scripted Hex Frost player for the AI calibration: an average person at
 * the keyboard. It sees the ice `reaction` frames late, rethinks its plan
 * that often, judges where it stands within `aimNoise` pixels, and jumps
 * once it believes it will land `margin` pixels inside a block. It keeps its
 * footing on the block it stands on, runs from the bear, and goes home once
 * the igloo is built.
 */

import {
  BAILEY_STATE,
  BLOCK_STATE,
  ENEMY_TYPE,
  GAME_MODE,
  PHASE,
} from "../../../../js/lib/games/hex_frost/protocol.js";
import { avoidBear, bearNear, footingSpan } from "../../../../js/lib/games/hex_frost/ai.js";
import {
  BLOCK_W,
  CANVAS_W,
  IGLOO_W,
  JUMP_DURATION,
  NUM_ROWS,
  getBlockAbsX,
  getBlockSpeed,
} from "../../../../js/lib/games/hex_frost/physics.js";

const NEUTRAL = Object.freeze({ left: false, right: false, up: false, down: false });
const BEAR_REACH = 40;
const HAZARD_REACH = 22;

/**
 * @param {object} options
 * @param {() => number} options.rng - draws in [0, 1)
 * @param {1|2} [options.player]
 * @param {number} [options.reaction] - frames between seeing and answering
 * @param {number} [options.aimNoise] - pixels the player misjudges its spot by
 * @param {number} [options.margin] - pixels inside a block it wants to land
 * @returns {{ nextInputs: (request: { state: object }) => object }}
 */
export function createFrostPlayer({ rng, player = 1, reaction = 12, aimNoise = 6, margin = 8 }) {
  const key = player === 1 ? "p1" : "p2";
  const own = player === 1 ? BLOCK_STATE.BLUE_P1 : BLOCK_STATE.BLUE_P2;
  const theirs = player === 1 ? BLOCK_STATE.BLUE_P2 : BLOCK_STATE.BLUE_P1;
  const home = player === 1 ? 40 + IGLOO_W / 2 : CANVAS_W - IGLOO_W - 40 + IGLOO_W / 2;
  const seen = [];
  let frame = 0;
  let heading = 1;
  let plan = null;
  let error = 0;

  const noise = () => (rng() + rng() + rng() - 1.5) * 2 * aimNoise;

  function usefulBlock(state, block) {
    if (block.state === BLOCK_STATE.WHITE) return true;
    return state.mode !== GAME_MODE.PEACEFUL && block.state === theirs;
  }

  function planNext(view, me) {
    if (me.iglooComplete) return { row: me.row - 1 };
    if (me.row === -1) heading = 1;
    if (me.row + heading >= NUM_ROWS || (me.row + heading < 0 && me.row >= 0)) heading = -heading;
    const rows = me.row === -1 ? [0] : [me.row + heading, me.row - heading];
    for (const row of rows) {
      if (row < 0 || row >= NUM_ROWS) continue;
      const pick = pickBlock(view, me, row);
      if (pick) {
        if (me.row >= 0) heading = row > me.row ? 1 : -1;
        return pick;
      }
    }
    return null;
  }

  function pickBlock(view, me, rowIndex) {
    const row = view.blockRows[rowIndex];
    const ahead = row.direction * getBlockSpeed(view) * (reaction + JUMP_DURATION);
    let best = null;
    row.blocks.forEach((block, index) => {
      if (!usefulBlock(view, block) || block.state === own) return;
      const left = getBlockAbsX(block, row);
      if (left < 0 || left + BLOCK_W > CANVAS_W) return;
      const distance = Math.abs(left + ahead + BLOCK_W / 2 - me.x);
      if (!best || distance < best.distance) best = { row: rowIndex, index, distance };
    });
    return best;
  }

  return {
    nextInputs({ state }) {
      frame++;
      if (!state || state.phase !== PHASE.BUILDING) {
        seen.length = 0;
        plan = null;
        heading = 1;
        return NEUTRAL;
      }
      seen.push(state);
      if (seen.length > reaction + 1) seen.shift();
      const view = seen[0];

      const me = state[key];
      if (me.state !== BAILEY_STATE.IDLE && me.state !== BAILEY_STATE.WALKING) {
        plan = null;
        return NEUTRAL;
      }
      const seenMe = view[key];
      const settled =
        (seenMe.state === BAILEY_STATE.IDLE || seenMe.state === BAILEY_STATE.WALKING) &&
        seenMe.row === me.row;
      if (!settled) return keepFooting(state, me, me.x);

      if (!plan || frame % reaction === 0) {
        plan = planNext(view, me);
        error = noise();
      }
      if (!plan) return keepFooting(state, me, me.x);

      if (me.row === -1 && me.iglooComplete) {
        return walkTo(state, me, avoidBear(view, me.x, home, BEAR_REACH));
      }
      if (plan.row === -1) {
        if (bearNear(view, me.x, BEAR_REACH)) return keepFooting(state, me, me.x);
        return { ...NEUTRAL, up: true };
      }

      const row = state.blockRows[plan.row];
      const block = row.blocks[plan.index];
      if (!block) return keepFooting(state, me, me.x);
      const landing =
        getBlockAbsX(block, row) + row.direction * getBlockSpeed(state) * JUMP_DURATION;
      if (landing < 0 || landing + BLOCK_W > CANVAS_W) {
        plan = null;
        return keepFooting(state, me, me.x);
      }
      const judged = me.x + error;
      const inside = Math.min(judged - landing, landing + BLOCK_W - judged);
      if (inside >= margin && !hazardAt(view, plan.row, me.x)) {
        return { ...NEUTRAL, [plan.row < me.row ? "up" : "down"]: true };
      }
      const goal = landing + BLOCK_W / 2 - error;
      if (me.row === -1) return walkTo(state, me, avoidBear(view, me.x, goal, BEAR_REACH));
      return keepFooting(state, me, goal);
    },
  };
}

function keepFooting(state, me, goal) {
  const span = footingSpan(state, me);
  return walkTo(state, me, span ? Math.max(span[0], Math.min(span[1], goal)) : goal);
}

function walkTo(_state, me, goal) {
  return { ...NEUTRAL, left: goal < me.x - 3, right: goal > me.x + 3 };
}

function hazardAt(view, rowIndex, x) {
  return view.enemies.some(
    (enemy) =>
      (enemy.type === ENEMY_TYPE.CRAB || enemy.type === ENEMY_TYPE.CLAM) &&
      enemy.row === rowIndex &&
      Math.abs(enemy.x - x) < HAZARD_REACH,
  );
}
