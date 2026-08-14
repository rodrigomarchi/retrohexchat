import { describe, it, expect, vi } from "vitest";
import { PHASE, GAME_MODE } from "../../../../js/lib/games/hex_hockey/protocol.js";
import {
  RINK_CX,
  RINK_CY,
  GOAL_TOP,
  createInitialState,
} from "../../../../js/lib/games/hex_hockey/physics.js";
import {
  attackingGoalCenter,
  chooseHockeyTarget,
  createHockeyAI,
  defensiveHomePosition,
  movementInputs,
  normalizeHockeyAIDifficulty,
  shouldShoot,
} from "../../../../js/lib/games/hex_hockey/ai.js";

describe("hex_hockey_ai", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeHockeyAIDifficulty("easy")).toBe("easy");
    expect(normalizeHockeyAIDifficulty("HARD")).toBe("hard");
    expect(normalizeHockeyAIDifficulty("unknown")).toBe("normal");
    expect(normalizeHockeyAIDifficulty(null)).toBe("normal");
  });

  it("lets difficulty be updated after creation", () => {
    const ai = createHockeyAI({ difficulty: "easy" });
    ai.setDifficulty("hard");
    expect(ai.difficulty).toBe("hard");
  });

  it("returns neutral inputs outside active play phases", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0 });

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      left: false,
      right: false,
      up: false,
      down: false,
      action: false,
    });
  });

  it("attacks the left goal for player 2 on default sides", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.p2.x = RINK_CX + 200;
    state.p2.y = RINK_CY;
    state.p2.facing = 4;
    state.p2.hasPuck = true;
    state.puck.possessedBy = 2;
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0 });

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(attackingGoalCenter(state, 2).x).toBeLessThan(RINK_CX);
    expect(inputs.left).toBe(true);
    expect(inputs.action).toBe(true);
  });

  it("attacks the right goal for player 2 when sides are swapped", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.sidesSwapped = true;

    expect(attackingGoalCenter(state, 2).x).toBeGreaterThan(RINK_CX);
  });

  it("chases a free puck in open ice", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.p2.x = RINK_CX + 180;
    state.p2.y = RINK_CY;
    state.puck.x = RINK_CX + 70;
    state.puck.y = RINK_CY + 24;
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0.5 });

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(inputs.left).toBe(true);
    expect(inputs.down).toBe(true);
    expect(inputs.action).toBe(false);
  });

  it("falls back to defense when the puck is headed at its goal", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.puck.x = RINK_CX + 210;
    state.puck.y = GOAL_TOP + 10;
    state.puck.vx = 4;

    const target = chooseHockeyTarget(state, 2);
    const home = defensiveHomePosition(state, 2);

    expect(target.kind).toBe("defend");
    expect(home.x).toBeGreaterThan(RINK_CX);
    expect(target.y).toBeGreaterThanOrEqual(GOAL_TOP);
  });

  it("presses action to tackle a nearby puck carrier", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.p1.x = state.p2.x - 10;
    state.p1.y = state.p2.y;
    state.p1.hasPuck = true;
    state.puck.possessedBy = 1;
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0 });

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(inputs.action).toBe(true);
  });

  it("does not repeat action while cooldown is active", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.p2.x = RINK_CX + 190;
    state.p2.y = RINK_CY;
    state.p2.facing = 4;
    state.p2.hasPuck = true;
    state.puck.possessedBy = 2;
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0 });

    expect(ai.nextInputs({ state, player: 2 }).action).toBe(true);
    expect(ai.nextInputs({ state, player: 2 }).action).toBe(false);
  });

  it("supports sudden death as an active phase", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.SUDDEN_DEATH;
    state.puck.x = state.p2.x - 30;
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0.5 });

    expect(ai.nextInputs({ state, player: 2 }).left).toBe(true);
  });

  it("maps movement toward a target without mutating state", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    const before = { x: state.p2.x, y: state.p2.y };

    const inputs = movementInputs(state, 2, { x: state.p2.x - 20, y: state.p2.y - 20 }, 4);

    expect(inputs.left).toBe(true);
    expect(inputs.up).toBe(true);
    expect(state.p2).toEqual(expect.objectContaining(before));
  });

  it("requires puck possession and goal-facing direction before shooting", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.p2.hasPuck = true;
    state.puck.possessedBy = 2;
    state.p2.facing = 0;

    expect(shouldShoot(state, 2)).toBe(false);

    state.p2.facing = 4;
    expect(shouldShoot(state, 2)).toBe(true);
  });

  it("uses the configured rng for probabilistic actions", () => {
    const rng = vi.fn(() => 1);
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.p2.hasPuck = true;
    state.puck.possessedBy = 2;
    state.p2.facing = 4;
    const ai = createHockeyAI({ difficulty: "easy", rng });

    expect(ai.nextInputs({ state, player: 2 }).action).toBe(false);
    expect(rng).toHaveBeenCalled();
  });
});
