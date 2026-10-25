/**
 * Hex Warlords: two kings behind castle walls, a fireball between them, and a
 * shield each to deflect it, or catch it and launch it back.
 *
 * Host-authoritative. The match lifecycle comes from `defineGame`; this file
 * says only what is Warlords'.
 *
 * @module games/warlords
 */

import { defineGame } from "../core/define_game.js";
import { createWarlordAI, normalizeWarlordAIDifficulty } from "./ai.js";
import {
  CANVAS_H,
  CANVAS_W,
  P1_KING_X,
  P1_KING_Y,
  P2_KING_X,
  P2_KING_Y,
  checkBrickCollision,
  checkCatch,
  checkGameOver,
  checkKingHit,
  checkShieldCollision,
  checkWallBounce,
  createBrickParticles,
  createInitialState,
  createKingParticles,
  rebuildCastles,
  releaseBall,
  serveFireball,
  updateCaughtFireball,
  updateFireball,
  updateParticles,
  updateShield,
} from "./physics.js";
import { GAME_END, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const SERVE_DELAY_TICKS = 48; // 0.8 s
const KING_HIT_PAUSE_TICKS = 120; // 2 s
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

/** Let go of a caught fireball, with the launch sound. */
function release(game, player) {
  game.gameState = releaseBall(game.gameState, player);
  if (game.gameState.released) {
    game.audio.playLaunch();
    game.gameState.released = false;
  }
}

function step(game) {
  game.updateOpponent();
  let s = game.gameState;

  s = updateShield(s, 1, game.localInputs);
  s = updateShield(s, 2, game.remoteInputs);
  s = updateCaughtFireball(s);
  s = updateFireball(s);
  s = checkWallBounce(s);
  if (s.wallBounced) {
    game.audio.playWallBounce();
    s.wallBounced = false;
  }

  s = checkShieldCollision(s);
  if (s.shieldHit) {
    s = checkCatch(s, game.localInputs, game.remoteInputs);
    if (s.caught) {
      game.audio.playCatch();
      s.caught = false;
    } else {
      game.audio.playShieldDeflect();
    }
    s.shieldHit = false;
    s.shieldHitPlayer = 0;
  }

  s = checkBrickCollision(s);
  if (s.brickHit) {
    game.audio.playBrickHit();
    s.particles = [
      ...(s.particles || []),
      ...createBrickParticles(s.hitBrickX, s.hitBrickY, s.hitBrickColor, game.fxRandom),
    ];
    s.brickHit = false;
  }

  s = checkKingHit(s);
  game.gameState = s;
  if (s.kingHit) {
    game.audio.playKingHit();
    const kingX = s.kingHitPlayer === 1 ? P1_KING_X : P2_KING_X;
    const kingY = s.kingHitPlayer === 1 ? P1_KING_Y : P2_KING_Y;
    s.particles = [...(s.particles || []), ...createKingParticles(kingX, kingY, game.fxRandom)];
    s.kingHit = false;
    s.phase = PHASE.KING_HIT;
    return;
  }

  if (s.particles && s.particles.length > 0) s.particles = updateParticles(s.particles);
  game.invalidate();
  game.frameCount++;
  game.broadcast();
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
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
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
    observe: (game) => ({ state: game.gameState, player: 2, difficulty: game.difficulty }),
  },
  audio: { sounds: SOUNDS },
  theme: getColors,
  init: () => createInitialState(),
  onStart: (game) => {
    game.localInputs = { up: false, down: false, space: false };
  },
  onStop: (game) => {
    game.localInputs = { up: false, down: false, space: false };
    game.remoteInputs = { up: false, down: false, space: false };
    game.peerReady = false;
  },
  idle: (game) => {
    const s = game.gameState;
    if (s.phase !== PHASE.KING_HIT || !s.particles || !s.particles.length) return;
    s.particles = updateParticles(s.particles);
    game.invalidate();
  },

  // A caught fireball goes when its shield's key is released (or the window
  // loses focus, since that release never arrives).
  onKeyUp: (game, event) => {
    if (game._keyInput(event) === "space" && game.isHost && game.gameState.caughtBy === 1) {
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
      COUNTDOWN: {
        enter: (game) => {
          game.gameState.countdown = COUNTDOWN_FROM;
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.audio.playCountdown();
        },
        every: { ticks: COUNTDOWN_EVERY_TICKS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          if (remaining === 0) return;
          game.gameState.countdown = remaining;
          game.broadcast();
          game.invalidate();
          game.audio.playCountdown();
        },
        next: "SERVING",
      },
      // The fireball waits at the centre while the countdown still shows.
      SERVING: {
        as: "COUNTDOWN",
        enter: (game) => {
          Object.assign(game.gameState, {
            fireballX: CANVAS_W / 2,
            fireballY: CANVAS_H / 2,
            fireballVX: 0,
            fireballVY: 0,
            caughtBy: 0,
          });
          game.setKeyboardCaptured(true);
          game.broadcast();
          game.invalidate();
        },
        after: { ticks: SERVE_DELAY_TICKS },
        then: (game) => {
          game.gameState = serveFireball(game.gameState, game.random);
          game.broadcast();
        },
        next: "PLAYING",
      },
      PLAYING: {
        enter: (game) => {
          game.frameCount = 0;
        },
        tick: step,
      },
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
  onSnapshot: (game, decoded, previous) => {
    if (previous.phase !== decoded.phase) {
      if (decoded.phase === PHASE.COUNTDOWN) game.audio.playCountdown();
      if (decoded.phase === PHASE.KING_HIT) game.audio.playKingHit();
    }
    game.invalidate();
  },
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    Object.assign(game.gameState, {
      phase: PHASE.FINISHED,
      p1Lives: result.p1Lives,
      p2Lives: result.p2Lives,
      winner: result.winner,
    });
    if (result.winner === 2) game.audio.playWin();
    else game.audio.playLose();
    game.invalidate();
  },
  render: (game) => {
    if (game.colors) render(game.ctx, game.gameState, game.colors, performance.now());
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.p1Lives, p2: game.gameState.p2Lives },
    winner: 0,
  }),
});
