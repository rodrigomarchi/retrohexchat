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

import { defineGame } from "../core/define_game.js";
import { matchResult } from "../core/result.js";
import { HexSkiingAudio } from "./audio.js";
import { normalizeSkiingAIDifficulty } from "./difficulty.js";
import {
  checkCollisions,
  checkGameOver,
  checkGates,
  createInitialState,
  determineWinner,
  ensureChunks,
  ensureGates,
  getScrollSpeed,
  packState,
  startNextRound,
  unpackState,
  updateAvalanche,
  updateBlizzard,
  updateItems,
  updateScroll,
  updateSkier,
} from "./physics.js";
import { EVENT, GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { generateSnowParticles, readColors, render } from "./renderer.js";

const COUNTDOWN_STEPS = 60; // steps per countdown beat
const ROUND_END_STEPS = 180; // steps the round's end shows
const COUNTDOWN_FROM = 3;

const MODE_MAP = {
  hex_skiing_escape: GAME_MODE.AVALANCHE_ESCAPE,
  hex_skiing_clean: GAME_MODE.CLEAN_RUN,
};

/** The sounds of a step's events, a bit field; host and guest hear the same. */
export function playEvents(audio, events) {
  if (events & EVENT.COLLISION_TREE) audio.playCollisionTree();
  if (events & EVENT.COLLISION_ROCK) audio.playCollisionRock();
  if (events & EVENT.GATE_CLEARED) audio.playGateCleared();
  if (events & EVENT.SPEED_BOOST) audio.playSpeedBoost();
  if (events & EVENT.ICE_PATCH) audio.playIcePatch();
  if (events & EVENT.BLIZZARD_START) audio.playBlizzardStart();
  if (events & EVENT.BLIZZARD_END) audio.playBlizzardEnd();
  if (events & EVENT.ENGULFED) audio.playEngulfed();
}

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
  let state = previous;
  state.p1 = updateSkier(state.p1, game.localInputs);
  state.p2 = updateSkier(state.p2, game.remoteInputs);
  state = updateScroll(state);
  state = ensureChunks(state);
  state = ensureGates(state);
  state = updateItems(state);
  state = checkCollisions(state);
  state = checkGates(state);
  state = updateAvalanche(state);
  state = updateBlizzard(state);

  const prevPhase = state.phase;
  state = checkGameOver(state);
  if (state.phase === PHASE.ROUND_END && prevPhase === PHASE.RACING) {
    game.roundEndTimer = ROUND_END_STEPS;
    game.audio.playRoundEnd();
  }
  if (state.phase === PHASE.FINISHED && prevPhase !== PHASE.FINISHED) finishMatch(game, state);

  playEvents(game.audio, state.events);
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
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
  },
  captureKeys: ["ArrowLeft", "ArrowRight", "a", "A", "d", "D"],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    difficulty: normalizeSkiingAIDifficulty,
    observe: (game) => ({ state: game.gameState, player: 2, difficulty: game.difficulty }),
  },
  audio: HexSkiingAudio,
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
    if (game.isHost) {
      const seed = (game.random() * 0xffffffff) >>> 0;
      game.gameState = createInitialState(game.gameMode, seed);
    }
  },
  onStop: (game) => {
    game.localInputs = { left: false, right: false };
    game.remoteInputs = { left: false, right: false };
    game.peerReady = false;
    game.frameCount = 0;
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
        steps: true,
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
      COUNTDOWN: { steps: true, tick: step },
      RACING: { steps: true, tick: step },
      ROUND_END: { steps: true, tick: step },
      FINISHED: { final: true },
    },
  },

  toWire: (game) => packState(game.gameState),
  applySnapshot: (game, decoded) => {
    game.gameMode = decoded.mode;
    game.gameState = unpackState(decoded);
    playEvents(game.audio, decoded.events);
  },
  onEnd: (game, result) => {
    if (game.gameState) game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
    game.invalidate();
    game.setKeyboardCaptured(false);
    game.audio.stopSkiDrone();
    if (game.outcome(result.winner) === "win") game.audio.playVictory();
    else game.audio.playGameOver();
  },
  render: (game) => {
    render(game.ctx, game.gameState, game.colors, game.frameCount, game.snowParticles);
  },
  disconnectResult: (game) =>
    matchResult(game.gameState.p1RoundWins || 0, game.gameState.p2RoundWins || 0, 0),
});
