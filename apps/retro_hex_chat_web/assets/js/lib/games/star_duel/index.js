/**
 * Star Duel: two ships in open space (or around a star, or through debris),
 * the first to the winning score of kills takes the match.
 *
 * Host-authoritative. Once the first round is under way the simulation never
 * pauses: wrecks drift and missiles fly on through the round over and the
 * respawn. The match lifecycle comes from `defineGame`; this file says only
 * what is Star Duel's.
 *
 * @module games/star_duel
 */

import { defineGame } from "../core/define_game.js";
import { countdownState } from "../core/rounds.js";
import { createStarDuelAI, normalizeStarDuelAIDifficulty } from "./ai.js";
import {
  STAR_X,
  STAR_Y,
  WIN_SCORE,
  applyDrag,
  applyGravity,
  applyGravityToMissile,
  applyThrust,
  attemptWarp,
  capSpeed,
  checkAsteroidMissileCollision,
  checkAsteroidShipCollision,
  checkMissileShipCollision,
  checkShipShipCollision,
  checkStarCollision,
  createExplosionParticles,
  createInitialState,
  fireMissile,
  generateAsteroids,
  spawnShips,
  tickCooldowns,
  updateMissiles,
  updateParticles,
  updateShipPosition,
  updateShipRotation,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT, encodeShipFlags } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS, extend } from "./sounds.js";

const SPAWN_DELAY_TICKS = 90; // 1.5 s
const ROUND_OVER_DELAY_TICKS = 120; // 2 s
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

const MODE_MAP = {
  star_duel: GAME_MODE.OPEN_SPACE,
  gravity_well: GAME_MODE.GRAVITY_WELL,
  debris_field: GAME_MODE.DEBRIS_FIELD,
};

const starDistance = (ship) => {
  const dx = ship.x - STAR_X;
  const dy = ship.y - STAR_Y;
  return Math.sqrt(dx * dx + dy * dy);
};

const wreck = (ship) => ({ ...ship, alive: false, exploding: true });

/** Rotate, thrust and coast a living ship by its pilot's inputs. */
function fly(ship, inputs) {
  if (!ship.alive) return ship;
  let s = updateShipRotation(ship, inputs.rotateLeft, inputs.rotateRight);
  s = { ...s, thrustActive: inputs.thrust };
  return updateShipPosition(capSpeed(applyDrag(applyThrust(s))));
}

/** Missiles and warps go on the press, not while the key is held. */
function pressed(game, key, now) {
  const fresh = now && !game[key];
  game[key] = now;
  return fresh;
}

/** The fanfare for whoever won at this screen, the falling one otherwise. */
function playEnd(game, winner) {
  if (game.outcome(winner) === "win") game.audio.playWin();
  else game.audio.playLose();
}

function silenceThrust(game) {
  game.audio.stopThrust();
  game.thrustAudioPlaying = false;
}

