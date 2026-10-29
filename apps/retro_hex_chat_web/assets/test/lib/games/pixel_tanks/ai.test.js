import { describe, expect, it, vi } from "vitest";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/pixel_tanks/protocol.js";
import {
  GRID_COLS,
  GRID_ROWS,
  WALL_SIZE,
  createInitialState,
  decodeMaze,
} from "../../../../js/lib/games/pixel_tanks/physics.js";
import {
  PIXEL_TANKS_AI_DIFFICULTIES,
  chooseTankTarget,
  createPixelTanksAI,
  incomingMissileThreat,
  lineOfSightClear,
  normalizePixelTanksAIDifficulty,
  shouldFire,
  tankMovementInputs,
} from "../../../../js/lib/games/pixel_tanks/ai.js";
import { expectPassedOpeningWaits, scriptedRng } from "../../../support/games/ai_tests.js";
import { describeStrengthOrder } from "../../../support/games/strength_order.js";

function playingState() {
  const state = createInitialState(GAME_MODE.MAZE_BATTLE, 0);
  state.phase = PHASE.PLAYING;
  return state;
}

function openWalls() {
  return decodeMaze(0);
}

/** Player two at (500, 240) facing player one on the same line, 80 px off. */
function facingState(overrides = {}) {
  return {
    ...playingState(),
    tank1X: 420,
    tank1Y: 240,
    tank2X: 500,
    tank2Y: 240,
    tank2Rot: Math.PI,
    ...overrides,
  };
}

/** Player two mid-field with player one's shell 70 px off and flying at it. */
function shellIncoming(overrides = {}) {
  return facingState({
    tank1X: 48,
    tank2X: 320,
    m1Active: true,
    m1X: 250,
    m1Y: 240,
    m1VX: 5,
    m1VY: 0,
    ...overrides,
  });
}

/** Player two's inputs for `state` on the open field. */
function look(ai, state) {
  return ai.nextInputs({ state, player: 2, walls: openWalls() });
}

function walledArena() {
  const walls = openWalls();
  for (let row = 8; row < GRID_ROWS - 8; row++) {
    walls[row * GRID_COLS + 20] = 1;
  }
  walls[12 * GRID_COLS + 20] = 0;
  return walls;
}

