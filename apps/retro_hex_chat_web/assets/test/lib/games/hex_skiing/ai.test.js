import { describe, it, expect } from "vitest";
import {
  SKIING_AI_DIFFICULTIES,
  chooseSkiingTarget,
  createHexSkiingAI,
  movementInputs,
  nearestBoostItem,
  nearestGate,
  normalizeSkiingAIDifficulty,
  pathRisk,
  VIEW_AHEAD,
} from "../../../../js/lib/games/hex_skiing/ai.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_skiing/protocol.js";
import {
  CANVAS_W,
  SKIER_SCREEN_Y,
  SKIER_W,
  createInitialState,
} from "../../../../js/lib/games/hex_skiing/physics.js";
import { itSetsDifficulty } from "../../../support/games/ai_tests.js";
import { describeStrengthOrder } from "../../../support/games/strength_order.js";

function racingState(mode = GAME_MODE.ALPINE_RACE) {
  return {
    ...createInitialState(mode, 12345),
    phase: PHASE.RACING,
  };
}

function skierY(state) {
  return state.scrollY + SKIER_SCREEN_Y;
}

describe("HexSkiingAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeSkiingAIDifficulty("easy")).toBe("easy");
    expect(normalizeSkiingAIDifficulty("HARD")).toBe("hard");
    expect(normalizeSkiingAIDifficulty("legendary")).toBe("normal");
    expect(normalizeSkiingAIDifficulty(null)).toBe("normal");
  });

  itSetsDifficulty(createHexSkiingAI);

  it("returns neutral inputs outside racing phase", () => {
    const ai = createHexSkiingAI({ difficulty: "hard", rng: () => 0.5 });

    expect(ai.nextInputs({ state: createInitialState(GAME_MODE.ALPINE_RACE, 12345) })).toEqual({
      left: false,
      right: false,
    });
  });

  it("targets the nearest uncleared slalom gate", () => {
    const state = racingState();
    const gate = {
      x: 240,
      y: skierY(state) + 60,
      width: 80,
      clearedP1: false,
      clearedP2: false,
    };
    state.gates = [gate];
    state.obstacles = [];

    expect(nearestGate(state, 2, SKIING_AI_DIFFICULTIES.hard)).toBe(gate);
    expect(chooseSkiingTarget(state, 2, SKIING_AI_DIFFICULTIES.hard)).toMatchObject({
      reason: "gate",
    });
    expect(chooseSkiingTarget(state, 2, SKIING_AI_DIFFICULTIES.hard).x).toBeGreaterThan(250);
    expect(chooseSkiingTarget(state, 2, SKIING_AI_DIFFICULTIES.hard).x).toBeLessThan(330);
  });

  it("ignores gates already cleared by the AI player", () => {
    const state = racingState();
    state.gates = [
      { x: 180, y: skierY(state) + 40, width: 70, clearedP1: false, clearedP2: true },
      { x: 360, y: skierY(state) + 80, width: 70, clearedP1: false, clearedP2: false },
    ];

    expect(nearestGate(state, 2, SKIING_AI_DIFFICULTIES.hard)).toMatchObject({ x: 360 });
  });

  it("chooses a boost item when no gate is urgent", () => {
    const state = racingState();
    state.gates = [];
    state.items = [{ type: 0, x: 220, y: skierY(state) + 80, collected: 0 }];
    state.obstacles = [];

    expect(nearestBoostItem(state, SKIING_AI_DIFFICULTIES.hard)).toMatchObject({ x: 220 });
    expect(chooseSkiingTarget(state, 2, SKIING_AI_DIFFICULTIES.hard)).toMatchObject({
      reason: "boost",
    });
  });

  it("ignores boost items in clean run mode", () => {
    const state = racingState(GAME_MODE.CLEAN_RUN);
    state.items = [{ type: 0, x: 220, y: skierY(state) + 80, collected: 0 }];

    expect(nearestBoostItem(state, SKIING_AI_DIFFICULTIES.hard)).toBeNull();
  });

  it("avoids obstacles directly ahead", () => {
    const state = racingState();
    state.p2 = { ...state.p2, x: CANVAS_W / 2, velX: 0 };
    state.gates = [];
    state.items = [];
    state.obstacles = [{ type: "tree", x: CANVAS_W / 2, y: skierY(state) + 80, w: 10, h: 14 }];

    const risk = pathRisk(state, CANVAS_W / 2, 2, SKIING_AI_DIFFICULTIES.hard);
    const target = chooseSkiingTarget(state, 2, SKIING_AI_DIFFICULTIES.hard);

    expect(risk).toBeGreaterThan(10);
    expect(target.reason).toBe("avoid");
    // Clear of the tree's trunk and the skier's own width.
    expect(Math.abs(target.x - CANVAS_W / 2)).toBeGreaterThan(10 / 2 + SKIER_W / 2);
  });

  it("treats ice as lower risk than trees", () => {
    const treeState = racingState();
    treeState.obstacles = [{ type: "tree", x: 320, y: skierY(treeState) + 60, w: 10, h: 14 }];

    const iceState = racingState();
    iceState.obstacles = [{ type: "ice", x: 320, y: skierY(iceState) + 60, w: 24, h: 16 }];

    expect(pathRisk(treeState, 320, 2, SKIING_AI_DIFFICULTIES.normal)).toBeGreaterThan(
      pathRisk(iceState, 320, 2, SKIING_AI_DIFFICULTIES.normal),
    );
  });

  it("moves toward a left or right target", () => {
    const actor = { x: 320, velX: 0 };

    expect(movementInputs(actor, { x: 220 }, SKIING_AI_DIFFICULTIES.hard)).toEqual({
      left: true,
      right: false,
    });
    expect(movementInputs(actor, { x: 420 }, SKIING_AI_DIFFICULTIES.hard)).toEqual({
      left: false,
      right: true,
    });
  });

  it("holds neutral near the target deadzone", () => {
    const actor = { x: 320, velX: 0 };

    expect(movementInputs(actor, { x: 324 }, SKIING_AI_DIFFICULTIES.hard)).toEqual({
      left: false,
      right: false,
    });
  });

  it("uses the cached decision between difficulty ticks", () => {
    const ai = createHexSkiingAI({ difficulty: "easy", rng: () => 0.5 });
    const state = racingState();
    state.p2 = { ...state.p2, x: 360, velX: 0 };
    state.gates = [
      { x: 150, y: skierY(state) + 160, width: 80, clearedP1: false, clearedP2: false },
    ];
    state.obstacles = [];

    const first = ai.nextInputs({ state, player: 2 });
    state.gates = [
      { x: 430, y: skierY(state) + 160, width: 80, clearedP1: false, clearedP2: false },
    ];
    const second = ai.nextInputs({ state, player: 2 });

    expect(first).toEqual(second);
  });

  it("sees no further down the slope than the screen shows", () => {
    const state = racingState();
    state.p2 = { ...state.p2, x: CANVAS_W / 2, velX: 0 };
    state.gates = [
      { x: 60, y: skierY(state) + VIEW_AHEAD + 20, width: 80, clearedP1: false, clearedP2: false },
    ];
    state.items = [{ type: 0, x: 220, y: skierY(state) + VIEW_AHEAD + 20, collected: 0 }];
    state.obstacles = [
      { type: "tree", x: CANVAS_W / 2, y: skierY(state) + VIEW_AHEAD + 20, w: 10, h: 14 },
    ];
    const farSighted = {
      ...SKIING_AI_DIFFICULTIES.hard,
      obstacleLookAhead: 400,
      gateLookAhead: 400,
      itemLookAhead: 400,
    };

    expect(nearestGate(state, 2, farSighted)).toBeNull();
    expect(nearestBoostItem(state, farSighted)).toBeNull();
    expect(pathRisk(state, CANVAS_W / 2, 2, farSighted)).toBe(0);
  });

  it("steers by the slope as it was its reaction time ago", () => {
    const config = SKIING_AI_DIFFICULTIES.normal;
    const ai = createHexSkiingAI({ difficulty: "normal", rng: () => 0.75 });
    const gateAt = (x) => ({ x, y: 0, width: 80, clearedP1: false, clearedP2: false });
    const frame = (gateX) => {
      const state = racingState();
      state.p2 = { ...state.p2, x: CANVAS_W / 2, velX: 0 };
      state.obstacles = [];
      state.items = [];
      state.gates = [{ ...gateAt(gateX), y: skierY(state) + 60 }];
      return state;
    };

    // A gate far left, then — for as long as it takes to react — one far right.
    ai.nextInputs({ state: frame(40), player: 2 });
    const before = [];
    for (let i = 0; i < config.reaction; i++) {
      for (let j = 0; j < config.interval - 1; j++) ai.nextInputs({ state: frame(500), player: 2 });
      before.push(ai.nextInputs({ state: frame(500), player: 2 }));
    }

    expect(before[0]).toEqual({ left: true, right: false });
    expect(before.at(-1)).toEqual({ left: false, right: true });
  });

  it("keeps one aim error for the whole approach to a gate", () => {
    const draws = [0.9, 0.0, 0.1, 0.0];
    let next = 0;
    const ai = createHexSkiingAI({ difficulty: "easy", rng: () => draws[next++ % draws.length] });
    const config = SKIING_AI_DIFFICULTIES.easy;
    const state = racingState();
    state.p2 = { ...state.p2, x: 300, velX: 0 };
    state.obstacles = [];
    state.items = [];
    state.gates = [
      { x: 260, y: skierY(state) + 90, width: 80, clearedP1: false, clearedP2: false },
    ];

    const targets = [];
    for (let i = 0; i < config.interval * 3; i++) {
      ai.nextInputs({ state, player: 2 });
      targets.push(ai._target.x);
    }
    const ideal = chooseSkiingTarget(state, 2, config).x;

    expect(new Set(targets).size).toBe(1);
    expect(Math.abs(targets[0] - ideal)).toBeGreaterThan(config.aimError);
    expect(next).toBe(2);
  });

  describe("between rounds and while down", () => {
    /** A racing state with one gate 60 px ahead, its left post at `gateX`. */
    function gateFrame(gateX, p2 = {}) {
      const state = racingState();
      state.p2 = { ...state.p2, x: CANVAS_W / 2, velX: 0, ...p2 };
      state.obstacles = [];
      state.items = [];
      state.gates = [
        { x: gateX, y: skierY(state) + 60, width: 80, clearedP1: false, clearedP2: false },
      ];
      return state;
    }

    it("starts a new round with nothing seen of the last one's slope", () => {
      const ai = createHexSkiingAI({ difficulty: "normal", rng: () => 0.75 });
      for (let i = 0; i < 20; i++) ai.nextInputs({ state: gateFrame(40), player: 2 });

      ai.forget();

      expect(ai.nextInputs({ state: gateFrame(500), player: 2 })).toEqual({
        left: false,
        right: true,
      });
    });

    it("keeps watching the slope while stunned", () => {
      const { reaction, interval } = SKIING_AI_DIFFICULTIES.normal;
      const ai = createHexSkiingAI({ difficulty: "normal", rng: () => 0.75 });
      ai.nextInputs({ state: gateFrame(40), player: 2 });
      for (let i = 0; i < reaction + 1; i++) {
        ai.nextInputs({ state: gateFrame(500, { stunTimer: 5 }), player: 2 });
      }

      // Up on its skis again, its next look comes before `reaction` new
      // frames: only frames watched while down can show it the new gate.
      let frame = reaction + 2;
      let inputs;
      do {
        frame++;
        inputs = ai.nextInputs({ state: gateFrame(500), player: 2 });
      } while (frame % interval !== 0);

      expect(frame - (reaction + 2)).toBeLessThanOrEqual(reaction);
      expect(inputs).toEqual({ left: false, right: true });
    });
  });
});

describeStrengthOrder("hex_skiing", SKIING_AI_DIFFICULTIES, {
  interval: "down",
  reaction: "down",
  obstacleLookAhead: "up",
  gateLookAhead: "up",
  itemLookAhead: "up",
  safetyWidth: "up",
  candidateStep: "down",
  deadzone: "down",
  velocityLead: "up",
  aimError: "down",
  gatePadding: "up",
});
