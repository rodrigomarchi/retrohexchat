/**
 * Hex Warlords: two kings behind castle walls, a fireball between them, and a
 * shield each to deflect it, or catch it and launch it back.
 *
 * Host-authoritative. The match lifecycle comes from `defineGame`; this file
 * says only what is Warlords'.
 *
 * @module games/warlords
 */

import { ARROW_KEYS, defineGame } from "../core/define_game.js";
import { drawOnDisconnect, guestEnd, playOutcome } from "../core/result.js";
import { createWarlordAI, normalizeWarlordAIDifficulty } from "./ai.js";
import {
  CANVAS_H,
  CANVAS_W,
  P1_KING_X,
  P1_KING_Y,
  P2_KING_X,
  P2_KING_Y,
  checkGameOver,
  createBrickParticles,
  createInitialState,
  createKingParticles,
  rebuildCastles,
  releaseBall,
  // ex_dna:disable-for-lines:17 this game's own imports
  serveFireball,
  stepTick,
  updateParticles,
} from "./physics.js";
import { GAME_END, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";
import {
  countdownToServe,
  endTick,
  playTick,
  playingState,
  releaseOnStop,
  servingState,
} from "../core/paddle_flow.js";

const KING_HIT_PAUSE_TICKS = 120; // 2 s

/** Let go of a caught fireball, with the launch sound. */
function release(game, player) {
  game.gameState = releaseBall(game.gameState, player);
  if (game.gameState.released) {
    game.audio.playLaunch();
    game.gameState.released = false;
  }
}

function step(game) {
  const { state: s, events } = playTick(game, stepTick);
  game.gameState = s;
  if (events.caught) game.audio.playCatch();
  else if (events.shieldHit) game.audio.playShieldDeflect();
  if (events.brickHit) {
    game.audio.playBrickHit();
    s.particles = [
      ...(s.particles || []),
      ...createBrickParticles(s.hitBrickX, s.hitBrickY, s.hitBrickColor, game.fxRandom),
    ];
  }
  if (events.kingHit) {
    game.audio.playKingHit();
    const kingX = s.kingHitPlayer === 1 ? P1_KING_X : P2_KING_X;
    const kingY = s.kingHitPlayer === 1 ? P1_KING_Y : P2_KING_Y;
    s.particles = [...(s.particles || []), ...createKingParticles(kingX, kingY, game.fxRandom)];
    return;
  }

  endTick(game, s, updateParticles);
}

/** The guest rebuilds the kings and walls, and tells which king was hit. */
function applySnapshot(game, decoded) {
  const s = game.gameState;
  for (const key of [
    "fireballX",
    "fireballY",
    "fireballVX",
    "fireballVY",
    "shield1Y",
    "shield2Y",
    "p1Lives",
    "p2Lives",
    "phase",
    "countdown",
    "round",
    "caughtBy",
  ]) {
    s[key] = decoded[key];
  }
  s.p1KingAlive = decoded.p1Lives > 0;
  s.p2KingAlive = decoded.p2Lives > 0;

  if (decoded.phase === PHASE.KING_HIT) {
    if (game.prevP1Lives !== undefined && decoded.p1Lives < game.prevP1Lives) {
      s.kingHitPlayer = 1;
      s.p1KingAlive = false;
    } else if (game.prevP2Lives !== undefined && decoded.p2Lives < game.prevP2Lives) {
      s.kingHitPlayer = 2;
      s.p2KingAlive = false;
    }
  }
  game.prevP1Lives = decoded.p1Lives;
  game.prevP2Lives = decoded.p2Lives;

  for (const [bricks, alive] of [
    ["p1Bricks", "p1BricksAlive"],
    ["p2Bricks", "p2BricksAlive"],
  ]) {
    if (decoded[alive] && s[bricks]) {
      for (let i = 0; i < s[bricks].length; i++) s[bricks][i].alive = decoded[alive][i] || false;
    }
  }
}

export default defineGame({
  inputs: {
    up: ARROW_KEYS.up,
    down: ARROW_KEYS.down,
    space: [" "],
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
    "s",
    "S",
  ],
  interpolate: { keys: ["fireballX", "fireballY", "shield1Y", "shield2Y"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    create: createWarlordAI,
    difficulty: normalizeWarlordAIDifficulty,
  },
  audio: { sounds: SOUNDS },
  theme: getColors,
  init: () => createInitialState(),
  onStart: (game) => {
    game.localInputs = { up: false, down: false, space: false };
  },
  onStop: releaseOnStop({ up: false, down: false, space: false }),
  idle: (game) => {
    const s = game.gameState;
    if (s.phase !== PHASE.KING_HIT || !s.particles || !s.particles.length) return;
    s.particles = updateParticles(s.particles);
    game.invalidate();
  },

  // A caught fireball goes when its shield's key is released (or the window
  // loses focus, since that release never arrives).
  onKeyUp: (game, event) => {
    if (game.keyInput(event) === "space" && game.isHost && game.gameState.caughtBy === 1) {
      release(game, 1);
    }
  },
  onBlur: (game) => {
    if (game.isHost && game.gameState.caughtBy === 1) release(game, 1);
  },
  onRemoteInputChange: (game, previous, current) => {
    if (!previous.space || current.space) return;
    if (game.gameState.caughtBy !== 2) return;
    release(game, 2);
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: countdownToServe({ capture: true }),
      // The fireball waits at the centre while the countdown still shows.
      SERVING: servingState({
        as: "COUNTDOWN",
        prepare: (game) => {
          Object.assign(game.gameState, {
            fireballX: CANVAS_W / 2,
            fireballY: CANVAS_H / 2,
            fireballVX: 0,
            fireballVY: 0,
            caughtBy: 0,
          });
          game.setKeyboardCaptured(true);
        },
        serve: (game) => serveFireball(game.gameState, game.random),
      }),
      PLAYING: playingState(step),
      KING_HIT: {
        enter: (game) => {
          game.broadcast();
          game.invalidate();
        },
        after: { ticks: KING_HIT_PAUSE_TICKS },
        then: (game) => {
          game.gameState = checkGameOver(game.gameState);
          if (game.gameState.phase !== PHASE.FINISHED) {
            game.gameState = rebuildCastles(game.gameState);
          }
        },
        next: (game) => (game.gameState.phase === PHASE.FINISHED ? "FINISHED" : "COUNTDOWN"),
      },
      FINISHED: {
        final: true,
        enter: (game) => {
          const { p1Lives, p2Lives, winner } = game.gameState;
          if (winner === 1) game.audio.playWin();
          else game.audio.playLose();
          game.finish({
            end: { p1Lives, p2Lives, winner },
            result: { score: { p1: p1Lives, p2: p2Lives }, winner },
          });
        },
      },
    },
  },

  applySnapshot,
  cues: [
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    { phase: PHASE.KING_HIT, play: "kingHit" },
  ],
  onSnapshot: (game) => game.invalidate(),
  onEnd: guestEnd({
    phase: PHASE.FINISHED,
    fields: ["p1Lives", "p2Lives", "winner"],
    sound: (game, result) => playOutcome(game, result.winner),
  }),
  render: (game) => render(game.ctx, game.gameState, game.colors, performance.now()),
  disconnectResult: drawOnDisconnect((s) => [s.p1Lives, s.p2Lives]),
});
