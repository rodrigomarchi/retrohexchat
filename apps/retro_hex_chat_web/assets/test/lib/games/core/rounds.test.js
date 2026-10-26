import { describe, it, expect, vi } from "vitest";
import { createFlow } from "../../../../js/lib/games/core/flow.js";
import { roundsFlow, tallyRound } from "../../../../js/lib/games/core/rounds.js";

const PHASE = { WAITING: 0, COUNTDOWN: 1, SPAWNING: 2, FIGHTING: 3, ROUND_OVER: 4, MATCH_OVER: 5 };

/** A game the flow's hooks can act on, writing down what they do. */
function game() {
  const said = [];
  const g = {
    gameState: {
      phase: PHASE.WAITING,
      countdown: 0,
      roundWins1: 0,
      roundWins2: 0,
      score1: 0,
      score2: 0,
    },
    said,
    audio: new Proxy({}, { get: (_t, name) => () => said.push(name) }),
    broadcast: () => said.push(`broadcast ${g.gameState.phase}/${g.gameState.countdown}`),
    invalidate: vi.fn(),
    finish: vi.fn(),
  };
  return g;
}

function play(spec, g) {
  const flow = createFlow(spec, {
    readPhase: () => g.gameState.phase,
    writePhase: (v) => (g.gameState.phase = v),
    startSteps: () => {},
    stopSteps: () => {},
    idle: () => {},
    target: g,
  });
  return flow;
}

const steps = (flow, n) => {
  for (let i = 0; i < n; i++) flow.step();
};

function boxing(overrides = {}) {
  return roundsFlow({
    phases: PHASE,
    play: "FIGHTING",
    countdown: { from: 3, every: 2 },
    spawnTicks: 2,
    roundOverTicks: 3,
    bell: (g) => g.audio.playBell(),
    startRound: (g) => (g.gameState.roundTimer = 99),
    states: { FIGHTING: { tick: () => {} } },
    nextRound: (s) => ({ ...s, score1: 0, score2: 0 }),
    winner: (s) => (s.roundWins1 >= s.roundWins2 ? 1 : 2),
    ...overrides,
  });
}

describe("a match in rounds", () => {
  it("counts down aloud, rings the bell, then starts the round in its phase", () => {
    const g = game();
    const flow = play(boxing(), g);
    flow.go("COUNTDOWN");
    steps(flow, 6);
    expect(g.said).toEqual([
      "broadcast 1/3",
      "playCountdown",
      "broadcast 1/2",
      "playCountdown",
      "broadcast 1/1",
      "playCountdown",
      "broadcast 2/1",
      "playBell",
    ]);
    steps(flow, 2);
    expect(flow.name).toBe("FIGHTING");
    expect(g.gameState).toMatchObject({ phase: PHASE.FIGHTING, roundTimer: 99 });
    expect(g.said.at(-1)).toBe("broadcast 3/1");
  });

  it("pauses on a round's end, then sets up the next and counts down again", () => {
    const g = game();
    const flow = play(boxing(), g);
    flow.go("COUNTDOWN");
    steps(flow, 8);
    g.gameState = { ...g.gameState, phase: PHASE.ROUND_OVER, score1: 7 };
    steps(flow, 1);
    expect(flow.name).toBe("ROUND_OVER");
    steps(flow, 3);
    expect(flow.name).toBe("COUNTDOWN");
    expect(g.gameState.score1).toBe(0);
  });

  it("ends the match with the round count, the winner's sound and both reports", () => {
    const g = game();
    const flow = play(boxing(), g);
    flow.go("COUNTDOWN");
    g.gameState = {
      ...g.gameState,
      phase: PHASE.MATCH_OVER,
      roundWins1: 2,
      roundWins2: 1,
      score1: 40,
      score2: 12,
    };
    steps(flow, 1);
    expect(g.said).toContain("playWin");
    expect(g.finish).toHaveBeenCalledWith({
      end: { score1: 40, score2: 12, winner: 1, roundWins1: 2, roundWins2: 1 },
      result: { score: { p1: 2, p2: 1 }, winner: 1 },
    });
  });

  it("sounds the loss when the other side takes the match", () => {
    const g = game();
    const flow = play(boxing(), g);
    flow.go("COUNTDOWN");
    g.gameState = { ...g.gameState, phase: PHASE.MATCH_OVER, roundWins1: 0, roundWins2: 2 };
    steps(flow, 1);
    expect(g.said).toContain("playLose");
    expect(g.finish.mock.calls[0][0].result.winner).toBe(2);
  });

  it("keeps the game's other phases", () => {
    const spec = boxing({
      states: { FIGHTING: { tick: () => {} }, HIT_PAUSE: { tick: () => {} } },
    });
    expect(Object.keys(spec.states)).toEqual(
      expect.arrayContaining([
        "COUNTDOWN",
        "SPAWNING",
        "FIGHTING",
        "HIT_PAUSE",
        "ROUND_OVER",
        "MATCH_OVER",
      ]),
    );
    expect(spec).toMatchObject({ phases: PHASE, initial: "WAITING", begin: "COUNTDOWN" });
  });
});

describe("tallyRound", () => {
  it("counts the round for its winner and says when the match is won", () => {
    expect(tallyRound({ roundWins1: 0, roundWins2: 1 }, 1, 2)).toEqual({
      roundWins1: 1,
      roundWins2: 1,
      matchOver: false,
    });
    expect(tallyRound({ roundWins1: 1, roundWins2: 1 }, 2, 2)).toEqual({
      roundWins1: 1,
      roundWins2: 2,
      matchOver: true,
    });
  });

  it("counts a draw for nobody", () => {
    expect(tallyRound({ roundWins1: 1, roundWins2: 1 }, 0, 2)).toEqual({
      roundWins1: 1,
      roundWins2: 1,
      matchOver: false,
    });
  });
});