function battle(game) {
  const state = game.gameState;
  game.updateOpponent();
  const local = game.localInputs;
  const remote = game.remoteInputs;

  let ship1 = fly(state.ship1, local);
  let ship2 = fly(state.ship2, remote);
  let { missiles } = state;

  if (pressed(game, "p1FirePrev", local.fire) && ship1.alive) {
    const shot = fireMissile(ship1, 1, missiles);
    if (shot) {
      ship1 = shot.ship;
      missiles = [...missiles, shot.missile];
      game.audio.playFire();
    }
  }
  if (pressed(game, "p2FirePrev", remote.fire) && ship2.alive) {
    const shot = fireMissile(ship2, 2, missiles);
    if (shot) {
      ship2 = shot.ship;
      missiles = [...missiles, shot.missile];
      game.audio.playFire();
    }
  }
  if (pressed(game, "p1WarpPrev", local.warp)) {
    const warp = attemptWarp(ship1, game.random);
    if (warp) {
      ship1 = warp.ship;
      game.audio.playWarp();
    }
  }
  if (pressed(game, "p2WarpPrev", remote.warp)) {
    const warp = attemptWarp(ship2, game.random);
    if (warp) {
      ship2 = warp.ship;
      game.audio.playWarp();
    }
  }

  missiles = updateMissiles(missiles);

  if (state.mode === GAME_MODE.GRAVITY_WELL) {
    const pull = (ship) => {
      if (!ship.alive) return ship;
      const s = capSpeed(applyGravity(ship, STAR_X, STAR_Y));
      return checkStarCollision(s) ? wreck(s) : s;
    };
    ship1 = pull(ship1);
    ship2 = pull(ship2);
    missiles = missiles.map((m) => applyGravityToMissile(m, STAR_X, STAR_Y));
    game.audio.playStarProximity(Math.min(starDistance(ship1), starDistance(ship2)));
  }

  if (state.mode === GAME_MODE.DEBRIS_FIELD) {
    if (ship1.alive && checkAsteroidShipCollision(ship1, state.asteroids)) ship1 = wreck(ship1);
    if (ship2.alive && checkAsteroidShipCollision(ship2, state.asteroids)) ship2 = wreck(ship2);
    missiles = checkAsteroidMissileCollision(missiles, state.asteroids);
  }

  const check1 = checkMissileShipCollision(missiles, ship1, 1);
  missiles = check1.missiles;
  if (check1.hit) {
    ship1 = wreck(ship1);
    game.audio.playHit();
  }
  const check2 = checkMissileShipCollision(missiles, ship2, 2);
  missiles = check2.missiles;
  if (check2.hit) {
    ship2 = wreck(ship2);
    game.audio.playHit();
  }
  if (checkShipShipCollision(ship1, ship2)) {
    ship1 = wreck(ship1);
    ship2 = wreck(ship2);
    game.audio.playHit();
  }

  if (ship1.alive) ship1 = tickCooldowns(ship1);
  if (ship2.alive) ship2 = tickCooldowns(ship2);

  // A kill scores for the other pilot; both dying at once is a drawn round.
  let { particles, score1, score2 } = state;
  let lastScorer = state.lastScorer || 0;
  let scoreChanged = false;
  const p1Died = ship1.exploding && ship1.alive === false && !state.ship1.exploding;
  const p2Died = ship2.exploding && ship2.alive === false && !state.ship2.exploding;
  if (p1Died) {
    particles = [...particles, ...createExplosionParticles(ship1.x, ship1.y, 15, game.fxRandom)];
  }
  if (p2Died) {
    particles = [...particles, ...createExplosionParticles(ship2.x, ship2.y, 15, game.fxRandom)];
  }
  if (p1Died || p2Died) {
    game.audio.playDeath();
    scoreChanged = true;
    if (p1Died && p2Died) lastScorer = 0;
    else if (p1Died) {
      score2++;
      lastScorer = 2;
    } else {
      score1++;
      lastScorer = 1;
    }
  }
  if (particles.length > 0) particles = updateParticles(particles);

  if (ship1.thrustActive && ship1.alive && !game.thrustAudioPlaying) {
    game.audio.playThrust();
    game.thrustAudioPlaying = true;
  } else if ((!ship1.thrustActive || !ship1.alive) && game.thrustAudioPlaying) {
    silenceThrust(game);
  }

  game.gameState = { ...state, ship1, ship2, missiles, particles, score1, score2, lastScorer };
  game.invalidate();
  game.frameCount++;
  game.broadcast();

  if (scoreChanged) {
    game.gameState.phase =
      score1 >= WIN_SCORE || score2 >= WIN_SCORE ? PHASE.FINISHED : PHASE.ROUND_OVER;
  }
}

function spawning(game) {
  game.broadcast();
  game.invalidate();
  game.audio.playSpawn();
}

