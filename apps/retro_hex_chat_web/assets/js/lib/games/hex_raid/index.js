/**
 * Hex Raid: two jets up a scrolling river, shooting, mining and refuelling,
 * until one runs out of lives.
 *
 * Host-authoritative; the host seeds the river and the guest builds the same
 * one from the seed in its first snapshot. The AI is loaded by the page, not
 * bundled here. The match lifecycle comes from `defineGame`; this file says
 * only what is Raid's.
 *
 * @module games/hex_raid
 */

import {
  ARROWS_WASD_SPACE,
  ARROW_KEYS,
  defineGame,
  freshOnHost,
  seededInit,
} from "../core/define_game.js";
import { countdownState } from "../core/rounds.js";
import { drawOnDisconnect, finishScored, guestEnd, playOutcome } from "../core/result.js";
import { normalizeRaidAIDifficulty } from "./difficulty.js";
// ex_dna:disable-for-lines:7 this game's own imports
import { createInitialState, getWinner, stepTick } from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const MODE_MAP = {
  hex_raid: GAME_MODE.RIVER_DUEL,
  hex_raid_pacifist: GAME_MODE.PACIFIST,
  hex_raid_blitz: GAME_MODE.BLITZ,
};

/** What the guest copies from each snapshot as it comes. */
const SNAPSHOT_FIELDS = [
  "jet1X",
  "jet1Y",
  "jet1Speed",
  "jet1Fuel",
  "jet1Lives",
  "jet1Alive",
  "jet1Invuln",
  "jet1Respawning",
  "jet2X",
  "jet2Y",
  "jet2Speed",
  "jet2Fuel",
  "jet2Lives",
  "jet2Alive",
  "jet2Invuln",
  "jet2Respawning",
  "m1X",
  "m1Y",
  "m1Active",
  "m2X",
  "m2Y",
  "m2Active",
  "enemies",
  "enemyCount",
  "fuels",
  "fuelCount",
  "mines",
  "mineCount",
  "bridgeY",
  "bridgeHp",
  "bridgeActive",
  "score1",
  "score2",
  "phase",
  "countdown",
  "section",
  "scrollY",
  "mode",
  "seed",
];

function releaseTriggers(game) {
  game.localFirePressed = false;
  game.remoteFirePressed = false;
  game.localMinePressed = false;
  game.remoteMinePressed = false;
}

/** The sounds of a step's events, in the order they are heard. */
function playEvents(audio, events) {
  if (events.enemyKill) audio.playEnemyDestroyed();
  if (events.fuelCapture) audio.playFuelCapture();
  if (events.fuelDestroyed) audio.playFuelDestroyed();
  if (events.bridgeHit && !events.bridgeDestroyed) audio.playBridgeHit();
  if (events.bridgeDestroyed) audio.playBridgeDestroyed();
  if (events.mineHit) audio.playMineHit();
}

/** The triggers each side had down the step before, as `stepTick` reads them. */
function heldTriggers(game) {
  return {
    1: { fire: game.localFirePressed, mine: game.localMinePressed },
    2: { fire: game.remoteFirePressed, mine: game.remoteMinePressed },
  };
}

/** Plays `sound` once for each player whose bit is set. */
function playFor(bits, sound) {
  for (const player of [1, 2]) if (bits & player) sound();
}

function fly(game) {
  game.updateOpponent();
  const step = stepTick(
    game.gameState,
    { 1: game.localInputs, 2: game.remoteInputs },
    heldTriggers(game),
    game.frameCount,
  );
  game.localFirePressed = step.held[1].fire;
  game.remoteFirePressed = step.held[2].fire;
  game.localMinePressed = step.held[1].mine;
  game.remoteMinePressed = step.held[2].mine;

  const s = step.state;
  playFor(step.fired, () => game.audio.playFire());
  playFor(step.dropped, () => game.audio.playMineDeploy());
  playEvents(game.audio, s.events);
  if (s.events.death) game.audio.playDeath();
  playFor(step.respawned, () => game.audio.playRespawn());
  if (
    game.frameCount % 30 === 0 &&
    ((s.jet1Alive && s.jet1Fuel < 50) || (s.jet2Alive && s.jet2Fuel < 50))
  ) {
    game.audio.playFuelLow();
  }

  game.gameState = s;
  // The match's end reports itself on entering FINISHED.
  if (s.phase === PHASE.FINISHED) return;

  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

/** The guest builds the host's river from its seed, then copies the snapshot. */
function applySnapshot(game, decoded) {
  if (game.seed === 0 && decoded.seed !== 0) {
    game.seed = decoded.seed;
    if (game.gameState.phase === PHASE.WAITING) {
      game.gameState = createInitialState(decoded.mode, decoded.seed);
    }
  }
  game.gameMode = decoded.mode;
  for (const key of SNAPSHOT_FIELDS) game.gameState[key] = decoded[key];
}

export default defineGame({
  inputs: {
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
    accel: ARROW_KEYS.up,
    decel: ARROW_KEYS.down,
    fire: [" "],
    mine: ["Shift", "q", "Q"],
  },
  captureKeys: [...ARROWS_WASD_SPACE, "Shift", "q", "Q"],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    difficulty: normalizeRaidAIDifficulty,
  },
  audio: { sounds: SOUNDS },
  theme: getColors,
  // The game id picks the mode; only the host seeds the river.
  init: seededInit(MODE_MAP, GAME_MODE.RIVER_DUEL, createInitialState),
  setup: (game) => {
    game.particles = [];
    releaseTriggers(game);
  },
  onStart: freshOnHost(createInitialState),
  onStop: (game) => {
    releaseTriggers(game);
    game.forgetMatch();
  },
  // A fresh press of the guest's (or the AI's) trigger always counts.
  onRemoteInputChange: (game, previous, current) => {
    if (current.fire && !previous.fire) game.remoteFirePressed = false;
    if (current.mine && !previous.mine) game.remoteMinePressed = false;
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: countdownState({ next: "FLYING" }),
      FLYING: {
        enter: (game) => {
          game.broadcast();
          game.frameCount = 0;
          releaseTriggers(game);
        },
        tick: fly,
      },
      FINISHED: {
        final: true,
        enter: (game) => {
          const { score1, score2 } = game.gameState;
          const winner = getWinner(game.gameState);
          if (winner === 1) game.audio.playWin();
          else game.audio.playLose();
          game.invalidate();
          finishScored(game, score1, score2, winner);
        },
      },
    },
  },

  applySnapshot,
  cues: [{ phase: PHASE.COUNTDOWN, play: "countdown" }],
  onEnd: guestEnd({
    phase: PHASE.FINISHED,
    fields: ["score1", "score2"],
    sound: (game, result) => playOutcome(game, result.winner),
  }),
  render: (game) =>
    render(game.ctx, game.gameState, game.colors, performance.now(), game.particles),
  disconnectResult: drawOnDisconnect((s) => [s.score1, s.score2]),
});
