/**
 * Light Trails: two light cycles on a grid, each leaving a wall behind it;
 * the one that crashes loses the round.
 *
 * Input is a discrete command (turn this way), not a held key: the guest
 * sends each turn as an edge and the host applies it on the next grid move,
 * ten a second. The match lifecycle comes from `defineGame`; this file says
 * only what is Light Trails'.
 *
 * @module games/surround
 */

import { gameColor } from "../../game_colors.js";
import { defineGame } from "../core/define_game.js";
import { createSurroundAI, normalizeSurroundAIDifficulty } from "./ai.js";
import { SurroundAudio } from "./audio.js";
import {
  CELL,
  createCrashParticles,
  createInitialState,
  moveAndCheck,
  updateParticles,
} from "./physics.js";
import { GAME_END, INPUT_KEY, PHASE, SNAPSHOT, WINS_NEEDED } from "./protocol.js";
import { getColors, render } from "./renderer.js";

const TICK_STEPS = 6; // one grid move every 6 fixed steps (10 Hz)
const ROUND_OVER_DELAY_TICKS = 180; // 3 s
const COUNTDOWN_FROM = 3;
const COUNTDOWN_EVERY_TICKS = 60; // 1 s

const KEYS = {
  ArrowUp: INPUT_KEY.UP,
  w: INPUT_KEY.UP,
  W: INPUT_KEY.UP,
  ArrowDown: INPUT_KEY.DOWN,
  s: INPUT_KEY.DOWN,
  S: INPUT_KEY.DOWN,
  ArrowLeft: INPUT_KEY.LEFT,
  a: INPUT_KEY.LEFT,
  A: INPUT_KEY.LEFT,
  ArrowRight: INPUT_KEY.RIGHT,
  d: INPUT_KEY.RIGHT,
  D: INPUT_KEY.RIGHT,
};

const turnFor = (key) => (Object.hasOwn(KEYS, key) ? KEYS[key] : null);

/** In solo play, the AI turns player two's cycle. */
function steerOpponent(game) {
  if (game.mode !== "solo" || typeof game.opponentController?.nextDirection !== "function") return;
  const next = game.opponentController.nextDirection({
    state: game.gameState,
    difficulty: game.difficulty,
    player: 2,
  });
  if (Number.isInteger(next) && next >= 0 && next <= 3) game.p2PendingDir = next;
}

/** A grid move on the host, every TICK_STEPS fixed steps. */
function move(game) {
  game.invalidate();
  game.tickFrames += 1;
  if (game.tickFrames < TICK_STEPS) return;
  game.tickFrames = 0;
  if (game.gameState.phase !== PHASE.PLAYING) return;

  steerOpponent(game);
  const s = moveAndCheck(game.gameState, game.p1PendingDir, game.p2PendingDir);
  game.gameState = s;
  if (s.p1Dead || s.p2Dead) {
    crash(game, s.p1Dead, s.p2Dead);
    return;
  }
  game.broadcast();
}

/** A crash ends the round, and the match once someone has enough rounds. */
function crash(game, p1Dead, p2Dead) {
  const s = game.gameState;
  game.audio.playCrash();
  if (p1Dead) {
    s.particles = [
      ...s.particles,
      ...createCrashParticles(s.p1.x, s.p1.y, gameColor("00ff41"), game.fxRandom),
    ];
  }
  if (p2Dead) {
    s.particles = [
      ...s.particles,
      ...createCrashParticles(s.p2.x, s.p2.y, gameColor("00d4ff"), game.fxRandom),
    ];
  }

  if (p1Dead && !p2Dead) s.score2++;
  else if (p2Dead && !p1Dead) s.score1++;
  game.savedScores = { score1: s.score1, score2: s.score2 };

  if (s.score1 >= WINS_NEEDED || s.score2 >= WINS_NEEDED) {
    s.phase = PHASE.MATCH_OVER;
    game.broadcast();
    return;
  }

  s.phase = PHASE.ROUND_OVER;
  if (!p1Dead && p2Dead) game.audio.playRoundWin();
  game.broadcast();
}