/** The ship's flags travel packed in one byte, its timers beside it. */
function toWire(game) {
  const s = game.gameState;
  const pack = (ship) => ({
    ...ship,
    flags: encodeShipFlags({
      alive: ship.alive,
      thrustActive: ship.thrustActive,
      exploding: ship.exploding,
      warping: ship.warping,
      invulnerable: ship.invulnerable,
    }),
  });
  return {
    ...s,
    ship1: pack(s.ship1),
    ship2: pack(s.ship2),
    invuln1: s.ship1.invulnTimer || 0,
    invuln2: s.ship2.invulnTimer || 0,
    warpCooldown1: s.ship1.warpCooldown || 0,
    warpCooldown2: s.ship2.warpCooldown || 0,
  };
}

function unpackShip(decoded, invulnTimer, warpCooldown) {
  return {
    x: decoded.x,
    y: decoded.y,
    vx: decoded.vx,
    vy: decoded.vy,
    rotation: decoded.rotation,
    alive: decoded.flags.alive,
    thrustActive: decoded.flags.thrustActive,
    exploding: decoded.flags.exploding,
    warping: decoded.flags.warping,
    invulnerable: decoded.flags.invulnerable,
    invulnTimer: invulnTimer || 0,
    fireCooldown: 0,
    warpCooldown: warpCooldown || 0,
  };
}

/** The guest rebuilds the ships, blows up the ones that just died, and follows the rival's thrust. */
function applySnapshot(game, decoded) {
  const prev = game.gameState;
  const ship1 = unpackShip(decoded.ship1, decoded.invuln1, decoded.warpCooldown1);
  const ship2 = unpackShip(decoded.ship2, decoded.invuln2, decoded.warpCooldown2);
  let particles = prev.particles || [];
  if (ship1.exploding && !prev.ship1.exploding) {
    particles = [...particles, ...createExplosionParticles(ship1.x, ship1.y, 15, game.fxRandom)];
  }
  if (ship2.exploding && !prev.ship2.exploding) {
    particles = [...particles, ...createExplosionParticles(ship2.x, ship2.y, 15, game.fxRandom)];
  }

  game.gameState = {
    ...prev,
    ship1,
    ship2,
    missiles: decoded.missiles,
    particles,
    score1: decoded.score1,
    score2: decoded.score2,
    phase: decoded.phase,
    countdown: decoded.countdown,
    mode: decoded.mode,
    asteroidSeed: decoded.asteroidSeed,
  };
  const s = game.gameState;
  const p1Scored = decoded.score1 > prev.score1;
  const p2Scored = decoded.score2 > prev.score2;
  if (p1Scored && !p2Scored) s.lastScorer = 1;
  else if (p2Scored && !p1Scored) s.lastScorer = 2;
  else if (p1Scored && p2Scored) s.lastScorer = 0;

  // The guest drew a field of its own at the start; the host's seed (0 among
  // them) replaces it.
  if (decoded.mode === GAME_MODE.DEBRIS_FIELD && decoded.asteroidSeed !== prev.asteroidSeed) {
    s.asteroids = generateAsteroids(decoded.asteroidSeed);
  }

  if (ship2.thrustActive && ship2.alive && !game.peerThrustAudioPlaying) {
    game.audio.playThrust();
    game.peerThrustAudioPlaying = true;
  } else if ((!ship2.thrustActive || !ship2.alive) && game.peerThrustAudioPlaying) {
    game.audio.stopThrust();
    game.peerThrustAudioPlaying = false;
  }
}

/** A round's end, or the match's, silences the rival's thrust. */
function silencePeerThrust(game) {
  game.audio.stopThrust();
  game.peerThrustAudioPlaying = false;
}

