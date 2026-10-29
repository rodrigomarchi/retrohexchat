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

import { ARROW_KEYS, defineGame, drawSeed, packedSnapshot } from "../core/define_game.js";
import { playFlags } from "../core/events.js";
import { drawOnDisconnect, matchResult, raceEnd } from "../core/result.js";
import { createHexFrostAI } from "./ai.js";
import { normalizeFrostAIDifficulty } from "./difficulty.js";
import {
  createInitialState,
  // ex_dna:disable-for-lines:9 this game's own imports
  determineWinner,
  packState,
  startNextRound,
  stepTick,
  unpackState,
} from "./physics.js";
import { EVENT, GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { generateSnowParticles, readColors, render } from "./renderer.js";
import { MASTER_VOLUME, SOUNDS, extend } from "./sounds.js";

const COUNTDOWN_INTERVAL = 60; // frames per countdown tick
const ROUND_END_DELAY = 180; // frames the round-end screen stays

const MODES = {
  hex_frost_blizzard: GAME_MODE.BLIZZARD,
  hex_frost_peaceful: GAME_MODE.PEACEFUL,
};

/** The sound of each event bit; host and guest hear the same. */
const EVENT_SOUNDS = [
  [EVENT.BLOCK_CLAIM, "blockClaim"],
  [EVENT.BLOCK_STEAL, "blockSteal"],
  [EVENT.BLOCK_UNDO, "blockUndo"],
  [EVENT.JUMP, "jump"],
  [EVENT.LAND, "land"],
  [EVENT.SPLASH, "splash"],
  [EVENT.FISH_COLLECT, "fishCollect"],
  [EVENT.ENEMY_HIT, "enemyHit"],
  [EVENT.IGLOO_PIECE, "iglooPiece"],
  [EVENT.IGLOO_LOSE, "iglooLose"],
  [EVENT.IGLOO_COMPLETE, "iglooComplete"],
  [EVENT.IGLOO_ENTER, "iglooEnter"],
  [EVENT.TEMP_LOW, "tempLow"],
  [EVENT.TEMP_ZERO, "tempZero"],
  [EVENT.BEAR_NEAR, "bearNear"],
  [EVENT.CLAM_SNAP, "clamSnap"],
];

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

function buildingTick(game) {
  const before = nextFrame(game);

  game.gameState = before;
  game.updateOpponent();

  const state = stepTick(before, game.localInputs, game.remoteInputs);
  // A jump is one press: it is spent on the frame it starts.
  game.localInputs.up = false;
  game.localInputs.down = false;
  game.remoteInputs.up = false;
  game.remoteInputs.down = false;

  if (state.phase === PHASE.ROUND_END && before.phase === PHASE.BUILDING) {
    game.roundEndTimer = ROUND_END_DELAY;
    game.audio.playRoundEnd();
  }
  if (state.phase === PHASE.FINISHED && before.phase !== PHASE.FINISHED) finishMatch(game, state);

  playFlags(game, EVENT_SOUNDS, state.events);
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
  if (game.outcome(winner) === "win") game.audio.playVictory();
  else game.audio.playGameOver();

  const end = { score1: state.p1.roundWins, score2: state.p2.roundWins, winner };
  game.finish({ end, result: matchResult(end.score1, end.score2, winner), broadcast: false });
}

export default defineGame({
  inputs: {
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
    up: ARROW_KEYS.up,
    down: ARROW_KEYS.down,
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
  audio: { sounds: SOUNDS, masterVolume: MASTER_VOLUME, extend },
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
    // ex_dna:disable-for-lines:7 this game's own defineGame definition
    if (game.mode === "solo" || game.isHost) {
      game.gameState = createInitialState(game.gameMode, drawSeed(game));
    }
  },
  onStop: (game) => {
    game.forgetMatch();
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
      BUILDING: { tick: buildingTick },
      ROUND_END: { tick: roundEndTick },
      FINISHED: {
        final: true,
        enter: (game) => finishMatch(game, game.gameState),
        // ex_dna:disable-for-lines:7 this game's own defineGame definition
      },
    },
  },

  ...packedSnapshot(packState, unpackState),
  cues: [{ flags: (s) => s.events, sounds: EVENT_SOUNDS }],
  onEnd: raceEnd(PHASE.FINISHED, (game) => game.audio.stopAmbientWind()),
  render: (game) =>
    render(game.ctx, game.gameState, game.colors, game.frameCount, game.snowParticles),
  disconnectResult: drawOnDisconnect((s) => [
    s.p1?.roundWins ?? s.p1RoundWins ?? 0,
    s.p2?.roundWins ?? s.p2RoundWins ?? 0,
  ]),
});
