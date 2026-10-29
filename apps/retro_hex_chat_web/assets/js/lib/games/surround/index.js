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
import { ARROW_KEYS, ARROWS_WASD_SPACE, defineGame } from "../core/define_game.js";
import { COUNTDOWN, countdownState } from "../core/rounds.js";
import { drawOnDisconnect, finishScored, guestEnd, playOutcome } from "../core/result.js";
import { createSurroundAI, normalizeSurroundAIDifficulty } from "./ai.js";
import {
  applyDirection,
  CELL,
  createCrashParticles,
  createInitialState,
  moveAndCheck,
  updateParticles,
} from "./physics.js";
import { GAME_END, INPUT_KEY, PHASE, SNAPSHOT, WINS_NEEDED } from "./protocol.js";
import { getColors, render } from "./renderer.js";
import { SOUNDS } from "./sounds.js";

const TICK_STEPS = 6; // one grid move every 6 fixed steps (10 Hz)
const ROUND_OVER_DELAY_TICKS = 180; // 3 s

/** Each key of a direction, to the turn it asks for. */
const KEYS = Object.fromEntries(
  Object.entries(ARROW_KEYS).flatMap(([direction, keys]) =>
    keys.map((key) => [key, INPUT_KEY[direction.toUpperCase()]]),
  ),
);

const turnFor = (key) => (Object.hasOwn(KEYS, key) ? KEYS[key] : null);

const MAX_QUEUED_TURNS = 2;

/**
 * A turn asked for by a player. While an earlier turn still waits for the
 * grid to move, this one waits behind it for the move after, so two quick
 * presses — up, then left — make both turns instead of only the last.
 */
function requestTurn(game, player, turn) {
  const pendingKey = player === 1 ? "p1PendingDir" : "p2PendingDir";
  const queue = player === 1 ? game.p1Turns : game.p2Turns;
  const heading = (player === 1 ? game.gameState.p1 : game.gameState.p2).dir;
  const pending = game[pendingKey];
  const waiting = pending !== heading && applyDirection(heading, pending) === pending;
  if (waiting && turn !== pending) {
    if (queue.length < MAX_QUEUED_TURNS) queue.push(turn);
    return;
  }
  game[pendingKey] = turn;
}

/** After a move, each player's next waiting turn becomes the pending one. */
function takeQueuedTurns(game) {
  const s = game.gameState;
  game.p1PendingDir = game.p1Turns.shift() ?? s.p1.dir;
  game.p2PendingDir = game.p2Turns.shift() ?? s.p2.dir;
}

/** Every round starts with nothing pending but each cycle's own heading. */
function clearTurns(game) {
  game.p1PendingDir = game.gameState.p1.dir;
  game.p2PendingDir = game.gameState.p2.dir;
  game.p1Turns = [];
  game.p2Turns = [];
}

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
  takeQueuedTurns(game);
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
    return;
  }

  const s = game.gameState;
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
  captureKeys: ARROWS_WASD_SPACE,
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: { create: createSurroundAI, difficulty: normalizeSurroundAIDifficulty },
  audio: { sounds: SOUNDS },
  theme: getColors,
  init: () => createInitialState(0),
  setup: (game) => {
    clearTurns(game);
    game.savedScores = { score1: 0, score2: 0 };
    game.nextRound = 0;
    game.tickFrames = 0;
  },
  idle: (game) => game.invalidate(),

  onKeyDown: (game, event) => {
    const turn = turnFor(event.key);
    if (turn === null) return;
    event.preventDefault();
    if (game.isHost) requestTurn(game, 1, turn);
    else game.sendInputEdge(turn);
    game.audio.playMove();
  },
  onKeyUp: (_game, event) => {
    if (turnFor(event.key) !== null) event.preventDefault();
  },
  onRemoteEdge: (game, code) => {
    if (code >= 0 && code <= 3) requestTurn(game, 2, code);
  },

  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      // Every round starts from a fresh grid, keeping the scores.
      COUNTDOWN: {
        ...countdownState({ next: "PLAYING" }),
        enter: (game) => {
          const fresh = createInitialState(game.nextRound);
          Object.assign(fresh, {
            ...game.savedScores,
            phase: PHASE.COUNTDOWN,
            countdown: COUNTDOWN.from,
          });
          game.gameState = fresh;
          clearTurns(game);
          game.broadcast();
          game.audio.playCountdown();
        },
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
          finishScored(game, score1, score2, winner, { broadcast: false });
        },
      },
    },
  },

  applySnapshot,
  // The guest hears each beat of the countdown, a crash, and a round it won.
  cues: [
    { phase: PHASE.COUNTDOWN, play: "countdown" },
    {
      when: (s, prev) =>
        s.phase === PHASE.COUNTDOWN &&
        prev.phase === PHASE.COUNTDOWN &&
        s.countdown !== prev.countdown,
      play: "countdown",
    },
    { phase: PHASE.ROUND_OVER, play: "crash" },
    {
      when: (s, prev) =>
        s.phase === PHASE.ROUND_OVER &&
        prev.phase !== PHASE.ROUND_OVER &&
        s.score1 <= prev.score1 &&
        s.score2 > prev.score2,
      play: "roundWin",
    },
  ],
  onEnd: guestEnd({
    phase: PHASE.MATCH_OVER,
    fields: ["score1", "score2"],
    sound: (game, result) => playOutcome(game, result.winner, "playMatchWin", "playMatchLose"),
    repaint: false,
  }),
  render: (game) => {
    const s = game.gameState;
    if (s.particles && s.particles.length > 0) s.particles = updateParticles(s.particles);
    render(game.ctx, s, game.colors, performance.now());
  },
  disconnectResult: drawOnDisconnect((s) => [s.score1, s.score2]),
});