export default defineGame({
  inputs: {
    rotateLeft: ["ArrowLeft", "a", "A"],
    rotateRight: ["ArrowRight", "d", "D"],
    thrust: ["ArrowUp", "w", "W"],
    fire: [" "],
    warp: ["ArrowDown", "s", "S"],
  },
  captureKeys: [
    "ArrowUp",
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    " ",
    "Spacebar",
    "w",
    "W",
    "a",
    "A",
    "s",
    "S",
    "d",
    "D",
  ],
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createStarDuelAI, difficulty: normalizeStarDuelAIDifficulty },
  audio: { sounds: SOUNDS, extend },
  theme: getColors,
  // The game id picks the arena: open space, a star's gravity well or a debris field.
  init: (game) => {
    game.gameMode = MODE_MAP[game.gameId] ?? GAME_MODE.OPEN_SPACE;
    return { ...createInitialState(game.gameMode, null, game.random), lastScorer: 0 };
  },
  setup: (game) => {
    game.p1FirePrev = false;
    game.p2FirePrev = false;
    game.p1WarpPrev = false;
    game.p2WarpPrev = false;
    game.thrustAudioPlaying = false;
    game.peerThrustAudioPlaying = false;
  },
  onStop: (game) => {
    game.audio.stopThrust();
    game.audio.stopStarProximity();
  },
  onAbandon: (game) => {
    game.audio.stopThrust();
    game.audio.stopStarProximity();
  },
  onBlur: silenceThrust,

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: countdownState({
        from: COUNTDOWN_FROM,
        every: COUNTDOWN_EVERY_TICKS,
        next: "SPAWNING",
      }),
      SPAWNING: {
        enter: spawning,
        after: { ticks: SPAWN_DELAY_TICKS },
        next: "PLAYING",
      },
      PLAYING: {
        enter: (game) => {
          game.gameState = spawnShips(game.gameState);
          game.frameCount = 0;
          game.p1FirePrev = false;
          game.p2FirePrev = false;
          game.p1WarpPrev = false;
          game.p2WarpPrev = false;
          game.broadcast();
          game.invalidate();
        },
        tick: battle,
      },
      ROUND_OVER: {
        enter: (game) => {
          game.broadcast();
          game.invalidate();
          silenceThrust(game);
          if (game.gameState.mode === GAME_MODE.GRAVITY_WELL) game.audio.stopStarProximity();
        },
        tick: battle,
        after: { ticks: ROUND_OVER_DELAY_TICKS },
        next: "RESPAWNING",
      },
      // Later rounds respawn while the last one's wreckage still drifts.
      RESPAWNING: {
        as: "SPAWNING",
        enter: spawning,
        tick: battle,
        after: { ticks: SPAWN_DELAY_TICKS },
        next: "PLAYING",
      },
      FINISHED: {
        final: true,
        enter: (game) => {
          const s = game.gameState;
          const winner = s.score1 >= WIN_SCORE ? 1 : 2;
          s.winner = winner;
          playEnd(game, winner);
          silenceThrust(game);
          if (s.mode === GAME_MODE.GRAVITY_WELL) game.audio.stopStarProximity();
          game.finish({
            end: { score1: s.score1, score2: s.score2, winner },
            result: { score: { p1: s.score1, p2: s.score2 }, winner },
          });
        },
      },
    },
  },

  toWire,
  applySnapshot,
  // The guest hears the countdown, the spawn, and every death in the score.
  cues: [
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    { phase: PHASE.SPAWNING, play: "spawn" },
    { phase: PHASE.ROUND_OVER, play: silencePeerThrust },
    { phase: PHASE.FINISHED, play: silencePeerThrust },
    { change: (s) => `${s.score1}:${s.score2}`, play: "death" },
  ],
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    Object.assign(game.gameState, {
      phase: PHASE.FINISHED,
      winner: result.winner,
      score1: result.score1,
      score2: result.score2,
    });
    playEnd(game, result.winner);
    game.audio.stopThrust();
    game.audio.stopStarProximity();
    game.peerThrustAudioPlaying = false;
    game.invalidate();
  },
  render: (game) => {
    if (game.colors) render(game.ctx, game.gameState, game.colors, performance.now());
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.score1, p2: game.gameState.score2 },
    winner: 0,
  }),
});