/** The guest rebuilds each round from its countdown and draws the trails as they grow. */
function applySnapshot(game, decoded) {
  const prevPhase = game.gameState.phase;
  if (decoded.phase === PHASE.COUNTDOWN && prevPhase !== PHASE.COUNTDOWN) {
    const fresh = createInitialState(decoded.round);
    Object.assign(fresh, {
      score1: decoded.score1,
      score2: decoded.score2,
      phase: decoded.phase,
      countdown: decoded.countdown,
    });
    game.gameState = fresh;
    game.audio.playCountdown();
    return;
  }

  const s = game.gameState;
  if (decoded.phase === PHASE.COUNTDOWN && decoded.countdown !== s.countdown) {
    game.audio.playCountdown();
  }
  if (decoded.phase === PHASE.ROUND_OVER && prevPhase !== PHASE.ROUND_OVER) {
    game.audio.playCrash();
    if (decoded.score1 <= s.score1 && decoded.score2 > s.score2) game.audio.playRoundWin();
  }
  if (decoded.phase === PHASE.PLAYING) {
    s.grid[decoded.p1y][decoded.p1x] = CELL.P1_TRAIL;
    s.grid[decoded.p2y][decoded.p2x] = CELL.P2_TRAIL;
  }
  s.p1 = { x: decoded.p1x, y: decoded.p1y, dir: decoded.p1dir };
  s.p2 = { x: decoded.p2x, y: decoded.p2y, dir: decoded.p2dir };
  Object.assign(s, {
    score1: decoded.score1,
    score2: decoded.score2,
    phase: decoded.phase,
    countdown: decoded.countdown,
    round: decoded.round,
  });
}

export default defineGame({
  inputs: {},
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
  ai: { create: createSurroundAI, difficulty: normalizeSurroundAIDifficulty },
  audio: SurroundAudio,
  theme: getColors,
  init: () => createInitialState(0),
  setup: (game) => {
    game.p1PendingDir = game.gameState.p1.dir;
    game.p2PendingDir = game.gameState.p2.dir;
    game.savedScores = { score1: 0, score2: 0 };
    game.nextRound = 0;
    game.tickFrames = 0;
  },
  idle: (game) => game.invalidate(),

  onKeyDown: (game, event) => {
    const turn = turnFor(event.key);
    if (turn === null) return;
    event.preventDefault();
    if (game.isHost) game.p1PendingDir = turn;
    else game._sendInputEdge(turn);
    game.audio.playMove();
  },
  onKeyUp: (_game, event) => {
    if (turnFor(event.key) !== null) event.preventDefault();
  },
  onRemoteEdge: (game, code) => {
    if (code >= 0 && code <= 3) game.p2PendingDir = code;
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      // Every round starts from a fresh grid, keeping the scores.
      COUNTDOWN: {
        enter: (game) => {
          const fresh = createInitialState(game.nextRound);
          Object.assign(fresh, {
            ...game.savedScores,
            phase: PHASE.COUNTDOWN,
            countdown: COUNTDOWN_FROM,
          });
          game.gameState = fresh;
          game.p1PendingDir = fresh.p1.dir;
          game.p2PendingDir = fresh.p2.dir;
          game.broadcast();
          game.audio.playCountdown();
        },
        every: { ticks: COUNTDOWN_EVERY_TICKS, count: COUNTDOWN_FROM },
        onEvery: (game, remaining) => {
          if (remaining === 0) return;
          game.gameState.countdown = remaining;
          game.broadcast();
          game.audio.playCountdown();
        },
        next: "PLAYING",
      },
      PLAYING: {
        enter: (game) => {
          game.gameState.countdown = 0;
          game.broadcast();
          game.tickFrames = 0;
        },
        tick: move,
      },
      ROUND_OVER: {
        after: { ticks: ROUND_OVER_DELAY_TICKS },
        then: (game) => {
          game.nextRound = game.gameState.round + 1;
        },
        next: "COUNTDOWN",
      },
      MATCH_OVER: {
        final: true,
        enter: (game) => {
          const { score1, score2 } = game.gameState;
          const winner = score1 >= WINS_NEEDED ? 1 : 2;
          if (winner === 1) game.audio.playMatchWin();
          else game.audio.playMatchLose();
          game.finish({
            end: { score1, score2, winner },
            result: { score: { p1: score1, p2: score2 }, winner },
            broadcast: false,
          });
        },
      },
    },
  },

  applySnapshot,
  onEnd: (game, result) => {
    game.setKeyboardCaptured(false);
    Object.assign(game.gameState, {
      phase: PHASE.MATCH_OVER,
      score1: result.score1,
      score2: result.score2,
    });
    if (result.winner === 2) game.audio.playMatchWin();
    else game.audio.playMatchLose();
  },
  render: (game) => {
    const s = game.gameState;
    if (s.particles && s.particles.length > 0) s.particles = updateParticles(s.particles);
    if (game.colors) render(game.ctx, s, game.colors, performance.now());
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.score1, p2: game.gameState.score2 },
    winner: 0,
  }),
});
