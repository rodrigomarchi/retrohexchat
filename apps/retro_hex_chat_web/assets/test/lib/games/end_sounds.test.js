// The sound at the end of a match follows who won, for whoever is at the
// screen: the guest who lost hears the losing sound, the host who lost too.
// Cooperative endings (Block Breakers, Invaders' co-op) are heard alike by
// both players, and a one-player game has nobody to beat: neither is here.

import { describe, expect, it, vi } from "vitest";
import { fakeChannel } from "../../support/games/fake_channel.js";
import { createLocalTransport } from "../../../js/lib/games/transport.js";
import { IDLE_SOLO, engineEachTest, loadGame } from "../../support/games/engine_ends.js";
import { recordingCanvas } from "../../support/games/recording_canvas.js";
import { GAME_DIRS, ONE_PLAYER_DIRS } from "../../support/games/engines.js";

const createMockCanvas = () => recordingCanvas(640, 480);

const games = {
  pong: { win: "playWin", lose: "playLose" },
  star_duel: { win: "playWin", lose: "playLose" },
  hex_frost: { win: "playVictory", lose: "playGameOver" },
  hex_skiing: { win: "playVictory", lose: "playGameOver" },
  hex_hockey: { win: "playVictory", lose: "playLose", wire: { 1: "p1", 2: "p2" } },
  hex_invaders: { win: "playVictory", lose: "playInvaded" },
  hex_tennis: { win: "playMatchWon", lose: "playMatchLost" },
  hex_boxing: { win: "playWin", lose: "playLose" },
  hex_outlaw: { win: "playWin", lose: "playLose" },
  hex_raid: { win: "playWin", lose: "playLose" },
  pixel_tanks: { win: "playWin", lose: "playLose" },
  surround: { win: "playMatchWin", lose: "playMatchLose" },
  hex_warlords: { win: "playWin", lose: "playLose", dir: "warlords" },
  hex_enduro: { win: "playVictory", lose: "playGameOver" },
};

const load = (gameId) => loadGame(games[gameId].dir ?? gameId);

function spySounds(engine, gameId) {
  const { win, lose } = games[gameId];
  return { win: vi.spyOn(engine.audio, win), lose: vi.spyOn(engine.audio, lose) };
}

const keep = engineEachTest();

/** The `heard` sound played once, and the other not at all. */
function expectHeardAlone(sounds, heard) {
  expect(sounds[heard]).toHaveBeenCalledTimes(1);
  expect(sounds[heard === "win" ? "lose" : "win"]).not.toHaveBeenCalled();
}

describe("the games heard here", () => {
  it("are every game folder but the co-operative one and the one-player ones", () => {
    const heard = Object.entries(games).map(([gameId, end]) => end.dir ?? gameId);
    expect(new Set([...heard, "breakout", ...ONE_PLAYER_DIRS])).toEqual(new Set(GAME_DIRS));
  });
});

describe("the guest's end-of-match sound", () => {
  for (const gameId of Object.keys(games)) {
    for (const [winner, heard] of [
      [2, "win"],
      [1, "lose"],
    ]) {
      it(`${gameId}: a guest told player ${winner} won hears the ${heard}`, async () => {
        const { Game, GAME_END } = await load(gameId);
        const channel = fakeChannel();
        const engine = keep(new Game(createMockCanvas(), channel, gameId, false, null));
        engine.start();
        const sounds = spySounds(engine, gameId);
        const wire = games[gameId].wire?.[winner] ?? winner;

        channel.emit("message", { data: GAME_END.encode({ winner: wire, score1: 0, score2: 0 }) });

        expectHeardAlone(sounds, heard);
      });
    }
  }
});

// How each of these games brings its host to the end with a given winner.
const hostEndings = {
  pong: (e, winner) => {
    e.gameState.winner = winner;
    e.flow.go("FINISHED");
  },
  star_duel: async (e, winner) => {
    const { WIN_SCORE } = await import("../../../js/lib/games/star_duel/physics.js");
    e.gameState[winner === 1 ? "score1" : "score2"] = WIN_SCORE;
    e.flow.go("FINISHED");
  },
  hex_frost: (e, winner) => {
    e.gameState.p1 = { ...e.gameState.p1, roundWins: winner === 1 ? 3 : 0 };
    e.gameState.p2 = { ...e.gameState.p2, roundWins: winner === 2 ? 3 : 0 };
    e.flow.go("FINISHED");
  },
  hex_skiing: async (e, winner) => {
    const { finishMatch } = await import("../../../js/lib/games/hex_skiing/index.js");
    finishMatch(e, {
      ...e.gameState,
      p1RoundWins: winner === 1 ? 2 : 0,
      p2RoundWins: winner === 2 ? 2 : 0,
    });
  },
  hex_hockey: async (e, winner) => {
    const { finishMatch } = await import("../../../js/lib/games/hex_hockey/index.js");
    finishMatch(e, {
      ...e.gameState,
      scoreP1: winner === 1 ? 3 : 0,
      scoreP2: winner === 2 ? 3 : 0,
    });
  },
  hex_invaders: (e, winner) => {
    e.endResult = { ended: true, winner };
    e.flow.go("FINISHED");
  },
  hex_tennis: (e, winner) => {
    e.gameState.winner = winner;
    e.flow.go("GAME_OVER");
  },
};

describe("the host's end-of-match sound", () => {
  for (const [gameId, end] of Object.entries(hostEndings)) {
    for (const [winner, heard] of [
      [1, "win"],
      [2, "lose"],
    ]) {
      it(`${gameId}: a host whose match player ${winner} won hears the ${heard}`, async () => {
        const { Game } = await load(gameId);
        const engine = keep(
          new Game(createMockCanvas(), createLocalTransport(), gameId, true, null, IDLE_SOLO),
        );
        engine.start();
        const sounds = spySounds(engine, gameId);

        await end(engine, winner);

        expectHeardAlone(sounds, heard);
      });
    }
  }
});
