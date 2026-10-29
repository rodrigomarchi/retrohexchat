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

import { ARROWS_WASD_SPACE, ARROW_KEYS, defineGame } from "../core/define_game.js";
import { drawOnDisconnect, finishScored, guestEnd, playOutcome } from "../core/result.js";
import { countdownState } from "../core/rounds.js";
import { createStarDuelAI, normalizeStarDuelAIDifficulty } from "./ai.js";
import {
  STAR_X,
  STAR_Y,
  WIN_SCORE,
  createExplosionParticles,
  createInitialState,
  generateAsteroids,
  spawnShips,
  stepTick,
  updateParticles,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT, encodeShipFlags } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS, extend } from "./sounds.js";

const SPAWN_DELAY_TICKS = 90; // 1.5 s
const ROUND_OVER_DELAY_TICKS = 120; // 2 s

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

function silenceThrust(game) {
  game.audio.stopThrust();
  game.thrustAudioPlaying = false;
}

function battle(game) {
  const state = game.gameState;
  game.updateOpponent();
  const step = stepTick(
    state,
    { 1: game.localInputs, 2: game.remoteInputs },
    {
      fire1: game.p1FirePrev,
      fire2: game.p2FirePrev,
      warp1: game.p1WarpPrev,
      warp2: game.p2WarpPrev,
    },
    game.random,
  );
  game.p1FirePrev = step.pressed.fire1;
  game.p2FirePrev = step.pressed.fire2;
  game.p1WarpPrev = step.pressed.warp1;
  game.p2WarpPrev = step.pressed.warp2;
  const { ship1, ship2, score1, score2 } = step.state;
  const { fired, warped, hits, died, scored } = step.events;

  for (let i = 0; i < fired.length; i++) game.audio.playFire();
  for (let i = 0; i < warped.length; i++) game.audio.playWarp();
  if (state.mode === GAME_MODE.GRAVITY_WELL) {
    game.audio.playStarProximity(Math.min(starDistance(ship1), starDistance(ship2)));
  }
  for (let i = 0; i < hits; i++) game.audio.playHit();

  let { particles } = state;
  for (const player of died) {
    const ship = player === 1 ? ship1 : ship2;
    particles = [...particles, ...createExplosionParticles(ship.x, ship.y, 15, game.fxRandom)];
  }
  if (died.length > 0) game.audio.playDeath();
  if (particles.length > 0) particles = updateParticles(particles);

  if (ship1.thrustActive && ship1.alive && !game.thrustAudioPlaying) {
    game.audio.playThrust();
    game.thrustAudioPlaying = true;
  } else if ((!ship1.thrustActive || !ship1.alive) && game.thrustAudioPlaying) {
    silenceThrust(game);
  }

  game.gameState = { ...step.state, particles };
  game.invalidate();
  game.frameCount++;
  game.broadcast();

  if (scored) {
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
    rotateLeft: ARROW_KEYS.left,
    rotateRight: ARROW_KEYS.right,
    thrust: ARROW_KEYS.up,
    fire: [" "],
    warp: ARROW_KEYS.down,
  },
  captureKeys: ARROWS_WASD_SPACE,
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
      COUNTDOWN: countdownState({ next: "SPAWNING" }),
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
          playOutcome(game, winner);
          silenceThrust(game);
          if (s.mode === GAME_MODE.GRAVITY_WELL) game.audio.stopStarProximity();
          finishScored(game, s.score1, s.score2, winner);
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
  onEnd: guestEnd({
    phase: PHASE.FINISHED,
    fields: ["winner", "score1", "score2"],
    sound: (game, result) => {
      playOutcome(game, result.winner);
      game.audio.stopThrust();
      game.audio.stopStarProximity();
      game.peerThrustAudioPlaying = false;
    },
  }),
  render: (game) => render(game.ctx, game.gameState, game.colors, performance.now()),
  disconnectResult: drawOnDisconnect((s) => [s.score1, s.score2]),
});
