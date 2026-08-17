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
  rotationDelta,
  shouldFire,
  tankMovementInputs,
} from "../../../../js/lib/games/pixel_tanks/ai.js";

function playingState() {
  const state = createInitialState(GAME_MODE.MAZE_BATTLE, 0);
  state.phase = PHASE.PLAYING;
  return state;
}

function openWalls() {
  return decodeMaze(0);
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

  it("returns neutral inputs outside the playing phase", () => {
    const ai = createPixelTanksAI({ difficulty: "hard", rng: () => 0.5 });
    const state = createInitialState(GAME_MODE.MAZE_BATTLE, 0);

    expect(ai.nextInputs({ state, player: 2, walls: openWalls() })).toEqual({
      rotateLeft: false,
      rotateRight: false,
      forward: false,
      fire: false,
    });
  });

  it("returns neutral inputs during respawn pause", () => {
    const ai = createPixelTanksAI({ difficulty: "hard", rng: () => 0.5 });
    const state = playingState();
    state.respawnPause = 12;

    expect(ai.nextInputs({ state, player: 2, walls: openWalls() })).toEqual({
      rotateLeft: false,
      rotateRight: false,
      forward: false,
      fire: false,
    });
  });

  it("chooses a direct attack target when the opponent is visible", () => {
    const state = playingState();
    state.tank1X = 420;
    state.tank1Y = 240;
    state.tank2X = 500;
    state.tank2Y = 240;

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
    const state = playingState();
    state.tank2X = 320;
    state.tank2Y = 240;
    state.m1Active = true;
    state.m1X = 250;
    state.m1Y = 240;
    state.m1VX = 5;
    state.m1VY = 0;

    const threat = incomingMissileThreat(state, 2, PIXEL_TANKS_AI_DIFFICULTIES.hard);

    expect(threat).not.toBeNull();
    expect(threat.evadeAngle).toBeCloseTo((Math.PI * 3) / 2, 5);
  });

  it("ignores missiles moving away from the tank", () => {
    const state = playingState();
    state.tank2X = 320;
    state.tank2Y = 240;
    state.m1Active = true;
    state.m1X = 250;
    state.m1Y = 240;
    state.m1VX = -5;
    state.m1VY = 0;

    expect(incomingMissileThreat(state, 2, PIXEL_TANKS_AI_DIFFICULTIES.hard)).toBeNull();
  });

  it("maps signed rotation to held inputs", () => {
    expect(tankMovementInputs(Math.PI, { angle: Math.PI / 2, advance: true }).rotateLeft).toBe(
      true,
    );
    expect(tankMovementInputs(0, { angle: Math.PI / 2, advance: true }).rotateRight).toBe(true);
    expect(tankMovementInputs(Math.PI, { angle: Math.PI, advance: true }).forward).toBe(true);
  });

  it("computes the shortest signed rotation delta", () => {
    expect(rotationDelta(0.05, Math.PI * 2 - 0.05)).toBeLessThan(0);
    expect(rotationDelta(Math.PI * 2 - 0.05, 0.05)).toBeGreaterThan(0);
  });

  it("fires only when aligned, visible, and off cooldown", () => {
    const state = playingState();
    state.tank1X = 420;
    state.tank1Y = 240;
    state.tank2X = 500;
    state.tank2Y = 240;
    state.tank2Rot = Math.PI;

    expect(
      shouldFire(
        state,
        2,
        { angle: Math.PI, distance: 80 },
        PIXEL_TANKS_AI_DIFFICULTIES.hard,
        0,
        () => 0,
        { walls: openWalls() },
      ),
    ).toBe(true);

    state.tank2Rot = Math.PI / 2;
    expect(
      shouldFire(
        state,
        2,
        { angle: Math.PI, distance: 80 },
        PIXEL_TANKS_AI_DIFFICULTIES.hard,
        0,
        () => 0,
        { walls: openWalls() },
      ),
    ).toBe(false);
  });

  it("does not fire through walls", () => {
    const state = playingState();
    state.tank1X = 100;
    state.tank1Y = 240;
    state.tank2X = 500;
    state.tank2Y = 240;
    state.tank2Rot = Math.PI;

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
    const state = playingState();
    state.tank1X = 420;
    state.tank1Y = 240;
    state.tank2X = 500;
    state.tank2Y = 240;
    state.tank2Rot = Math.PI;

    const first = ai.nextInputs({ state, player: 2, walls: openWalls() });
    const second = ai.nextInputs({ state, player: 2, walls: openWalls() });

    expect(first.fire).toBe(true);
    expect(second.fire).toBe(false);
  });

  it("uses the configured rng for aim error and fire odds", () => {
    const rng = vi.fn(() => 0.5);
    const ai = createPixelTanksAI({ difficulty: "hard", rng });
    const state = playingState();
    state.tank1X = 420;
    state.tank1Y = 240;
    state.tank2X = 500;
    state.tank2Y = 240;
    state.tank2Rot = Math.PI;

    ai.nextInputs({ state, player: 2, walls: openWalls() });

    expect(rng).toHaveBeenCalled();
  });
});
