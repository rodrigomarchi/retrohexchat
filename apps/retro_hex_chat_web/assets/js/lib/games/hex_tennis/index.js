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

import { ARROWS_WASD_SPACE, ARROW_KEYS, defineGame } from "../core/define_game.js";
import { beepCountdownState } from "../core/rounds.js";
import { drawOnDisconnect, guestEnd, playOutcome } from "../core/result.js";
import { createTennisAI, normalizeTennisAIDifficulty } from "./ai.js";
import {
  createInitialState,
  resetForNextPoint,
  shouldChangeover,
  stepRally,
  stepServing,
} from "./physics.js";
import { GAME_END, GAME_MODE, PHASE, SNAPSHOT } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const POINT_PAUSE_FRAMES = 120; // 2 s at 60 steps a second
const CHANGEOVER_PAUSE_FRAMES = 120;

const MODE_MAP = {
  hex_tennis: GAME_MODE.CLASSIC,
  hex_tennis_quick: GAME_MODE.QUICK,
  hex_tennis_sudden: GAME_MODE.SUDDEN_DEATH,
};

/** The server moves and serves on the press; the serve clock serves for them when it runs out. */
function serving(game, state) {
  const pressed = { local: game.localServePressed, remote: game.remoteServePressed };
  const next = stepServing(state, game.localInputs, game.remoteInputs, pressed, game.random);
  if (next.served) game.audio.playServe();
  game.localServePressed = next.pressed.local;
  game.remoteServePressed = next.pressed.remote;
  game.gameState = next.state;
}

/**
 * The ball in play. Returns `false` when the step ends here: a point is
 * announced at once, and the match's end reports itself on entering GAME_OVER.
 */
function rally(game, state) {
  const prev = game.gameState;
  const { state: s, point } = stepRally(state, game.localInputs, game.remoteInputs);
  game.gameState = s;
  if (s.hitEvent && !prev.hitEvent) game.audio.playHit();
  if (s.faultEvent && !prev.faultEvent) game.audio.playFault();
  if (s.netFault && !prev.netFault) game.audio.playNetHit();
  if (s.outOfBounds && !prev.outOfBounds) {
    if (s.outType === 3) game.audio.playAce();
    else game.audio.playOut();
  }
  if (!point) return true;

  game.audio.playPoint();
  if (s.phase === PHASE.GAME_OVER) return false;
  game.pointPauseCounter = POINT_PAUSE_FRAMES;
  game.invalidate();
  game.broadcast();
  return false;
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
    up: ARROW_KEYS.up,
    down: ARROW_KEYS.down,
    left: ARROW_KEYS.left,
    right: ARROW_KEYS.right,
    serve: [" ", "Shift"],
  },
  captureKeys: [...ARROWS_WASD_SPACE, "Shift"],
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
      // The beep sounds on each second that passes; the last one brings the serve.
      COUNTDOWN: beepCountdownState({
        next: "SERVING",
        start: (game) => {
          game.gameState.phase = PHASE.SERVING;
          game.frameCount = 0;
          game.gameState.countdown = 0;
          game.broadcast();
          game.invalidate();
        },
      }),
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
          if (winner > 0) playOutcome(game, winner, "playMatchWon", "playMatchLost");
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
  onEnd: guestEnd({
    phase: PHASE.GAME_OVER,
    fields: ["winner", "p1Games", "p2Games"],
    sound: (game, result) => playOutcome(game, result.winner, "playMatchWon", "playMatchLost"),
  }),
  render: (game) => render(game.ctx, game.gameState, game.colors, performance.now()),
  disconnectResult: drawOnDisconnect((s) => [s.p1Games, s.p2Games]),
});
