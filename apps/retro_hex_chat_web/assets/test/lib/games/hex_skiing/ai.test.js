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
} from "../../../../js/lib/games/hex_skiing/ai.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_skiing/protocol.js";
import {
  CANVAS_W,
  SKIER_SCREEN_Y,
  createInitialState,
} from "../../../../js/lib/games/hex_skiing/physics.js";

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

  it("updates difficulty through the public setter", () => {
    const ai = createHexSkiingAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

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
      y: skierY(state) + 160,
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
      { x: 180, y: skierY(state) + 120, width: 70, clearedP1: false, clearedP2: true },
      { x: 360, y: skierY(state) + 180, width: 70, clearedP1: false, clearedP2: false },
    ];

    expect(nearestGate(state, 2, SKIING_AI_DIFFICULTIES.hard)).toMatchObject({ x: 360 });
  });

  it("chooses a boost item when no gate is urgent", () => {
    const state = racingState();
    state.gates = [];
    state.items = [{ type: 0, x: 220, y: skierY(state) + 180, collected: 0 }];
    state.obstacles = [];

    expect(nearestBoostItem(state, SKIING_AI_DIFFICULTIES.hard)).toMatchObject({ x: 220 });
    expect(chooseSkiingTarget(state, 2, SKIING_AI_DIFFICULTIES.hard)).toMatchObject({
      reason: "boost",
    });
  });

  it("ignores boost items in clean run mode", () => {
    const state = racingState(GAME_MODE.CLEAN_RUN);
    state.items = [{ type: 0, x: 220, y: skierY(state) + 180, collected: 0 }];

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
    expect(Math.abs(target.x - CANVAS_W / 2)).toBeGreaterThan(40);
  });

  it("treats ice as lower risk than trees", () => {
    const treeState = racingState();
    treeState.obstacles = [{ type: "tree", x: 320, y: skierY(treeState) + 120, w: 10, h: 14 }];

    const iceState = racingState();
    iceState.obstacles = [{ type: "ice", x: 320, y: skierY(iceState) + 120, w: 24, h: 16 }];

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
});
