import { mulberry32 } from "../seeded_random.js";
import { askAsTheEngineDoes } from "./engine_ai.js";
import { createDelayedView, createPerThing } from "../../../../js/lib/games/core/ai.js";
import { aiRandom, createRng } from "../../../../js/lib/games/core/rng.js";
import {
  chooseRaidTarget,
  createHexRaidAI,
  delayedSight,
  movementInputs,
  noticedMines,
  shouldDeployMine,
  shouldFire,
} from "../../../../js/lib/games/hex_raid/ai.js";
import {
  SPEED_BASE,
  createInitialState,
  getWinner,
  stepTick,
} from "../../../../js/lib/games/hex_raid/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_raid/protocol.js";

const RELEASED = {
  left: false,
  right: false,
  accel: false,
  decel: false,
  fire: false,
  mine: false,
};

/** A match that nobody loses three lives in ends here: eight minutes. */
const MAX_FRAMES = 60 * 60 * 8;

/**
 * The average player: sees the river 12 frames (~200 ms) late, makes a new
 * plan every 12 frames that misses its spot by up to 20 px, fires at most
 * every 20 frames at an enemy about 20 px from its nose (and lets 4 in 10 of
 * those go), and cruises at the base speed. It spots 8 in 10 of its
 * rival's mines, and when the rival flies within 24 px of its lane drops a
 * mine 3 times in 10, looking for the next chance a second later. It picks
 * what to chase the way the AI does.
 */
export const AVERAGE_PLAYER = Object.freeze({
  reaction: 12,
  interval: 12,
  error: 20,
  deadzone: 8,
  threatY: 210,
  dodgeX: 54,
  fuelAt: 135,
  fuelY: 270,
  fireY: 290,
  fireX: 20,
  fireOdds: 0.6,
  fireCd: 20,
  mineX: 24,
  mineOdds: 0.3,
  mineCd: 60,
  mineNotice: 0.8,
  cruise: SPEED_BASE,
});

/**
 * A scripted player for jet 1, drawing from `random`.
 * @param {typeof AVERAGE_PLAYER} profile
 * @param {() => number} random
 * @returns {(state: object) => object} the inputs for a step
 */
export function scriptedPlayer(profile, random) {
  const view = createDelayedView();
  const noticed = createPerThing();
  let frame = 0;
  let target = null;
  let cooldown = 0;
  let mineCooldown = 0;

  return (state) => {
    frame++;
    if (cooldown > 0) cooldown--;
    if (mineCooldown > 0) mineCooldown--;
    const sight = delayedSight(view.see(state, profile.reaction), state, 1);
    const seen = noticedMines(sight, 1, noticed, () => random() < profile.mineNotice);
    if (!state.jet1Alive) return RELEASED;

    if (frame % profile.interval === 0 || !target) {
      target = chooseRaidTarget(seen, 1, profile, () => (random() - 0.5) * profile.error * 2);
    }

    const fire = cooldown === 0 && shouldFire(seen, 1, profile) && random() < profile.fireOdds;
    if (fire) cooldown = profile.fireCd;
    let mine = false;
    if (mineCooldown === 0 && shouldDeployMine(seen, 1, profile)) {
      mineCooldown = profile.mineCd;
      mine = random() < profile.mineOdds;
    }
    return { ...movementInputs(state, 1, target, profile.deadzone), fire, mine };
  };
}

/**
 * One seeded solo match of Hex Raid, played the way the game's host steps
 * it: a scripted player on jet 1 against the AI on jet 2.
 * @param {object} options
 * @param {string} options.difficulty
 * @param {number} options.seed
 * @param {typeof AVERAGE_PLAYER} [options.profile]
 * @param {number} [options.mode]
 * @returns {{ winner: 1 | 2, score1: number, score2: number, frames: number }}
 */
export function playRaidMatch({ difficulty, seed, profile = AVERAGE_PLAYER, mode }) {
  const riverSeed = ((createRng(seed).next() * 0xffffffff) | 0) >>> 0;
  const ai = askAsTheEngineDoes(createHexRaidAI({ difficulty, rng: aiRandom(seed) }), difficulty);
  const player = scriptedPlayer(profile, mulberry32(seed ^ 0x9e3779b9));
  let held = { 1: { fire: false, mine: false }, 2: { fire: false, mine: false } };

  let state = {
    ...createInitialState(mode ?? GAME_MODE.RIVER_DUEL, riverSeed),
    phase: PHASE.FLYING,
  };
  let frame = 0;
  for (; frame < MAX_FRAMES && state.phase === PHASE.FLYING; frame++) {
    const keys = { 2: ai(state), 1: player(state) };
    ({ state, held } = stepTick(state, keys, held, frame));
  }

  return { winner: getWinner(state), score1: state.score1, score2: state.score2, frames: frame };
}
