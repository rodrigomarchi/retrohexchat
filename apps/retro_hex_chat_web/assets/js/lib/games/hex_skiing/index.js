/**
 * Hex Skiing: two skiers down a generated slope through gates, trees and an
 * avalanche, best of the rounds.
 *
 * Host-authoritative; the host draws the slope's seed when it starts, and
 * the state travels packed flat. Every phase is counted in steps: the
 * countdown, the race and the round's end are one simulation that moves
 * itself on, so they share one step. The AI is loaded by the page, not
 * bundled here. The match lifecycle comes from `defineGame`; this file says
 * only what is Skiing's.
 *
 * @module games/hex_skiing
 */

import { ARROW_KEYS, defineGame, drawSeed, packedSnapshot } from "../core/define_game.js";
import { playFlags } from "../core/events.js";
import { drawOnDisconnect, matchResult, raceEnd } from "../core/result.js";
import { normalizeSkiingAIDifficulty } from "./difficulty.js";
import {
  createInitialState,
  determineWinner,
  // ex_dna:disable-for-lines:9 this game's own imports
  getScrollSpeed,
  packState,
  startNextRound,
  stepTick,
  unpackState,
} from "./physics.js";
import { EVENT, GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { generateSnowParticles, readColors, render } from "./renderer.js";
import { SOUNDS, extend } from "./sounds.js";

const COUNTDOWN_STEPS = 60; // steps per countdown beat
const ROUND_END_STEPS = 180; // steps the round's end shows
const COUNTDOWN_FROM = 3;

const MODE_MAP = {
  hex_skiing_escape: GAME_MODE.AVALANCHE_ESCAPE,
  hex_skiing_clean: GAME_MODE.CLEAN_RUN,
};

/** The sound of each event bit, in the order they are heard; host and guest hear the same. */
export const EVENT_SOUNDS = [
  [EVENT.COLLISION_TREE, "collisionTree"],
  [EVENT.COLLISION_ROCK, "collisionRock"],
  [EVENT.GATE_CLEARED, "gateCleared"],
  [EVENT.SPEED_BOOST, "speedBoost"],
  [EVENT.ICE_PATCH, "icePatch"],
  [EVENT.BLIZZARD_START, "blizzardStart"],
  [EVENT.BLIZZARD_END, "blizzardEnd"],
  [EVENT.ENGULFED, "engulfed"],
];

/** A countdown beat every COUNTDOWN_STEPS; the last one starts the race. */
function countdown(game, state) {
  game.countdownFrames--;
  if (game.countdownFrames > 0) return;
  state.countdown--;
  if (state.countdown <= 0) {
    state.phase = PHASE.RACING;
    state.countdown = 0;
    game.setKeyboardCaptured(true);
    game.audio.playCountdownGo();
  } else {
    game.countdownFrames = COUNTDOWN_STEPS;
    game.audio.playCountdown();
  }
}

/** The round's end shows for a while, then the next round counts down. */
function roundEnd(game, state) {
  game.roundEndTimer--;
  if (game.roundEndTimer > 0) return state;
  game.countdownFrames = COUNTDOWN_STEPS;
  game.audio.playCountdown();
  return startNextRound(state);
}

/** The match ends inside the step that reaches it, before the step's sounds and snapshot. */
export function finishMatch(game, state) {
  const winner = determineWinner(state);
  game.audio.stopSkiDrone();
  if (game.outcome(winner) === "win") game.audio.playVictory();
  else game.audio.playGameOver();
  const end = { score1: state.p1RoundWins, score2: state.p2RoundWins, winner };
  game.finish({ end, result: matchResult(end.score1, end.score2, winner), broadcast: false });
}

function race(game, previous) {
  // The AI sees the step's state with last step's events already cleared.
  game.gameState = previous;
  game.updateOpponent();
  const prevPhase = previous.phase;
  const state = stepTick(previous, { p1: game.localInputs, p2: game.remoteInputs });
  if (state.phase === PHASE.ROUND_END && prevPhase === PHASE.RACING) {
    game.roundEndTimer = ROUND_END_STEPS;
    game.audio.playRoundEnd();
  }
  if (state.phase === PHASE.FINISHED && prevPhase !== PHASE.FINISHED) finishMatch(game, state);

  playFlags(game, EVENT_SOUNDS, state.events);
  game.audio.updateSkiPitch(Math.max(getScrollSpeed(state.p1), getScrollSpeed(state.p2)));
  if (state.mode !== GAME_MODE.CLEAN_RUN) {
    const avalancheScreenY = state.avalancheY - state.scrollY;
    const proximity = Math.max(0, Math.min(1, avalancheScreenY / 380));
    if (proximity > 0.3 && game.frameCount % 20 === 0) game.audio.playAvalancheRumble(proximity);
  }
  state.frameCount = game.frameCount;
  return state;
}

function step(game) {
  if (!game.isHost || !game.gameState) return;
  game.frameCount++;
  let state = { ...game.gameState, events: 0 };

  if (state.phase === PHASE.COUNTDOWN) countdown(game, state);
  else if (state.phase === PHASE.ROUND_END) state = roundEnd(game, state);
  else if (state.phase === PHASE.RACING) state = race(game, state);
  else {
    game.invalidate();
    return;
  }

  game.gameState = state;
  game.invalidate();
  game.broadcast();
}

export default defineGame({
  inputs: {
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
  },
  captureKeys: ["ArrowLeft", "ArrowRight", "a", "A", "d", "D"],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    difficulty: normalizeSkiingAIDifficulty,
    observe: (game) => ({ state: game.gameState, player: 2, difficulty: game.difficulty }),
  },
  audio: { sounds: SOUNDS, extend },
  theme: readColors,
  // There is no slope until the host draws its seed on start.
  init: (game) => {
    game.gameMode = MODE_MAP[game.gameId] ?? GAME_MODE.ALPINE_RACE;
    return null;
  },
  setup: (game) => {
    game.countdownFrames = 0;
    game.roundEndTimer = 0;
    game.snowParticles = null;
  },
  onStart: (game) => {
    game.snowParticles = generateSnowParticles(40);
    // ex_dna:disable-for-lines:7 this game's own defineGame definition
    if (game.isHost) {
      game.gameState = createInitialState(game.gameMode, drawSeed(game));
    }
  },
  onStop: (game) => {
    game.forgetMatch();
    game.countdownFrames = 0;
    game.roundEndTimer = 0;
    game.audio.stopSkiDrone();
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "STARTING",
    states: {
      // The first countdown starts the drone and the steps; later ones come
      // from the round's end, inside the step.
      STARTING: {
        as: "COUNTDOWN",
        enter: (game) => {
          game.gameState.countdown = COUNTDOWN_FROM;
          game.countdownFrames = COUNTDOWN_STEPS;
          game.setKeyboardCaptured(true);
          game.audio.playCountdown();
          game.broadcast();
          game.audio.startSkiDrone();
        },
        tick: step,
      },
      COUNTDOWN: { tick: step },
      RACING: { tick: step },
      ROUND_END: { tick: step },
      // ex_dna:disable-for-lines:7 this game's own defineGame definition
      FINISHED: { final: true },
    },
  },

  ...packedSnapshot(packState, unpackState),
  cues: [{ flags: (s) => s.events, sounds: EVENT_SOUNDS }],
  onEnd: raceEnd(PHASE.FINISHED, (game) => game.audio.stopSkiDrone()),
  render: (game) => {
    render(game.ctx, game.gameState, game.colors, game.frameCount, game.snowParticles);
  },
  disconnectResult: drawOnDisconnect((s) => [s.p1RoundWins || 0, s.p2RoundWins || 0]),
});
