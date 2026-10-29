import { describe, it, expect, vi } from "vitest";
import {
  FROST_AI_DIFFICULTIES,
  chooseFrostTarget,
  createHexFrostAI,
  landingSpan,
  normalizeFrostAIDifficulty,
  pathRisk,
  selectTargetBlock,
  steer,
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
import { describeStrengthOrder } from "../../../support/games/strength_order.js";
import { itSetsDifficulty } from "../../../support/games/ai_tests.js";
import { released } from "../../../support/games/physics_tests.js";

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

// A state for steering tests: no enemies, the given round's drift, P2 at `p2`.
function steeringState({ round = 1, row0 = [blockAt(300)], p2 = {} } = {}) {
  const state = { ...replaceRow(buildingState(), 0, row0), round, enemies: [] };
  state.p2 = { ...state.p2, row: -1, state: BAILEY_STATE.IDLE, ...p2 };
  return state;
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

  itSetsDifficulty(createHexFrostAI);

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

    expect(ai.nextInputs({ state, player: 2 })).toEqual(released("left", "right", "up", "down"));
  });

  it("targets the AI igloo when enough pieces are complete on shore", () => {
    const state = buildingState();
    state.p2 = { ...state.p2, row: -1, x: CANVAS_W / 2, iglooComplete: true };

    const target = chooseFrostTarget(state, 2, FROST_AI_DIFFICULTIES.hard);

    expect(target.reason).toBe("igloo");
    expect(target.row).toBe(-1);
    expect(target.x).toBeGreaterThan(550);
  });

  it("jumps down from shore when the row 0 block will be under it on landing", () => {
    // The block spans 274–326 now and 286–338 once a jump lands (0.6 px × 20 frames).
    const state = steeringState({ p2: { x: 300 } });
    const target = chooseFrostTarget(state, 2, FROST_AI_DIFFICULTIES.hard);

    expect(target).toMatchObject({ row: 0, index: 0, reason: "block" });
    expect(steer(state, state, state.p2, target, FROST_AI_DIFFICULTIES.hard)).toEqual({
      left: false,
      right: false,
      up: false,
      down: true,
    });
  });

  it("walks toward where the block will be before jumping", () => {
    const state = steeringState({ p2: { x: 120 } });
    const target = { x: 300, row: 0, index: 0 };

    expect(steer(state, state, state.p2, target, FROST_AI_DIFFICULTIES.hard)).toEqual({
      left: false,
      right: true,
      up: false,
      down: false,
    });
  });

  it("leads the landing by the block's drift during the jump", () => {
    // Round 5 drifts 1.7 px a frame: the block spans 274–326 now, 308–360 on landing.
    const target = { x: 300, row: 0, index: 0 };
    const config = FROST_AI_DIFFICULTIES.hard;

    const overNow = steeringState({ round: 5, p2: { x: 290 } });
    expect(landingSpan(overNow, 0, 0)).toEqual([308, 360]);
    expect(steer(overNow, overNow, overNow.p2, target, config)).toMatchObject({
      down: false,
      right: true,
    });

    const overOnLanding = steeringState({ round: 5, p2: { x: 334 } });
    expect(steer(overOnLanding, overOnLanding, overOnLanding.p2, target, config).down).toBe(true);
  });

  it("jumps only with its landing margin inside the block", () => {
    // 6 px inside the landing span (286–338).
    const state = steeringState({ p2: { x: 292 } });
    const target = { x: 300, row: 0, index: 0 };

    expect(steer(state, state, state.p2, target, FROST_AI_DIFFICULTIES.hard).down).toBe(false);
    expect(steer(state, state, state.p2, target, FROST_AI_DIFFICULTIES.normal).down).toBe(true);
  });

  it("jumps on where it believes it stands, error included", () => {
    const state = steeringState({ p2: { x: 312 } });
    const target = { x: 300, row: 0, index: 0 };
    const config = FROST_AI_DIFFICULTIES.hard;

    expect(steer(state, state, state.p2, target, config, 0).down).toBe(true);
    // Believing it stands 30 px further right, it waits for the block instead.
    expect(steer(state, state, state.p2, target, config, 30).down).toBe(false);
  });

  it("does not walk off the block it stands on", () => {
    // Row 1 drifts left; its block spans 274–326, footing 282–318.
    let state = replaceRow(buildingState(), 1, [blockAt(300)]);
    state = replaceRow(state, 2, [blockAt(540)]);
    state.enemies = [];
    const target = { x: 540, row: 2, index: 0 };
    const config = FROST_AI_DIFFICULTIES.hard;

    const atEdge = { ...state.p2, row: 1, x: 318, state: BAILEY_STATE.IDLE };
    expect(steer(state, state, atEdge, target, config)).toMatchObject({
      left: false,
      right: false,
    });

    const inside = { ...atEdge, x: 300 };
    expect(steer(state, state, inside, target, config).right).toBe(true);
  });

  it("only picks blocks wholly on screen", () => {
    // The block at 10 starts off the left edge, though it is the closest.
    const state = steeringState({ row0: [blockAt(10), blockAt(400)], p2: { x: 10 } });

    expect(selectTargetBlock(state, 0, 2, FROST_AI_DIFFICULTIES.hard).index).toBe(1);
  });

  it("does not aim at a block that leaves the screen during the jump", () => {
    // 564–616 now, 598–650 once a round-5 jump lands.
    const state = steeringState({ round: 5, row0: [blockAt(590)] });

    expect(landingSpan(state, 0, 0)).toBeNull();
  });

  // The opponent's block at 180 is beside the AI; a white one waits at 360.
  it.each([
    ["steals the opponent's block outside peaceful mode", GAME_MODE.ARCTIC_RACE, 180],
    ["leaves the opponent's block alone in peaceful mode", GAME_MODE.PEACEFUL, 360],
  ])("%s", (_name, mode, expectedX) => {
    let state = buildingState(mode);
    state = replaceRow(state, 0, [blockAt(180, BLOCK_STATE.BLUE_P1), blockAt(360)]);
    state.p2 = { ...state.p2, row: -1, x: 170 };

    const target = selectTargetBlock(state, 0, 2, FROST_AI_DIFFICULTIES.hard);

    expect(target).toMatchObject({ reason: "block", x: expectedX });
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

  it("waits its reaction time at the start of a round before moving", () => {
    const ai = createHexFrostAI({ difficulty: "hard", rng: () => 0.5 });
    const state = steeringState({ round: 5, p2: { x: 334 } });
    const { reaction } = FROST_AI_DIFFICULTIES.hard;

    for (let frame = 1; frame <= reaction; frame++) {
      expect(ai.nextInputs({ state, player: 2 }).down).toBe(false);
    }
    expect(ai.nextInputs({ state, player: 2 }).down).toBe(true);
  });

  it("sees an enemy leave only a reaction time later", () => {
    const ai = createHexFrostAI({ difficulty: "hard", rng: () => 0.5 });
    const clear = steeringState({ round: 5, p2: { x: 334 } });
    const guarded = { ...clear, enemies: [{ type: ENEMY_TYPE.CRAB, x: 334, row: 0, state: 1 }] };
    const { reaction } = FROST_AI_DIFFICULTIES.hard;

    for (let frame = 0; frame < reaction * 2; frame++) {
      expect(ai.nextInputs({ state: guarded, player: 2 }).down).toBe(false);
    }
    for (let frame = 0; frame < reaction; frame++) {
      expect(ai.nextInputs({ state: clear, player: 2 }).down).toBe(false);
    }
    expect(ai.nextInputs({ state: clear, player: 2 }).down).toBe(true);
  });

  it("forgets the last round when told a new one starts", () => {
    const rng = vi.fn(() => 0.5);
    const ai = createHexFrostAI({ difficulty: "hard", rng });
    const state = steeringState({ round: 5, p2: { x: 334 } });
    const { reaction } = FROST_AI_DIFFICULTIES.hard;

    for (let frame = 0; frame <= reaction; frame++) ai.nextInputs({ state, player: 2 });
    expect(ai.nextInputs({ state, player: 2 }).down).toBe(true);
    expect(rng).toHaveBeenCalledTimes(2);

    ai.forget();

    // A fresh look at the ice, and a fresh aim, before it moves again.
    for (let frame = 1; frame <= reaction; frame++) {
      expect(ai.nextInputs({ state, player: 2 }).down).toBe(false);
    }
    expect(ai.nextInputs({ state, player: 2 }).down).toBe(true);
    expect(rng).toHaveBeenCalledTimes(4);
  });

  it("draws one aim error per hop and keeps it until the jump", () => {
    const rng = vi.fn(() => 0.5);
    const ai = createHexFrostAI({ difficulty: "hard", rng });
    const onShore = steeringState({ p2: { x: 120 } });
    const onRow0 = steeringState({ p2: { x: 300, row: 0 } });

    for (let frame = 0; frame < 40; frame++) ai.nextInputs({ state: onShore, player: 2 });
    // One error, the sum of two draws.
    expect(rng).toHaveBeenCalledTimes(2);

    for (let frame = 0; frame < 40; frame++) ai.nextInputs({ state: onRow0, player: 2 });
    expect(rng).toHaveBeenCalledTimes(4);
  });
});

describeStrengthOrder("hex_frost", FROST_AI_DIFFICULTIES, {
  reaction: "down",
  interval: "down",
  deadzone: "down",
  landMargin: "up",
  aimError: "down",
  walkDuty: "up",
  safetyWidth: "up",
  enemyWeight: "up",
  distanceWeight: "down",
  usefulBias: "up",
});
