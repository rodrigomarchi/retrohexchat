import { describe, expect, it } from "vitest";
import { EVENT, GAME_MODE, PHASE } from "../../../../js/lib/games/hex_hockey/protocol.js";
import {
  GOALIE_H,
  RINK_BOTTOM,
  RINK_CY,
  createInitialState,
  getGoalieXPositions,
  goalEndsMatch,
  puckCrossingY,
  stepTick,
  updateGoalie,
} from "../../../../js/lib/games/hex_hockey/physics.js";

const idle = { left: false, right: false, up: false, down: false, action: false };
const playing = (mode = GAME_MODE.CLASSIC) => ({
  ...createInitialState(mode),
  phase: PHASE.PLAYING,
});

describe("the goalie", () => {
  it("reads where a loose puck will cross its line, off the boards on the way", () => {
    const loose = { x: 100, y: 255, vx: -2, vy: 1, possessedBy: 0 };
    expect(puckCrossingY(loose, 50)).toBeCloseTo(280);
    // A puck heading off the bottom board comes back up.
    const steep = { x: 300, y: RINK_BOTTOM - 20, vx: -2, vy: 2, possessedBy: 0 };
    expect(puckCrossingY(steep, 50)).toBeLessThan(RINK_BOTTOM);
    // Held, still, or moving away: nothing to read.
    expect(puckCrossingY({ ...loose, possessedBy: 1 }, 50)).toBeNull();
    expect(puckCrossingY({ ...loose, vx: 0 }, 50)).toBeNull();
    expect(puckCrossingY({ ...loose, vx: 2 }, 50)).toBeNull();
  });

  it("skates for where a shot will cross, not where the puck is", () => {
    const state = playing();
    const { g1x } = getGoalieXPositions(state);
    state.g1.y = RINK_CY;
    // A shot from above the goal, angled down across it.
    state.puck = { x: g1x + 60, y: RINK_CY - 40, vx: -3, vy: 3, possessedBy: 0 };
    const before = state.g1.y;
    updateGoalie(state, true);
    expect(state.g1.y).toBeGreaterThan(before);
  });

  it("closes the angle on a carried puck: between it and the middle of its goal", () => {
    const state = playing();
    state.g1.y = RINK_CY;
    state.puck = { x: 200, y: RINK_CY - 120, vx: 0, vy: 0, possessedBy: 2 };
    for (let frame = 0; frame < 200; frame++) updateGoalie(state, true);
    expect(state.g1.y).toBeLessThan(RINK_CY);
    expect(state.g1.y).toBeGreaterThan(RINK_CY - 120);
  });

  it("stands tall enough to cover a fifth of its goal", () => {
    expect(GOALIE_H).toBe(20);
  });
});

describe("the end of a match", () => {
  it("comes with any goal of sudden death, which the next goal decides", () => {
    const sudden = { ...playing(), period: 4, scoreP1: 3, scoreP2: 2 };
    expect(goalEndsMatch(sudden)).toBe(true);
    expect(goalEndsMatch({ ...playing(GAME_MODE.BLITZ), period: 2, scoreP1: 1 })).toBe(true);
  });

  it("does not come with a goal in regular time", () => {
    expect(goalEndsMatch({ ...playing(), period: 3, scoreP1: 3, scoreP2: 2 })).toBe(false);
  });

  it("comes in a Showdown at its target, and not before", () => {
    const showdown = playing(GAME_MODE.SHOWDOWN);
    expect(goalEndsMatch({ ...showdown, scoreP1: 4 })).toBe(false);
    expect(goalEndsMatch({ ...showdown, scoreP2: 5 })).toBe(true);
  });
});

describe("a tackle", () => {
  // Whoever moved second in the frame would always be the closer chaser.
  it("is judged from where both stood as the frame began", () => {
    const state = playing();
    state.p1 = { ...state.p1, x: 300, y: 255, hasPuck: true, stunTimer: 0 };
    state.p2 = { ...state.p2, x: 319, y: 255, hasPuck: false, stunTimer: 0 };
    state.puck.possessedBy = 1;
    // The carrier skates away this very frame; the tackle still comes in.
    const tick = stepTick(
      state,
      { ...idle, left: true },
      { ...idle, action: true },
      { local: false, remote: false },
      () => 0,
    );
    expect(tick.handled.remote).toBe(true);
    expect(state.eventFlags & EVENT.TACKLE_SUCCESS).toBeTruthy();
  });
});
