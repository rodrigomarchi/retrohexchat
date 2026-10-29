import { describe, it, expect, vi } from "vitest";
import { PHASE, GAME_MODE } from "../../../../js/lib/games/hex_hockey/protocol.js";
import {
  RINK_CX,
  RINK_CY,
  GOAL_TOP,
  GOAL_LINE_LEFT,
  createInitialState,
} from "../../../../js/lib/games/hex_hockey/physics.js";
import {
  angleShotSpot,
  attackingGoalCenter,
  HOCKEY_AI_DIFFICULTIES,
  chooseHockeyTarget,
  createHockeyAI,
  defensiveHomePosition,
  movementInputs,
  normalizeHockeyAIDifficulty,
  shouldShoot,
} from "../../../../js/lib/games/hex_hockey/ai.js";
import { released } from "../../../support/games/physics_tests.js";

/** Player two holds the puck in the goal lane, within shooting range, facing the goal. */
function carrierInGoalLane() {
  const state = createInitialState(GAME_MODE.CLASSIC);
  state.phase = PHASE.PLAYING;
  state.p2.x = GOAL_LINE_LEFT + 120;
  state.p2.y = RINK_CY;
  state.p2.facing = 4;
  state.p2.hasPuck = true;
  state.puck.possessedBy = 2;
  return state;
}

/** The AI skates down and to the left this frame, without pressing action. */
function expectSkatesDownLeft(ai, state) {
  expect(ai.nextInputs({ state, player: 2 })).toMatchObject({
    left: true,
    down: true,
    action: false,
  });
}

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

    expect(ai.nextInputs({ state, player: 2 })).toEqual(
      released("left", "right", "up", "down", "action"),
    );
  });

  it("attacks the left goal for player 2 on default sides", () => {
    const state = carrierInGoalLane();
    // 0.99: no angled shot this possession, so it takes the goal lane
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0.99 });

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

    expectSkatesDownLeft(ai, state);
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

  /** Player one holds the puck 10 px from player two, both standing still. */
  function carrierInReach() {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.p1.x = state.p2.x - 10;
    state.p1.y = state.p2.y;
    state.p1.hasPuck = true;
    state.puck.possessedBy = 1;
    return state;
  }

  it("presses action to tackle a nearby puck carrier after its reaction delay", () => {
    const state = carrierInReach();
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0 });
    const { tackleDelayFrames } = HOCKEY_AI_DIFFICULTIES.hard;

    for (let frame = 0; frame < tackleDelayFrames; frame++) {
      expect(ai.nextInputs({ state, player: 2 }).action).toBe(false);
    }
    expect(ai.nextInputs({ state, player: 2 }).action).toBe(true);
  });

  it("decides once per contact whether to tackle", () => {
    const state = carrierInReach();
    let draw = 0.99;
    const ai = createHockeyAI({ difficulty: "hard", rng: () => draw });

    const holdsBack = () => {
      for (let frame = 0; frame < 30; frame++) {
        expect(ai.nextInputs({ state, player: 2 }).action).toBe(false);
      }
    };

    holdsBack();
    // Later draws would say yes, but this contact was already decided
    draw = 0;
    holdsBack();

    state.p1.x = state.p2.x - 100;
    ai.nextInputs({ state, player: 2 });
    state.p1.x = state.p2.x - 10;
    const pressed = Array.from({ length: 10 }, () => ai.nextInputs({ state, player: 2 }).action);
    expect(pressed).toContain(true);
  });

  it("does not repeat action while cooldown is active", () => {
    const state = carrierInGoalLane();
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0.99 });

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
    state.p2.x = GOAL_LINE_LEFT + 120;
    state.p2.hasPuck = true;
    state.puck.possessedBy = 2;
    state.p2.facing = 0;

    expect(shouldShoot(state, 2)).toBe(false);

    state.p2.facing = 4;
    expect(shouldShoot(state, 2)).toBe(true);
  });

  it("does not shoot from beyond its range", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.p2.x = GOAL_LINE_LEFT + 200;
    state.p2.facing = 4;
    state.p2.hasPuck = true;
    state.puck.possessedBy = 2;

    expect(shouldShoot(state, 2, 150)).toBe(false);
    expect(shouldShoot(state, 2, 250)).toBe(true);
  });

  it("aims an angled shot along a diagonal that crosses the goal line mid-goal", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    for (const side of [-1, 1]) {
      const spot = angleShotSpot(state, 2, side);
      const steps = (spot.x - GOAL_LINE_LEFT) / 1;
      const dy = spot.facing === 3 ? 1 : -1;

      expect([3, 5]).toContain(spot.facing);
      expect(spot.y + dy * steps).toBeCloseTo(RINK_CY);
    }
  });

  it("skates to its angled-shot spot and shoots from there facing the goal", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.p2.hasPuck = true;
    state.puck.possessedBy = 2;
    // 0: an angled shot this possession, from above the goal (the side draw is 0 < 0.5)
    const ai = createHockeyAI({ difficulty: "hard", rng: () => 0 });
    const spot = angleShotSpot(state, 2, -1);
    state.p2.x = spot.x;
    state.p2.y = spot.y;
    state.p2.facing = 4;

    expectSkatesDownLeft(ai, state);
    state.p2.facing = spot.facing;
    expect(ai.nextInputs({ state, player: 2 }).action).toBe(true);
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

  it("decides once per line-up whether to shoot, and afresh after forgetting", () => {
    const state = carrierInGoalLane();
    let draw = 0.99;
    const ai = createHockeyAI({ difficulty: "easy", rng: () => draw });

    for (let frame = 0; frame < 10; frame++) {
      expect(ai.nextInputs({ state, player: 2 }).action).toBe(false);
    }
    // Later draws would say shoot, but this line-up was already decided
    draw = 0;
    expect(ai.nextInputs({ state, player: 2 }).action).toBe(false);

    // A fresh possession plan: no angled shot (draw not under angleShotChance), then a shot
    draw = HOCKEY_AI_DIFFICULTIES.easy.shootChance;
    expect(draw).toBeGreaterThanOrEqual(HOCKEY_AI_DIFFICULTIES.easy.angleShotChance);
    ai.forget();
    expect(ai.nextInputs({ state, player: 2 }).action).toBe(true);
  });

  it("keeps one steering error for a target while the puck stays put", () => {
    const state = createInitialState(GAME_MODE.CLASSIC);
    state.phase = PHASE.PLAYING;
    state.puck.x = RINK_CX + 70;
    state.puck.y = RINK_CY + 24;
    let draw = 0.9;
    const ai = createHockeyAI({ difficulty: "hard", rng: () => draw });

    ai.nextInputs({ state, player: 2 });
    const target = { ...ai._target };
    draw = 0.1;
    for (let frame = 0; frame < 5; frame++) {
      ai.nextInputs({ state, player: 2 });
      expect(ai._target).toMatchObject({ x: target.x, y: target.y });
    }
  });
});
