import { defineGame } from "../../../js/lib/games/core/define_game.js";
import { schema, i16, u8 } from "../../../js/lib/games/core/codec.js";
import { MSG } from "../../../js/lib/games/core/messages.js";

/**
 * The smallest game the core can run: a dot that walks right while a player
 * holds the key, and scores for that player at the wall. First to two wins.
 * The core's own tests play it, so the core is proved without any real game.
 */
export const PHASE = { WAITING: 0, COUNTDOWN: 1, PLAYING: 2, FINISHED: 3 };

export const SNAPSHOT = schema(MSG.GAME_STATE, [
  u8("phase"),
  u8("countdown"),
  i16("x"),
  u8("score1"),
  u8("score2"),
]);
export const GAME_END = schema(MSG.GAME_END, [u8("score1"), u8("score2"), u8("winner")]);

const step = (game) => {
  game.updateOpponent();
  const s = game.gameState;
  if (game.localInputs.right) s.x += 1;
  if (game.remoteInputs.right) s.x -= 1;
  if (s.x >= 10) [s.score1, s.x] = [s.score1 + 1, 0];
  if (s.x <= -10) [s.score2, s.x] = [s.score2 + 1, 0];
  if (s.score1 >= 2 || s.score2 >= 2) s.phase = PHASE.FINISHED;
  game.broadcast();
};

const winner = (s) => (s.score1 > s.score2 ? 1 : 2);

export const definition = {
  inputs: { right: ["ArrowRight"] },
  captureKeys: ["ArrowRight", " "],
  interpolate: { keys: ["x"] },
  schema: { snapshot: SNAPSHOT, end: GAME_END },
  ai: {
    create: ({ difficulty }) => ({ difficulty, nextInputs: () => ({ right: true, extra: true }) }),
    difficulty: (d) => d || "normal",
  },
  theme: () => ({ bg: "black" }),
  init: () => ({ phase: PHASE.WAITING, countdown: 0, x: 0, score1: 0, score2: 0 }),
  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "COUNTDOWN",
    states: {
      COUNTDOWN: {
        enter: (game) => {
          game.gameState.countdown = 2;
          game.broadcast();
        },
        every: { ticks: 6, count: 2 },
        onEvery: (game, left) => {
          game.gameState.countdown = left;
          game.broadcast();
        },
        next: "PLAYING",
      },
      PLAYING: { tick: step },
      FINISHED: {
        final: true,
        enter: (game) => {
          const s = game.gameState;
          game.finish({
            end: { score1: s.score1, score2: s.score2, winner: winner(s) },
            result: { score: { p1: s.score1, p2: s.score2 }, winner: winner(s) },
          });
        },
      },
    },
  },
  onEnd: (game, result) => {
    game.gameState.phase = PHASE.FINISHED;
    game.ended = result;
  },
  onStop: (game) => {
    game.stoppedWhileRunning = game.running;
  },
  render: (game) => {
    game.ctx.fillRect(game.gameState.x, 0, 1, 1);
  },
  disconnectResult: (game) => ({
    score: { p1: game.gameState.score1, p2: game.gameState.score2 },
    winner: 0,
  }),
};

export const FakeGame = defineGame(definition);