describe("PixelTanksAI", () => {
  it("normalizes invalid difficulties to normal", () => {
    expect(normalizePixelTanksAIDifficulty("easy")).toBe("easy");
    expect(normalizePixelTanksAIDifficulty("HARD")).toBe("hard");
    expect(normalizePixelTanksAIDifficulty("nightmare")).toBe("normal");
    expect(normalizePixelTanksAIDifficulty(null)).toBe("normal");
  });

  it("lets difficulty be updated after creation", () => {
    const ai = createPixelTanksAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

  it.each([
    ["outside the playing phase", () => createInitialState(GAME_MODE.MAZE_BATTLE, 0)],
    ["during respawn pause", () => ({ ...playingState(), respawnPause: 12 })],
  ])("returns neutral inputs %s", (_when, state) => {
    const ai = createPixelTanksAI({ difficulty: "hard", rng: () => 0.5 });

    expect(look(ai, state())).toEqual({
      rotateLeft: false,
      rotateRight: false,
      forward: false,
      fire: false,
    });
  });

  it("chooses a direct attack target when the opponent is visible", () => {
    const state = facingState();

    const target = chooseTankTarget(state, 2, openWalls(), PIXEL_TANKS_AI_DIFFICULTIES.hard);

    expect(target.kind).toBe("attack");
    expect(target.angle).toBeCloseTo(Math.PI, 5);
  });

  it("navigates around walls when a direct shot is blocked", () => {
    const state = playingState();
    state.tank1X = 48;
    state.tank1Y = 240;
    state.tank2X = 592;
    state.tank2Y = 240;

    const target = chooseTankTarget(state, 2, walledArena(), PIXEL_TANKS_AI_DIFFICULTIES.normal);

    expect(target.kind).toBe("navigate");
    expect(target.advance).toBe(true);
  });

  it("detects blocked and clear sight lines", () => {
    const walls = openWalls();
    walls[15 * GRID_COLS + 20] = 1;

    expect(lineOfSightClear(100, 15 * WALL_SIZE + 8, 500, 15 * WALL_SIZE + 8, walls)).toBe(false);
    expect(lineOfSightClear(100, 80, 500, 80, walls)).toBe(true);
  });

  it("detects incoming enemy missiles and selects an evasion angle", () => {
    const state = shellIncoming();

    const threat = incomingMissileThreat(state, 2, PIXEL_TANKS_AI_DIFFICULTIES.hard);

    expect(threat).not.toBeNull();
    expect(threat.evadeAngle).toBeCloseTo((Math.PI * 3) / 2, 5);
  });

  it("ignores missiles moving away from the tank", () => {
    const state = shellIncoming({ m1VX: -5 });

    expect(incomingMissileThreat(state, 2, PIXEL_TANKS_AI_DIFFICULTIES.hard)).toBeNull();
  });

  it("maps signed rotation to held inputs", () => {
    expect(tankMovementInputs(Math.PI, { angle: Math.PI / 2, advance: true }).rotateLeft).toBe(
      true,
    );
    expect(tankMovementInputs(0, { angle: Math.PI / 2, advance: true }).rotateRight).toBe(true);
    expect(tankMovementInputs(Math.PI, { angle: Math.PI, advance: true }).forward).toBe(true);
  });

  it("fires only when aligned, visible, and off cooldown", () => {
    const opensFire = (state) =>
      shouldFire(
        state,
        2,
        { angle: Math.PI, distance: 80 },
        PIXEL_TANKS_AI_DIFFICULTIES.hard,
        0,
        () => 0,
        {
          walls: openWalls(),
        },
      );

    expect(opensFire(facingState())).toBe(true);
    expect(opensFire(facingState({ tank2Rot: Math.PI / 2 }))).toBe(false);
  });

  it("does not fire through walls", () => {
    const state = facingState({ tank1X: 100 });

    expect(
      shouldFire(
        state,
        2,
        { angle: Math.PI, distance: 400 },
        PIXEL_TANKS_AI_DIFFICULTIES.hard,
        0,
        () => 0,
        { walls: walledArena() },
      ),
    ).toBe(false);
  });

  it("emits a one-frame fire press through the controller cooldown", () => {
    const ai = createPixelTanksAI({ difficulty: "hard", rng: () => 0.5 });
    const state = facingState();

    const first = look(ai, state);
    const second = look(ai, state);

    expect(first.fire).toBe(true);
    expect(second.fire).toBe(false);
  });

  it("uses the configured rng for aim error and fire odds", () => {
    const rng = vi.fn(() => 0.5);
    const ai = createPixelTanksAI({ difficulty: "hard", rng });
    const state = facingState();

    look(ai, state);

    expect(rng).toHaveBeenCalled();
  });

  it("keeps one aim error for a shot instead of drawing a fresh one each look", () => {
    const draws = [0.999, 0.001];
    let next = 0;
    const ai = createPixelTanksAI({ difficulty: "hard", rng: () => draws[next++ % 2] });
    const state = facingState({ tank1X: 300, tank1Invuln: true });

    const turns = Array.from({ length: 12 }, () => look(ai, state).rotateRight);

    expect(turns.every((right) => right)).toBe(true);
    expect(next).toBe(1);
  });

  it("rolls the fire odds once per opening and waits out the cooldown after passing", () => {
    const ai = createPixelTanksAI({ difficulty: "normal", rng: scriptedRng([0.5, 0.99], 0.5) });
    const state = facingState({ tank1X: 300 });

    expectPassedOpeningWaits(
      () => look(ai, state).fire,
      PIXEL_TANKS_AI_DIFFICULTIES.normal.fireCooldownFrames,
    );
  });

  it("dodges a shell only once it is reactionFrames old", () => {
    const ai = createPixelTanksAI({ difficulty: "hard", rng: () => 0 });
    const state = shellIncoming();

    expect(look(ai, { ...state, m1Age: 0 }).rotateRight).toBe(false);
    for (let age = 1; age < 20; age++) look(ai, { ...state, m1Age: age });
    expect(look(ai, { ...state, m1Age: 20 }).rotateRight).toBe(true);
  });

  it("decides once per shell whether to dodge it", () => {
    const ai = createPixelTanksAI({ difficulty: "hard", rng: scriptedRng([0.99, 0.5], 0) });
    const state = shellIncoming({ tank1Invuln: true });

    for (let age = 0; age < 30; age++) {
      expect(look(ai, { ...state, m1Age: age }).rotateRight).toBe(false);
    }
  });
});

describe("PixelTanksAI between rounds", () => {
  it("lets go of its target and draws a fresh aim once a new round starts", () => {
    const rng = vi.fn(() => 0.5);
    const ai = createPixelTanksAI({ difficulty: "hard", rng });
    const state = facingState({ tank1Invuln: true });

    look(ai, state);
    look(ai, state);
    expect(rng).toHaveBeenCalledTimes(1);

    ai.forget();
    look(ai, state);
    expect(rng).toHaveBeenCalledTimes(2);
  });
});

describeStrengthOrder("Pixel Tanks", PIXEL_TANKS_AI_DIFFICULTIES, {
  decisionInterval: "down",
  aimErrorAngle: "down",
  turnDeadzone: "down",
  moveAngle: "up",
  aimTolerance: "down",
  standoffDistance: "down",
  fireMaxDistance: "up",
  fireCooldownFrames: "down",
  fireChance: "up",
  dodgeChance: "up",
  reactionFrames: "down",
  threatFrames: "up",
  threatRadius: "up",
  threatMargin: "up",
});
