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

import { ARROWS_WASD_SPACE, defineGame } from "../core/define_game.js";
import { countdownState } from "../core/rounds.js";
import { drawOnDisconnect, guestEnd, matchResult, playOutcome } from "../core/result.js";
import { normalizeRaidAIDifficulty } from "./difficulty.js";
import {
  SCORE_FUEL_OUT,
  accelerateJet,
  checkBridgeCollision,
  checkBridgeHits,
  checkEnemyCollisions,
  checkFuelCapture,
  checkGameOver,
  checkMineCollisions,
  checkMissileHits,
  checkRiverCollision,
  clearEvents,
  createInitialState,
  deployMine,
  drainFuel,
  fireMissile,
  getWinner,
  handleDeath,
  moveJet,
  processRespawns,
  spawnEntities,
  tickTimers,
  updateBridge,
  updateEnemies,
  updateFuels,
  updateMines,
  updateMissiles,
  updateScroll,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

const MODE_MAP = {
  hex_raid: GAME_MODE.RIVER_DUEL,
  hex_raid_pacifist: GAME_MODE.PACIFIST,
  hex_raid_blitz: GAME_MODE.BLITZ,
};

const RELEASED = {
  left: false,
  right: false,
  accel: false,
  decel: false,
  fire: false,
  mine: false,
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

/** Missiles and mines go on the press, not while the key is held. */
function pressed(game, key, now) {
  const fresh = now && !game[key];
  game[key] = now;
  return fresh;
}

function releaseTriggers(game) {
  game.localFirePressed = false;
  game.remoteFirePressed = false;
  game.localMinePressed = false;
  game.remoteMinePressed = false;
}

function steer(s, player, inputs) {
  let next = s;
  if (inputs.left) next = moveJet(next, player, -1);
  if (inputs.right) next = moveJet(next, player, 1);
  if (inputs.accel) next = accelerateJet(next, player, 1);
  if (inputs.decel) next = accelerateJet(next, player, -1);
  return next;
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

function fly(game) {
  let s = clearEvents(game.gameState);
  game.updateOpponent();
  const local = game.localInputs;
  const remote = game.remoteInputs;
  s = steer(s, 1, local);
  s = steer(s, 2, remote);

  if (pressed(game, "localFirePressed", local.fire)) {
    const prev = s.m1Active;
    s = fireMissile(s, 1);
    if (s.m1Active && !prev) game.audio.playFire();
  }
  if (pressed(game, "remoteFirePressed", remote.fire)) {
    const prev = s.m2Active;
    s = fireMissile(s, 2);
    if (s.m2Active && !prev) game.audio.playFire();
  }
  if (pressed(game, "localMinePressed", local.mine)) {
    const prevCount = s.mineCount;
    s = deployMine(s, 1);
    if (s.mineCount > prevCount) game.audio.playMineDeploy();
  }
  if (pressed(game, "remoteMinePressed", remote.mine)) {
    const prevCount = s.mineCount;
    s = deployMine(s, 2);
    if (s.mineCount > prevCount) game.audio.playMineDeploy();
  }

  const scrolled = updateScroll(s);
  s = scrolled.state;
  const { scrollDelta } = scrolled;
  s = spawnEntities(s);
  s = updateMissiles(s);
  s = updateEnemies(s, scrollDelta);
  s = updateFuels(s, scrollDelta);
  s = updateBridge(s, scrollDelta);
  s = updateMines(s, scrollDelta);
  s = drainFuel(s, game.frameCount);
  s = checkMissileHits(s);
  s = checkBridgeHits(s);
  s = checkEnemyCollisions(s);
  s = checkFuelCapture(s);
  s = checkMineCollisions(s);
  s = checkBridgeCollision(s);
  for (const player of [1, 2]) {
    if (checkRiverCollision(s, player)) s = { ...s, events: { ...s.events, death: player } };
  }

  playEvents(game.audio, s.events);
  // A jet that runs dry hands its rival the fuel-out bonus.
  if (s.events.death) {
    game.audio.playDeath();
    s = handleDeath(s, s.events.death);
    if (s.events.fuelEmpty) {
      const bonusKey = s.events.fuelEmpty === 1 ? "score2" : "score1";
      s = { ...s, [bonusKey]: s[bonusKey] + SCORE_FUEL_OUT };
    }
  }

  const prevJ1Alive = s.jet1Alive;
  const prevJ2Alive = s.jet2Alive;
  s = processRespawns(s);
  if (s.jet1Alive && !prevJ1Alive) game.audio.playRespawn();
  if (s.jet2Alive && !prevJ2Alive) game.audio.playRespawn();
  if (
    game.frameCount % 30 === 0 &&
    ((s.jet1Alive && s.jet1Fuel < 50) || (s.jet2Alive && s.jet2Fuel < 50))
  ) {
    game.audio.playFuelLow();
  }

  // The match's end reports itself on entering FINISHED.
  if (checkGameOver(s).ended) {
    game.gameState = { ...s, phase: PHASE.FINISHED };
    return;
  }

  game.gameState = tickTimers(s);
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
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    accel: ["ArrowUp", "w", "W"],
    decel: ["ArrowDown", "s", "S"],
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
  init: (game) => {
    game.gameMode = MODE_MAP[game.gameId] || GAME_MODE.RIVER_DUEL;
    game.seed = game.isHost ? ((game.random() * 0xffffffff) | 0) >>> 0 : 0;
    return createInitialState(game.gameMode, game.seed);
  },
  setup: (game) => {
    game.particles = [];
    releaseTriggers(game);
  },
  onStart: (game) => {
    if (game.isHost) game.gameState = createInitialState(game.gameMode, game.seed);
  },
  onStop: (game) => {
    releaseTriggers(game);
    game.localInputs = { ...RELEASED };
    game.remoteInputs = { ...RELEASED };
    game.peerReady = false;
    game.frameCount = 0;
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
      COUNTDOWN: countdownState({
        from: COUNTDOWN_FROM,
        every: COUNTDOWN_EVERY_TICKS,
        next: "FLYING",
      }),
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
          game.finish({
            end: { score1, score2, winner },
            result: matchResult(score1, score2, winner),
          });
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
