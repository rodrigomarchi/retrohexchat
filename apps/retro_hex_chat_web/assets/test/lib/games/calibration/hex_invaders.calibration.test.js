import { calibrate } from "../../../support/games/calibration.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createHexInvadersAI } from "../../../../js/lib/games/hex_invaders/ai.js";
import {
  CANNON_W,
  CANVAS_W,
  HALF_W,
  checkWaveClear,
  createInitialState,
  createWave,
  stepTick,
} from "../../../../js/lib/games/hex_invaders/physics.js";
import { ALIEN_TYPE, GAME_MODE, PHASE } from "../../../../js/lib/games/hex_invaders/protocol.js";

const RELEASED = { left: false, right: false, fire: false };
const BETWEEN_WAVES_TICKS = 180; // the wave-clear and wave-start overlays
const MATCH_LIMIT_TICKS = 60 * 60 * 20;

// The average player: takes a fresh look every 12 frames (200 ms), aims
// within 6 px of the alien it picked, presses fire on about a third of the
// frames it is lined up, and sees four bombs in five coming down at it.
const PLAYER = { lookEvery: 12, aimError: 6, aimTolerance: 4, fireOdds: 0.3, noticeOdds: 0.8 };

function averagePlayer(random) {
  let target = null;
  let age = Infinity;
  const noticed = new Map();

  return (state) => {
    const x = state.cannon1X;
    const max = state.mode === GAME_MODE.COOP ? CANVAS_W : HALF_W;
    for (const bomb of state.bombs) {
      if (bomb.side !== 1 && state.mode !== GAME_MODE.COOP) continue;
      if (bomb.y <= 340 || Math.abs(bomb.x - x) >= 24) continue;
      if (!noticed.has(bomb.id)) noticed.set(bomb.id, random() < PLAYER.noticeOdds);
      if (!noticed.get(bomb.id)) continue;
      const away = bomb.x <= x ? 1 : -1;
      const room = x + away * 40 > CANNON_W && x + away * 40 < max - CANNON_W;
      const go = room ? away : -away;
      return { left: go < 0, right: go > 0, fire: false };
    }

    if (age++ >= PLAYER.lookEvery || state.aliens1[target?.index]?.type !== target?.type) {
      age = 0;
      let best = null;
      let bestScore = -Infinity;
      state.aliens1.forEach((alien, index) => {
        if (alien.type === ALIEN_TYPE.NONE) return;
        const score = alien.y * 1.8 - Math.abs(alien.x + 5 - x);
        if (score > bestScore) {
          bestScore = score;
          best = { index, type: alien.type, x: alien.x + 5 };
        }
      });
      target = best && { ...best, x: best.x + (random() * 2 - 1) * PLAYER.aimError };
    }
    if (!target) return RELEASED;

    const dx = target.x - x;
    const lined = Math.abs(dx) <= PLAYER.aimTolerance;
    return {
      left: dx < -3,
      right: dx > 3,
      fire: lined && !state.m1Active && random() < PLAYER.fireOdds,
    };
  };
}

/**
 * A match, the average player at the left cannon, until it ends or — for a
 * shorter trial — `waves` waves are cleared: who won, and the waves cleared.
 */
function playMatch(mode, difficulty, seed, waves = Infinity) {
  const random = mulberry32(seed);
  const player = averagePlayer(mulberry32(seed ^ 0x5bd1e995));
  const ai = createHexInvadersAI({ difficulty, rng: mulberry32(seed ^ 0x27d4eb2f) });
  let held = { local: false, remote: false };
  let state = { ...createWave(createInitialState(mode, (random() * 0xffffffff) >>> 0), 1) };
  state.phase = PHASE.PLAYING;
  let pause = 0;

  for (let tick = 0; tick < MATCH_LIMIT_TICKS; tick++) {
    if (pause > 0) {
      if (--pause === 0) {
        state = { ...createWave(state, state.wave + 1), phase: PHASE.PLAYING };
        // The engine has the AI forget at every phase change: a wave starts clean.
        ai.forget();
      }
      continue;
    }
    const remote = ai.nextInputs({ state, difficulty, player: 2 });
    const step = stepTick(state, player(state), remote, held);
    ({ state, held } = step);
    const cleared = checkWaveClear(state) ? state.wave : state.wave - 1;
    if (step.over.ended) return { winner: step.over.winner, cleared };
    if (cleared >= waves) return { winner: 0, cleared };
    if (state.phase === PHASE.WAVE_CLEAR) pause = BETWEEN_WAVES_TICKS;
  }
  return { winner: 0, cleared: state.wave - 1 };
}

calibrate("hex_invaders", {
  play: ({ difficulty, seed }) => playMatch(GAME_MODE.INVASION_WAR, difficulty, seed).winner === 2,
});

// In co-op the AI is the player's partner, and the difficulty names the game
// the player chose: an easy game gets the strongest partner. A trial is the
// first wave, and it counts against the team when the team falls before
// clearing it — so the targets are how often the game beats the team, rising
// from easy to hard. Ten whole waves are rarely survived even by a strong
// pair, so a whole co-op match would tell the difficulties apart only by how
// far the team got.
calibrate("hex_invaders co-op", {
  targets: { easy: 0.15, normal: 0.4, hard: 0.65 },
  label: "first waves",
  play: ({ difficulty, seed }) => playMatch(GAME_MODE.COOP, difficulty, seed, 1).cleared < 1,
});
