import { describe, it, expect } from "vitest";
import {
  FROST_AI_DIFFICULTIES,
  chooseFrostTarget,
  createHexFrostAI,
  movementInputs,
  normalizeFrostAIDifficulty,
  pathRisk,
  selectTargetBlock,
} from "../../../../js/lib/games/hex_frost/ai.js";
import {
  BAILEY_STATE,
  BLOCK_STATE,
  ENEMY_TYPE,
  GAME_MODE,
  PHASE,
} from "../../../../js/lib/games/hex_frost/protocol.js";
import {
  BLOCK_GAP,
  BLOCK_W,
  CANVAS_W,
  createInitialState,
} from "../../../../js/lib/games/hex_frost/physics.js";

function buildingState(mode = GAME_MODE.ARCTIC_RACE) {
  return {
    ...createInitialState(mode, 12345),
    phase: PHASE.BUILDING,
  };
}

function blockAt(centerX, state = BLOCK_STATE.WHITE) {
  return {
    x: centerX + BLOCK_GAP - BLOCK_W / 2,
    state,
  };
}

function rowWithBlocks(blocks) {
  return {
    direction: 1,
    offset: 0,
    totalWidth: 7 * (BLOCK_W + BLOCK_GAP),
    blocks,
  };
}

function replaceRow(state, rowIndex, blocks) {
  const blockRows = state.blockRows.map((row, index) =>
    index === rowIndex ? rowWithBlocks(blocks) : row,
  );
  return { ...state, blockRows };
}

describe("HexFrostAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeFrostAIDifficulty("easy")).toBe("easy");
    expect(normalizeFrostAIDifficulty("HARD")).toBe("hard");
    expect(normalizeFrostAIDifficulty("legendary")).toBe("normal");
    expect(normalizeFrostAIDifficulty(null)).toBe("normal");
  });

  it("updates difficulty through the public setter", () => {
    const ai = createHexFrostAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

  it("returns neutral inputs outside the building phase", () => {
    const ai = createHexFrostAI({ difficulty: "hard", rng: () => 0.5 });

    expect(ai.nextInputs({ state: createInitialState(GAME_MODE.ARCTIC_RACE, 12345) })).toEqual({
      left: false,
      right: false,
      up: false,
      down: false,
    });
  });

  it("returns neutral inputs while Bailey is jumping", () => {
    const ai = createHexFrostAI({ difficulty: "hard", rng: () => 0.5 });
    const state = buildingState();
    state.p2 = { ...state.p2, state: BAILEY_STATE.JUMPING };

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      left: false,
      right: false,
      up: false,
      down: false,
    });
  });

  it("targets the AI igloo when enough pieces are complete on shore", () => {
    const state = buildingState();
    state.p2 = { ...state.p2, row: -1, x: CANVAS_W / 2, iglooComplete: true };

    const target = chooseFrostTarget(state, 2, FROST_AI_DIFFICULTIES.hard);

    expect(target.reason).toBe("igloo");
    expect(target.row).toBe(-1);
    expect(target.x).toBeGreaterThan(550);
    expect(target.jump).toBeNull();
  });

  it("jumps down from shore when aligned with a useful row 0 block", () => {
    let state = buildingState();
    state = replaceRow(state, 0, [blockAt(300)]);
    state.p2 = { ...state.p2, row: -1, x: 300, state: BAILEY_STATE.IDLE };

    const target = chooseFrostTarget(state, 2, FROST_AI_DIFFICULTIES.hard);

    expect(target).toMatchObject({ row: 0, reason: "block", jump: "down" });
    expect(movementInputs(state.p2, target, FROST_AI_DIFFICULTIES.hard)).toEqual({
      left: false,
      right: false,
      up: false,
      down: true,
    });
  });

  it("moves toward a target before jumping", () => {
    const actor = { x: 300 };

    expect(movementInputs(actor, { x: 240, jump: "down" }, FROST_AI_DIFFICULTIES.hard)).toEqual({
      left: true,
      right: false,
      up: false,
      down: false,
    });
    expect(movementInputs(actor, { x: 360, jump: "up" }, FROST_AI_DIFFICULTIES.hard)).toEqual({
      left: false,
      right: true,
      up: false,
      down: false,
    });
  });

  it("can steal opponent blocks outside peaceful mode", () => {
    let state = buildingState(GAME_MODE.ARCTIC_RACE);
    state = replaceRow(state, 0, [blockAt(180, BLOCK_STATE.BLUE_P1), blockAt(360)]);
    state.p2 = { ...state.p2, row: -1, x: 170 };

    const target = selectTargetBlock(state, 0, 2, FROST_AI_DIFFICULTIES.hard);

    expect(target.reason).toBe("block");
    expect(target.x).toBeLessThan(240);
  });

  it("does not target opponent blocks as useful in peaceful mode", () => {
    let state = buildingState(GAME_MODE.PEACEFUL);
    state = replaceRow(state, 0, [blockAt(180, BLOCK_STATE.BLUE_P1), blockAt(360)]);
    state.p2 = { ...state.p2, row: -1, x: 170 };

    const target = selectTargetBlock(state, 0, 2, FROST_AI_DIFFICULTIES.hard);

    expect(target.reason).toBe("block");
    expect(target.x).toBeGreaterThan(300);
  });

  it("scores hazards on the same row as risky", () => {
    const state = buildingState();
    state.enemies = [{ type: ENEMY_TYPE.CRAB, x: 320, row: 1, state: 1, timer: 0 }];

    expect(pathRisk(state, 320, 1, 2, FROST_AI_DIFFICULTIES.hard)).toBeGreaterThan(
      pathRisk(state, 460, 1, 2, FROST_AI_DIFFICULTIES.hard),
    );
  });

  it("avoids a dangerous block when another target is available", () => {
    let state = buildingState();
    state = replaceRow(state, 0, [blockAt(260), blockAt(420)]);
    state.p2 = { ...state.p2, row: -1, x: 260 };
    state.enemies = [{ type: ENEMY_TYPE.CRAB, x: 260, row: 0, state: 1, timer: 0 }];

    const target = chooseFrostTarget(state, 2, FROST_AI_DIFFICULTIES.hard);

    expect(target.x).toBeGreaterThan(360);
  });

  it("uses the cached decision between difficulty ticks", () => {
    const ai = createHexFrostAI({ difficulty: "easy", rng: () => 0.5 });
    let state = buildingState();
    state = replaceRow(state, 0, [blockAt(220)]);
    state.p2 = { ...state.p2, row: -1, x: 300 };

    const first = ai.nextInputs({ state, player: 2 });
    state = replaceRow(state, 0, [blockAt(420)]);
    const second = ai.nextInputs({ state, player: 2 });

    expect(first).toEqual(second);
  });
});
