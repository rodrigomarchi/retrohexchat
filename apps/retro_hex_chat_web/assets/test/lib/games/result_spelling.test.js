// Every game reports the end of a match in one spelling — a nested score and
// a numeric winner — whether the match was played out, told to the guest, or
// cut short by the channel. The server still reads the older spellings, for
// browsers holding an older chunk; nothing sends them any more.

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createLocalTransport } from "../../../js/lib/games/transport.js";
import { recordingAudio } from "../../support/games/recording_audio.js";
import { recordingCanvas } from "../../support/games/recording_canvas.js";

const GAMES = {
  pong: "pong",
  star_duel: "star_duel",
  hex_frost: "hex_frost",
  hex_skiing: "hex_skiing",
  hex_hockey: "hex_hockey",
  hex_invaders: "hex_invaders",
  hex_tennis: "hex_tennis",
  hex_boxing: "hex_boxing",
  hex_outlaw: "hex_outlaw",
  hex_raid: "hex_raid",
  pixel_tanks: "pixel_tanks",
  surround: "surround",
  hex_warlords: "warlords",
  hex_enduro: "hex_enduro",
  block_breakers: "breakout",
};

const channel = () => ({
  readyState: "open",
  send: vi.fn(),
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
});

async function load(gameId) {
  const dir = GAMES[gameId];
  const [{ default: Game }, { GAME_END }] = await Promise.all([
    import(`../../../js/lib/games/${dir}/index.js`),
    import(`../../../js/lib/games/${dir}/protocol.js`),
  ]);
  return { Game, GAME_END };
}

function expectOneSpelling(result) {
  expect(Object.keys(result).sort()).toEqual(
    "disconnected" in result ? ["disconnected", "score", "winner"] : ["score", "winner"],
  );
  expect(Object.keys(result.score).sort()).toEqual(["p1", "p2"]);
  expect(Number.isInteger(result.score.p1)).toBe(true);
  expect(Number.isInteger(result.score.p2)).toBe(true);
  expect(Number.isInteger(result.winner)).toBe(true);
}

let engine = null;
beforeEach(() => {
  recordingAudio();
});
afterEach(() => {
  engine?.stop();
  engine = null;
  vi.restoreAllMocks();
});

describe("a match cut short by the channel", () => {
  for (const gameId of Object.keys(GAMES)) {
    it(`${gameId}: reports the disconnect in the one spelling`, async () => {
      const { Game } = await load(gameId);
      const results = [];
      engine = new Game(
        recordingCanvas(640, 480),
        createLocalTransport(),
        gameId,
        true,
        (r) => results.push(r),
        {
          mode: "solo",
          opponentController: { nextInputs: () => ({}), nextDirection: () => null },
        },
      );
      engine.start();
      expect(engine.beginMatch()).toBe(true);

      engine._handleChannelClose();

      expect(results).toHaveLength(1);
      expect(results[0].disconnected).toBe(true);
      expectOneSpelling(results[0]);
    });
  }
});

describe("a match told to the guest", () => {
  for (const gameId of Object.keys(GAMES)) {
    it(`${gameId}: if the guest reports what it is told, it is in the one spelling`, async () => {
      const { Game, GAME_END } = await load(gameId);
      const results = [];
      engine = new Game(recordingCanvas(640, 480), channel(), gameId, false, (r) =>
        results.push(r),
      );
      engine.start();
      const winner = gameId === "hex_hockey" ? "p2" : 2;

      engine._onChannelMessage({
        data: GAME_END.encode({
          winner,
          score1: 1,
          score2: 2,
          score_p1: 1,
          score_p2: 2,
          won: true,
        }),
      });

      for (const result of results) expectOneSpelling(result);
    });
  }
});

// The games whose host spelled its result its own way.
const hostEndings = {
  hex_frost: (e) => {
    e.gameState.p1 = { ...e.gameState.p1, roundWins: 3 };
    e.flow.go("FINISHED");
  },
  hex_skiing: async (e) => {
    const { finishMatch } = await import("../../../js/lib/games/hex_skiing/index.js");
    finishMatch(e, { ...e.gameState, p1RoundWins: 2, p2RoundWins: 0 });
  },
  hex_hockey: async (e) => {
    const { finishMatch } = await import("../../../js/lib/games/hex_hockey/index.js");
    finishMatch(e, { ...e.gameState, scoreP1: 1, scoreP2: 3 });
  },
};

describe("a match played out", () => {
  for (const [gameId, end] of Object.entries(hostEndings)) {
    it(`${gameId}: the host reports it in the one spelling`, async () => {
      const { Game } = await load(gameId);
      const results = [];
      engine = new Game(
        recordingCanvas(640, 480),
        createLocalTransport(),
        gameId,
        true,
        (r) => results.push(r),
        {
          mode: "solo",
          opponentController: { nextInputs: () => ({}) },
        },
      );
      engine.start();

      await end(engine);

      expect(results).toHaveLength(1);
      expectOneSpelling(results[0]);
    });
  }

  it("hex_hockey: two goals ahead is player two's win", async () => {
    const { Game } = await load("hex_hockey");
    const { finishMatch } = await import("../../../js/lib/games/hex_hockey/index.js");
    const results = [];
    engine = new Game(recordingCanvas(640, 480), createLocalTransport(), "hex_hockey", true, (r) =>
      results.push(r),
    );
    engine.start();

    finishMatch(engine, { ...engine.gameState, scoreP1: 1, scoreP2: 3, period: 3 });

    expect(results).toEqual([{ score: { p1: 1, p2: 3 }, winner: 2 }]);
  });
});
