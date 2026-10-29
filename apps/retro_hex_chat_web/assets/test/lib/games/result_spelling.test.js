// Every game reports the end of a match in one spelling — a nested score and
// a numeric winner — whether the match was played out or cut short by the
// channel. The server still reads the older spellings, for
// browsers holding an older chunk; nothing sends them any more.

import { describe, expect, it } from "vitest";
import { createLocalTransport } from "../../../js/lib/games/transport.js";
import { IDLE_SOLO, engineEachTest, loadGame } from "../../support/games/engine_ends.js";
import { fakeChannel } from "../../support/games/fake_channel.js";
import { recordingCanvas } from "../../support/games/recording_canvas.js";
import { GAME_DIRS, ONE_PLAYER_DIRS } from "../../support/games/engines.js";

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

// A one-player game is cut short by nothing and told nothing by a guest; its
// own result, soloResult, is its match test's.
describe("the games checked here", () => {
  it("are every two-player game folder", () => {
    expect(new Set([...Object.values(GAMES), ...ONE_PLAYER_DIRS])).toEqual(new Set(GAME_DIRS));
  });
});

const load = (gameId) => loadGame(GAMES[gameId]);

function expectOneSpelling(result) {
  expect(Object.keys(result).sort()).toEqual(
    "disconnected" in result ? ["disconnected", "score", "winner"] : ["score", "winner"],
  );
  expect(Object.keys(result.score).sort()).toEqual(["p1", "p2"]);
  expect(Number.isInteger(result.score.p1)).toBe(true);
  expect(Number.isInteger(result.score.p2)).toBe(true);
  expect(Number.isInteger(result.winner)).toBe(true);
}

const keep = engineEachTest();

describe("a match cut short by the channel", () => {
  for (const gameId of Object.keys(GAMES)) {
    it(`${gameId}: reports the disconnect in the one spelling`, async () => {
      const { Game } = await load(gameId);
      const results = [];
      const channel = fakeChannel();
      const engine = keep(
        new Game(
          recordingCanvas(640, 480),
          channel,
          gameId,
          true,
          (r) => results.push(r),
          IDLE_SOLO,
        ),
      );
      engine.start();
      expect(engine.beginMatch()).toBe(true);

      channel.emit("close");

      expect(results).toHaveLength(1);
      expect(results[0].disconnected).toBe(true);
      expectOneSpelling(results[0]);
    });
  }
});

// Only the host's result is the match's: the server refuses a guest's
// (Lobby.SessionServer), so a guest told the match is over reports nothing.
describe("a match told to the guest", () => {
  for (const gameId of Object.keys(GAMES)) {
    it(`${gameId}: the guest reports nothing`, async () => {
      const { Game, GAME_END } = await load(gameId);
      const results = [];
      const channel = fakeChannel();
      keep(
        new Game(recordingCanvas(640, 480), channel, gameId, false, (r) => results.push(r)),
      ).start();
      const winner = gameId === "hex_hockey" ? "p2" : 2;

      channel.emit("message", {
        data: GAME_END.encode({
          winner,
          score1: 1,
          score2: 2,
          score_p1: 1,
          score_p2: 2,
          won: true,
        }),
      });

      expect(results).toEqual([]);
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
      const engine = keep(
        new Game(
          recordingCanvas(640, 480),
          createLocalTransport(),
          gameId,
          true,
          (r) => results.push(r),
          IDLE_SOLO,
        ),
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
    const engine = keep(
      new Game(recordingCanvas(640, 480), createLocalTransport(), "hex_hockey", true, (r) =>
        results.push(r),
      ),
    );
    engine.start();

    finishMatch(engine, { ...engine.gameState, scoreP1: 1, scoreP2: 3, period: 3 });

    expect(results).toEqual([{ score: { p1: 1, p2: 3 }, winner: 2 }]);
  });
});
