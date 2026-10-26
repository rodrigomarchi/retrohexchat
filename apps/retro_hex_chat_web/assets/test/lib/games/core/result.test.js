import { describe, expect, it, vi } from "vitest";
import {
  drawOnDisconnect,
  guestEnd,
  matchResult,
  playOutcome,
  soloResult,
} from "../../../../js/lib/games/core/result.js";

describe("matchResult", () => {
  it("spells a result the one way the server reads for every game", () => {
    expect(matchResult(3, 1, 1)).toEqual({ score: { p1: 3, p2: 1 }, winner: 1 });
  });

  it("keeps a draw, and a co-op pair's win (0) or loss (-1), as numbers", () => {
    expect(matchResult(2, 2, 0)).toEqual({ score: { p1: 2, p2: 2 }, winner: 0 });
    expect(matchResult(40, 40, -1)).toEqual({ score: { p1: 40, p2: 40 }, winner: -1 });
  });
});

describe("soloResult", () => {
  it("spells a one-player game's points the way the server reads every result, with nobody to beat", () => {
    expect(soloResult(4200)).toEqual({ score: { p1: 4200, p2: 0 }, winner: 0 });
  });
});

/** A guest's game: player two, writing down what the end does in order. */
function guest(state = {}) {
  const calls = [];
  return {
    calls,
    isHost: false,
    gameState: state,
    outcome(winner) {
      if (winner !== 1 && winner !== 2) return "draw";
      return winner === 2 ? "win" : "lose";
    },
    setKeyboardCaptured: (on) => calls.push(["capture", on]),
    invalidate: () => calls.push(["invalidate"]),
    audio: new Proxy({}, { get: (_t, name) => () => calls.push([name]) }),
  };
}

describe("drawOnDisconnect", () => {
  it("reports the score as it stood with nobody the winner", () => {
    const result = drawOnDisconnect((s) => [s.a, s.b])({ gameState: { a: 4, b: 2 } });
    expect(result).toEqual({ score: { p1: 4, p2: 2 }, winner: 0 });
  });
});

describe("playOutcome", () => {
  it("plays the win for this screen's side, the loss otherwise, a draw included", () => {
    const g = guest();
    playOutcome(g, 2);
    playOutcome(g, 1);
    playOutcome(g, 0, "playVictory", "playGameOver");
    expect(g.calls).toEqual([["playWin"], ["playLose"], ["playGameOver"]]);
  });
});

describe("guestEnd", () => {
  it("releases the keyboard, copies phase and fields, plays the sound, then repaints", () => {
    const g = guest({ phase: 1, score1: 0 });
    const sound = vi.fn((game) => game.calls.push(["sound"]));
    guestEnd({ phase: 9, fields: ["score1", "score2"], sound })(g, {
      score1: 3,
      score2: 5,
      winner: 2,
    });

    expect(g.gameState).toEqual({ phase: 9, score1: 3, score2: 5 });
    expect(g.calls).toEqual([["capture", false], ["sound"], ["invalidate"]]);
    expect(sound).toHaveBeenCalledWith(g, { score1: 3, score2: 5, winner: 2 });
  });

  it("skips the repaint when asked", () => {
    const g = guest({});
    guestEnd({ phase: 2, sound: () => {}, repaint: false })(g, {});
    expect(g.calls).toEqual([["capture", false]]);
  });
});
