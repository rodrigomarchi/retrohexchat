/**
 * Hex Frost: two builders hop across drifting floes to claim blocks and
 * finish an igloo before the cold gets them. Three modes: Arctic Race,
 * Blizzard and Peaceful.
 *
 * Host-authoritative, counted in frames: the countdown and the pause after a
 * round run inside the simulation step. The match lifecycle comes from
 * `defineGame`; this file says only what is Frost's.
 *
 * @module games/hex_frost
 */

import { defineGame } from "../core/define_game.js";
import { createHexFrostAI } from "./ai.js";
import { HexFrostAudio } from "./audio.js";
import { normalizeFrostAIDifficulty } from "./difficulty.js";
import {
  checkEnemyCollisions,
  checkIglooEntry,
  checkRoundEnd,
  createInitialState,
  determineWinner,
  handleRespawns,
  packState,
  spawnFish,
  startNextRound,
  unpackState,
  updateBailey,
  updateBlocks,
  updateEnemies,
  updateFish,
  updateFlashTimers,
  updateTemperature,
} from "./physics.js";
import { EVENT, GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { generateSnowParticles, readColors, render } from "./renderer.js";

const COUNTDOWN_INTERVAL = 60; // frames per countdown tick
const ROUND_END_DELAY = 180; // frames the round-end screen stays

const MODES = {
  hex_frost_blizzard: GAME_MODE.BLIZZARD,
  hex_frost_peaceful: GAME_MODE.PEACEFUL,
};

const EVENT_SOUNDS = [
  [EVENT.BLOCK_CLAIM, "playBlockClaim"],
  [EVENT.BLOCK_STEAL, "playBlockSteal"],
  [EVENT.BLOCK_UNDO, "playBlockUndo"],
  [EVENT.JUMP, "playJump"],
  [EVENT.LAND, "playLand"],
  [EVENT.SPLASH, "playSplash"],
  [EVENT.FISH_COLLECT, "playFishCollect"],
  [EVENT.ENEMY_HIT, "playEnemyHit"],
  [EVENT.IGLOO_PIECE, "playIglooPiece"],
  [EVENT.IGLOO_LOSE, "playIglooLose"],
  [EVENT.IGLOO_COMPLETE, "playIglooComplete"],
  [EVENT.IGLOO_ENTER, "playIglooEnter"],
  [EVENT.TEMP_LOW, "playTempLow"],
  [EVENT.TEMP_ZERO, "playTempZero"],
  [EVENT.BEAR_NEAR, "playBearNear"],
  [EVENT.CLAM_SNAP, "playClamSnap"],
];

function playEvents(game, events) {
  for (const [bit, sound] of EVENT_SOUNDS) {
    if (events & bit) game.audio[sound]();
  }
}

/** The frame's bookkeeping, shared by every phase that steps. */
function nextFrame(game) {
  game.frameCount++;
  return { ...game.gameState, events: 0, frameCount: game.frameCount };
}

function publish(game, state) {
  game.gameState = state;
  game.invalidate();
  game.broadcast();
}

function countdownTick(game) {
  const state = nextFrame(game);
  game.countdownTimer--;
  if (game.countdownTimer <= 0) {
    state.countdown--;
    if (state.countdown <= 0) {
      state.phase = PHASE.BUILDING;
      state.countdown = 0;
      game.setKeyboardCaptured(true);
      game.audio.playCountdownGo();
    } else {
      game.countdownTimer = COUNTDOWN_INTERVAL;
      game.audio.playCountdown();
    }
  }
  publish(game, state);
}

function roundEndTick(game) {
  let state = nextFrame(game);
  game.roundEndTimer--;
  if (game.roundEndTimer <= 0) {
    state = startNextRound(state);
    if (state.phase === PHASE.COUNTDOWN) {
      game.countdownTimer = COUNTDOWN_INTERVAL;
      game.audio.playCountdown();
    }
  }
  publish(game, state);
}

/** The finished match is drawn and sent once more, then the engine stops. */
function finishedTick(game) {
  game.invalidate();
  game.broadcast();
  game._stopSteps();
  game.setKeyboardCaptured(false);
  game.running = false;
}

function buildingTick(game) {
  let state = nextFrame(game);

  game.gameState = state;
  game.updateOpponent();

  state = updateBlocks(state);
  state = updateBailey(state, "p1", game.localInputs);
  game.localInputs.up = false;
  game.localInputs.down = false;
  state = updateBailey(state, "p2", game.remoteInputs);
  game.remoteInputs.up = false;
  game.remoteInputs.down = false;
  state = updateEnemies(state);
  state = spawnFish(state);
  state = updateFish(state);
  state = checkEnemyCollisions(state, "p1");
  state = checkEnemyCollisions(state, "p2");
  state = handleRespawns(state);
  state = updateTemperature(state);
  state = checkIglooEntry(state);

  const prevPhase = state.phase;
  state = checkRoundEnd(state);
  if (state.phase === PHASE.ROUND_END && prevPhase === PHASE.BUILDING) {
    game.roundEndTimer = ROUND_END_DELAY;
    game.audio.playRoundEnd();
  }
  if (state.phase === PHASE.FINISHED && prevPhase !== PHASE.FINISHED) finishMatch(game, state);

  state = updateFlashTimers(state);
  playEvents(game, state.events);
  publish(game, state);
}

/**
 * End the match once, whichever way it got there: inside the step that
 * reaches it, or on entering FINISHED from the round that decided it.
 */
function finishMatch(game, state) {
  if (game.matchFinished) return;
  game.matchFinished = true;
  const winner = determineWinner(state);
  game.audio.stopAmbientWind();
  if (winner > 0) game.audio.playVictory();
  else game.audio.playGameOver();

  const result = { score1: state.p1.roundWins, score2: state.p2.roundWins, winner };
  game.finish({ end: result, result, broadcast: false });
}

export default defineGame({
  inputs: {
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
  },
  captureKeys: [
    "ArrowLeft",
    "ArrowRight",
    "ArrowUp",
    "ArrowDown",
    "a",
    "A",
    "d",
    "D",
    "w",
    "W",
    "s",
    "S",
  ],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    create: createHexFrostAI,
    difficulty: normalizeFrostAIDifficulty,
    observe: (game) => ({ state: game.gameState, player: 2, difficulty: game.difficulty }),
  },
  audio: HexFrostAudio,
  theme: readColors,
  init: () => null,
  setup: (game) => {
    game.gameMode = MODES[game.gameId] ?? GAME_MODE.ARCTIC_RACE;
    game.countdownTimer = 0;
    game.roundEndTimer = 0;
    game.snowParticles = null;
    game.matchFinished = false;
  },
  onStart: (game) => {
    game.snowParticles = generateSnowParticles(35);
    if (game.mode === "solo" || game.isHost) {
      const seed = (Math.random() * 0xffffffff) >>> 0;
      game.gameState = createInitialState(game.gameMode, seed);
    }
  },
  onStop: (game) => {
    game.localInputs = { left: false, right: false, up: false, down: false };
    game.remoteInputs = { left: false, right: false, up: false, down: false };
    game.peerReady = false;
    game.frameCount = 0;
    game.countdownTimer = 0;
    game.roundEndTimer = 0;
    game.audio.stopAmbientWind();
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: {
        steps: true,
        // A later round's countdown is set up by the simulation itself.
        enter: (game) => {
          if (game.flow.previous !== "WAITING") return;
          game.gameState.countdown = 3;
          game.countdownTimer = COUNTDOWN_INTERVAL;
          game.setKeyboardCaptured(true);
          game.audio.playCountdown();
          game.audio.startAmbientWind();
          game.broadcast();
        },
        tick: countdownTick,
      },
      BUILDING: { steps: true, tick: buildingTick },
      ROUND_END: { steps: true, tick: roundEndTick },
      FINISHED: {
        final: true,
        steps: true,
        enter: (game) => finishMatch(game, game.gameState),
        tick: finishedTick,
      },
    },
  },

  toWire: (game) => packState(game.gameState),
  applySnapshot: (game, decoded) => {
    game.gameMode = decoded.mode;
    game.gameState = unpackState(decoded);
    playEvents(game, decoded.events);
  },
  onEnd: (game, result) => {
    if (game.gameState) game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
    game.invalidate();
    game.setKeyboardCaptured(false);
    game.audio.stopAmbientWind();
    if (result.winner > 0) game.audio.playVictory();
    else game.audio.playGameOver();
    game.onGameEnd?.(result);
  },
  render: (game) =>
    render(game.ctx, game.gameState, game.colors, game.frameCount, game.snowParticles),
  disconnectResult: (game) => ({
    winner: "draw",
    score_p1: game.gameState.p1?.roundWins ?? game.gameState.p1RoundWins ?? 0,
    score_p2: game.gameState.p2?.roundWins ?? game.gameState.p2RoundWins ?? 0,
  }),
});
