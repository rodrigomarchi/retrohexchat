import { describe, expect, it, vi } from "vitest";
import {
  COUNTDOWN,
  beepCountdownState,
  closeRound,
  closeRoundStep,
  countdownState,
  endRoundStep,
  pointsReached,
  publishStep,
  roundsEnding,
} from "../../../../js/lib/games/core/rounds.js";

const PHASE = { WAITING: 0, COUNTDOWN: 1, PLAYING: 2, ROUND_OVER: 3, MATCH_OVER: 4 };

/** A game's surface as the round helpers use it, every call logged in order. */
function fakeGame(state = {}) {
  const log = [];
  const game = {
    gameState: state,
    particles: [1, 2],
    frameCount: 0,
    constructor: { FINAL_PHASE: PHASE.MATCH_OVER },
    broadcast: () => log.push("broadcast"),
    invalidate: () => log.push("invalidate"),
    setKeyboardCaptured: (on) => log.push(`capture ${on}`),
    audio: new Proxy({}, { get: (_t, name) => () => log.push(name) }),
    log,
  };
  return game;
}

describe("the countdowns", () => {
  it("count from COUNTDOWN unless told: three, a number a second", () => {
    expect(COUNTDOWN).toEqual({ from: 3, every: 60 });
    expect(countdownState({ next: "PLAYING" }).every).toEqual({ ticks: 60, count: 3 });
  });

  it("beepCountdownState shows each number, beeps as each second passes, and starts at zero", () => {
    const start = vi.fn();
    const state = beepCountdownState({ next: "PLAYING", start, capture: true });
    const game = fakeGame({ countdown: 0 });

    state.enter(game);
    expect(game.gameState.countdown).toBe(3);
    state.onEvery(game, 2);
    expect(game.gameState.countdown).toBe(2);
    state.onEvery(game, 0);

    expect(start).toHaveBeenCalledOnce();
    expect(game.gameState.countdown).toBe(2);
    expect(game.log).toEqual([
      "capture true",
      "broadcast",
      "invalidate",
      "playCountdown",
      "broadcast",
      "invalidate",
      "playCountdown",
    ]);
    expect(state.next).toBe("PLAYING");
  });
});

describe("a round's step", () => {
  it("publishStep settles the particles, keeps the state, repaints and sends", () => {
    const game = fakeGame();
    const next = { phase: PHASE.PLAYING };
    publishStep(game, next, (particles) => particles.slice(1));

    expect(game.particles).toEqual([2]);
    expect(game.gameState).toBe(next);
    expect(game.frameCount).toBe(1);
    expect(game.log).toEqual(["invalidate", "broadcast"]);
  });

  it("endRoundStep sends a round's end, but not the match's, which reports itself", () => {
    const game = fakeGame();
    endRoundStep(game, { phase: PHASE.ROUND_OVER });
    endRoundStep(game, { phase: PHASE.MATCH_OVER });
    expect(game.gameState.phase).toBe(PHASE.MATCH_OVER);
    expect(game.log).toEqual(["broadcast"]);
  });

  it("closeRoundStep ticks the last fifteen seconds aloud and ends a round that is over", () => {
    const rules = {
      checkRoundEnd: (s) => ({ ended: s.over, roundWinner: 1 }),
      advanceRound: (s, winner) => ({ ...s, phase: PHASE.ROUND_OVER, winner }),
      sound: vi.fn(),
    };
    const ticking = fakeGame();
    expect(closeRoundStep(ticking, { roundTimer: 900, over: false }, rules)).toBe(false);
    expect(closeRoundStep(ticking, { roundTimer: 901, over: false }, rules)).toBe(false);
    expect(ticking.log).toEqual(["playTimerTick"]);

    const ending = fakeGame();
    expect(closeRoundStep(ending, { roundTimer: 10, over: true }, rules)).toBe(true);
    expect(rules.sound).toHaveBeenCalledWith(ending.gameState);
    expect(ending.gameState).toMatchObject({ phase: PHASE.ROUND_OVER, winner: 1 });
  });
});

describe("a round's end", () => {
  it("pointsReached ends the round for the side at the target, player one first", () => {
    expect(pointsReached({ score1: 5, score2: 5 }, 5)).toEqual({ ended: true, roundWinner: 1 });
    expect(pointsReached({ score1: 2, score2: 5 }, 5)).toEqual({ ended: true, roundWinner: 2 });
    expect(pointsReached({ score1: 4, score2: 4 }, 5)).toEqual({ ended: false, roundWinner: 0 });
  });

  it("closeRound tallies the round and ends the match once a side has the rounds", () => {
    const state = { roundWins1: 1, roundWins2: 0, phase: PHASE.PLAYING };
    expect(closeRound(state, 2, 2, PHASE)).toMatchObject({
      roundWins2: 1,
      phase: PHASE.ROUND_OVER,
    });
    expect(closeRound(state, 1, 2, PHASE)).toMatchObject({
      roundWins1: 2,
      phase: PHASE.MATCH_OVER,
    });
  });

  it("roundsEnding reads the rounds each side took, on the guest and on a dropped channel", () => {
    const { onEnd, disconnectResult } = roundsEnding(PHASE);
    const game = fakeGame({ roundWins1: 0, roundWins2: 0 });
    game.outcome = () => "win";
    onEnd(game, { winner: 1, roundWins1: 2, roundWins2: 1 });

    expect(game.gameState).toMatchObject({ phase: PHASE.MATCH_OVER, roundWins1: 2 });
    expect(game.log).toContain("playWin");
    expect(disconnectResult(game)).toEqual({ score: { p1: 2, p2: 1 }, winner: 0 });
  });
});
