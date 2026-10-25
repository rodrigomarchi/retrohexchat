/**
 * Hex Tennis: top-down tennis with serves, faults, a net and real scoring,
 * classic, quick or sudden death.
 *
 * Host-authoritative. Serve, rally, the pause after a point and the
 * changeover are one simulation that moves itself between them, so they
 * share one step. The match lifecycle comes from `defineGame`; this file
 * says only what is Tennis's.
 *
 * @module games/hex_tennis
 */

import { defineGame } from "../core/define_game.js";
import { createTennisAI, normalizeTennisAIDifficulty } from "./ai.js";
import {
  advanceScore,
  checkHitZone,
  checkNetCollision,
  checkOutOfBounds,
  checkServeLanding,
  clearEventFlags,
  createInitialState,
  performServe,
  resetForNextPoint,
  shouldChangeover,
  updateBall,
  updatePlayer,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const POINT_PAUSE_FRAMES = 120; // 2 s at 60 steps a second
const CHANGEOVER_PAUSE_FRAMES = 120;
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

const MODE_MAP = {
  hex_tennis: GAME_MODE.CLASSIC,
  hex_tennis_quick: GAME_MODE.QUICK,
  hex_tennis_sudden: GAME_MODE.SUDDEN_DEATH,
};

/** The server moves and serves on the press; the serve clock serves for them when it runs out. */
function serving(game, state) {
  let s = updatePlayer(state, 1, game.localInputs);
  s = updatePlayer(s, 2, game.remoteInputs);
  if (game.localInputs.serve && !game.localServePressed && s.server === 1) {
    s = performServe(s, game.random);
    game.audio.playServe();
  }
  game.localServePressed = game.localInputs.serve;
  if (game.remoteInputs.serve && !game.remoteServePressed && s.server === 2) {
    s = performServe(s, game.random);
    game.audio.playServe();
  }
  game.remoteServePressed = game.remoteInputs.serve;

  if (s.phase === PHASE.SERVING) {
    s = { ...s, serveTimer: s.serveTimer - 1 };
    if (s.serveTimer <= 0) {
      s = performServe(s, game.random);
      game.audio.playServe();
    }
  }
  game.gameState = s;
}

/**
 * The ball in play. Returns `false` when the step ends here: a fault that
 * sends the point back to the serve publishes itself, a point is announced
 * at once, and the match's end reports itself on entering GAME_OVER.
 */
function rally(game, state) {
  const prev = game.gameState;
  let s = clearEventFlags(state);
  s = updatePlayer(s, 1, game.localInputs);
  s = updatePlayer(s, 2, game.remoteInputs);
  s = updateBall(s);
  s = checkHitZone(s, 1);
  s = checkHitZone(s, 2);
  if (s.hitEvent && !prev.hitEvent) game.audio.playHit();

  s = checkServeLanding(s);
  if (s.faultEvent && !prev.faultEvent) {
    game.audio.playFault();
    if (s.phase === PHASE.SERVING) {
      game.gameState = s;
      game.invalidate();
      game.frameCount++;
      game.broadcast();
      return false;
    }
  }

  s = checkNetCollision(s);
  if (s.netFault && !prev.netFault) game.audio.playNetHit();
  s = checkOutOfBounds(s);
  if (s.outOfBounds && !prev.outOfBounds) {
    if (s.outType === 3) game.audio.playAce();
    else game.audio.playOut();
  }

  if (s.pointWinner > 0) {
    s = advanceScore(s);
    game.audio.playPoint();
    game.gameState = s;
    if (s.phase === PHASE.GAME_OVER) return false;
    s.phase = PHASE.POINT;
    game.pointPauseCounter = POINT_PAUSE_FRAMES;
    game.invalidate();
    game.broadcast();
    return false;
  }
  game.gameState = s;
  return true;
}

/** The pause after a point, then a changeover of ends when one is due. */
function pause(game, s) {
  game.pointPauseCounter--;
  if (game.pointPauseCounter > 0) return;
  if (s.phase === PHASE.POINT && shouldChangeover(s)) {
    s.phase = PHASE.CHANGEOVER;
    game.pointPauseCounter = CHANGEOVER_PAUSE_FRAMES;
    game.gameState = s;
  } else {
    game.gameState = resetForNextPoint(s);
  }
}

function play(game) {
  const s = game.gameState;
  game.updateOpponent();
  if (s.phase === PHASE.SERVING) serving(game, s);
  else if (s.phase === PHASE.RALLY) {
    if (!rally(game, s)) return;
  } else if (s.phase === PHASE.POINT || s.phase === PHASE.CHANGEOVER) pause(game, s);

  game.invalidate();
  game.frameCount++;
  game.broadcast();
}

/** The fanfare for whoever won at this screen, the falling one otherwise. */
function playEnd(game, winner) {
  if (game.outcome(winner) === "win") game.audio.playMatchWon();
  else game.audio.playMatchLost();
}

/** The ball travels flattened beside the rest of the state. */
function toWire(game) {
  const s = game.gameState;
  return {
    ...s,
    ballX: s.ball.x,
    ballY: s.ball.y,
    ballVX: s.ball.vx,
    ballVY: s.ball.vy,
    ballHeight: s.ball.height,
  };
}

/** The guest rebuilds the ball. */
function applySnapshot(game, decoded) {
  const prev = game.gameState;
  game.gameState = {
    ...prev,
    ...decoded,
    ball: {
      x: decoded.ballX,
      y: decoded.ballY,
      vx: decoded.ballVX,
      vy: decoded.ballVY,
      speed: prev.ball ? prev.ball.speed : 0,
      height: decoded.ballHeight,
      heightVel: prev.ball ? prev.ball.heightVel : 0,
    },
  };
}

export default defineGame({
  inputs: {
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
    left: ["ArrowLeft", "a", "A"],
    right: ["ArrowRight", "d", "D"],
    serve: [" ", "Shift"],
  },
  captureKeys: [
    "ArrowUp",
    "ArrowDown",
    "ArrowLeft",
    "ArrowRight",
    " ",
    "Spacebar",
    "Shift",
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
  ai: { create: createTennisAI, difficulty: normalizeTennisAIDifficulty },
  audio: { sounds: SOUNDS },
  theme: getColors,
  // The game id picks the format: classic, quick or sudden death.
  init: (game) => {
    game.gameMode = MODE_MAP[game.gameId] ?? GAME_MODE.CLASSIC;
    return createInitialState(game.gameMode);
  },
  setup: (game) => {
    game.localServePressed = false;
    game.remoteServePressed = false;
    game.pointPauseCounter = 0;
  },
  onStop: (game) => {
    game.localServePressed = false;
    game.remoteServePressed = false;
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      // The beep sounds on each second that passes, the last one included.
      COUNTDOWN: {
        enter: (game) => {
          game.gameState.countdown = COUNTDOWN_FROM;
          game.broadcast();
          game.invalidate();
        },
        every: { ticks: COUNTDOWN_EVERY_TICKS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          game.audio.playCountdown();
          if (remaining === 0) {
            game.gameState.phase = PHASE.SERVING;
            game.frameCount = 0;
          }
          game.gameState.countdown = remaining;
          game.broadcast();
          game.invalidate();
        },
        next: "SERVING",
      },
      SERVING: { tick: play },
      RALLY: { tick: play },
      POINT: { tick: play },
      CHANGEOVER: { tick: play },
      GAME_OVER: {
        final: true,
        enter: (game) => {
          const { p1Games, p2Games, winner, gameMode, isTiebreak } = game.gameState;
          game.broadcast();
          game.invalidate();
          if (winner > 0) playEnd(game, winner);
          game.finish({
            end: { p1Games, p2Games, winner, gameMode, wasTiebreak: isTiebreak },
            result: { score: { p1: p1Games, p2: p2Games }, winner },
            broadcast: false,
          });
        },
      },
    },
  },

  toWire,
  applySnapshot,
  // The guest hears the countdown, each point, and every event a snapshot newly carries.
  cues: [
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    { phase: PHASE.POINT, play: "point" },
    { rise: (s) => s.hitEvent, play: "hit" },
    { rise: (s) => s.serveEvent, play: "serve" },
    { rise: (s) => s.faultEvent, play: "fault" },
    { rise: (s) => s.netFault, play: "netHit" },
    {
      rise: (s) => s.outOfBounds,
      play: (game, s) => (s.outType === 3 ? game.audio.playAce() : game.audio.playOut()),
    },
  ],
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    Object.assign(game.gameState, {
      phase: PHASE.GAME_OVER,
      winner: result.winner,
      p1Games: result.p1Games,
      p2Games: result.p2Games,
    });
    playEnd(game, result.winner);
    game.invalidate();
  },
  render: (game) => {
    if (game.colors) render(game.ctx, game.gameState, game.colors, performance.now());
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.p1Games, p2: game.gameState.p2Games },
    winner: 0,
  }),
});
