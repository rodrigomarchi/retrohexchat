import { describe, expect, it, vi } from "vitest";
import {
  PUNCH_DURATION,
  PUNCH_WINDUP,
  createInitialState,
  stepTick,
} from "../../../../js/lib/games/hex_boxing/physics.js";
import { PHASE, PUNCH_STATE } from "../../../../js/lib/games/hex_boxing/protocol.js";
import {
  BOXING_AI_DIFFICULTIES,
  BOXING_PUNCH_CYCLE_FRAMES,
  boxingFacingInputs,
  boxingMovementInputs,
  boxingTargetPosition,
  createBoxingAI,
  directionFacesOpponent,
  normalizeBoxingAIDifficulty,
  shouldThrowPunch,
} from "../../../../js/lib/games/hex_boxing/ai.js";
import { scriptedRng } from "../../../support/games/ai_tests.js";
import { describeStrengthOrder } from "../../../support/games/strength_order.js";

/** The fight under way, the boxers on line 240, with `overrides`. */
function inRing(overrides = {}) {
  return { ...fightingState(), b1y: 240, b2y: 240, ...overrides };
}

/** Player two 28 px right of player one and facing it: in reach and lined up. */
function inReach(overrides = {}) {
  return inRing({ b1x: 192, b2x: 220, b2dir: 4, ...overrides });
}

function look(ai, state) {
  return ai.nextInputs({ state, player: 2 });
}

function fightingState() {
  const state = createInitialState();
  state.phase = PHASE.FIGHTING;
  return state;
}

describe("BoxingAI", () => {
  it("normalizes invalid difficulties to normal", () => {
    expect(normalizeBoxingAIDifficulty("easy")).toBe("easy");
    expect(normalizeBoxingAIDifficulty("HARD")).toBe("hard");
    expect(normalizeBoxingAIDifficulty("legendary")).toBe("normal");
    expect(normalizeBoxingAIDifficulty(null)).toBe("normal");
  });

  it("lets difficulty be updated after creation", () => {
    const ai = createBoxingAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

  it("returns neutral inputs outside the fighting phase", () => {
    const ai = createBoxingAI({ difficulty: "hard", rng: () => 0 });
    const state = createInitialState();

    expect(look(ai, state)).toEqual({
      up: false,
      down: false,
      left: false,
      right: false,
      punch: false,
    });
  });

  it("approaches the opponent from the right side for player 2", () => {
    const ai = createBoxingAI({ difficulty: "hard", rng: () => 0.5 });
    const state = fightingState();

    const inputs = look(ai, state);

    expect(inputs.left).toBe(true);
    expect(inputs.right).toBe(false);
  });

  it("steps back from a punch it is to dodge", () => {
    const state = inRing({
      b1x: 420,
      b1punchState: PUNCH_STATE.PUNCHING,
      b2x: 450,
    });

    const target = boxingTargetPosition(state, 2, BOXING_AI_DIFFICULTIES.hard, { dodge: true });

    expect(target.kind).toBe("dodge");
    expect(target.x).toBeGreaterThan(state.b2x);
    expect(target.y).toBe(state.b2y);
  });

  it("holds position inside the deadzone", () => {
    expect(boxingMovementInputs({ x: 100, y: 100 }, { x: 104, y: 97 }, 6)).toEqual({
      up: false,
      down: false,
      left: false,
      right: false,
      punch: false,
    });
  });

  it("moves toward a target outside the deadzone", () => {
    expect(boxingMovementInputs({ x: 100, y: 100 }, { x: 80, y: 130 }, 6)).toEqual({
      up: false,
      down: true,
      left: true,
      right: false,
      punch: false,
    });
  });

  it("throws a one-frame punch when aligned and in range", () => {
    const ai = createBoxingAI({ difficulty: "hard", rng: () => 0 });
    const state = inReach();

    const first = look(ai, state);
    const second = look(ai, state);

    expect(first.punch).toBe(true);
    expect(second.punch).toBe(false);
  });

  it("does not punch when the rng roll misses", () => {
    const state = inReach();

    expect(shouldThrowPunch(state, 2, BOXING_AI_DIFFICULTIES.easy, () => 1)).toBe(false);
  });

  it("requires the boxer to face the opponent before punching", () => {
    const state = inReach({ b2dir: 0 });

    expect(shouldThrowPunch(state, 2, BOXING_AI_DIFFICULTIES.hard, () => 0)).toBe(false);
  });

  it("maps 8-way facing directions against the opponent vector", () => {
    expect(directionFacesOpponent(4, -20, 0)).toBe(true);
    expect(directionFacesOpponent(0, -20, 0)).toBe(false);
    expect(directionFacesOpponent(6, 0, -20)).toBe(true);
    expect(directionFacesOpponent(2, 0, -20)).toBe(false);
  });

  it("uses the configured rng for target error and punch odds", () => {
    const rng = vi.fn(() => 0);
    const ai = createBoxingAI({ difficulty: "hard", rng });
    const state = inReach();

    look(ai, state);

    expect(rng).toHaveBeenCalled();
  });

  it("steps in when its punch is ready and keeps its distance while it is not", () => {
    const state = inRing({ b1x: 300, b2x: 400 });
    const config = BOXING_AI_DIFFICULTIES.easy;

    const ready = boxingTargetPosition(state, 2, config, { ready: true });
    const recovering = boxingTargetPosition(state, 2, config, { ready: false });

    expect(ready).toMatchObject({ kind: "approach", x: 300 + config.idealDistancePx });
    expect(recovering).toMatchObject({ kind: "standoff", x: 300 + config.standoffDistancePx });
  });

  it("reads the rival where it stood reactionFrames ago", () => {
    const ai = createBoxingAI({ difficulty: "normal", rng: () => 0.5 });
    const state = inRing({ b1x: 300, b2x: 400 });
    const { reactionFrames, decisionInterval } = BOXING_AI_DIFFICULTIES.normal;

    look(ai, state);
    state.b1y = 340;
    const early = look(ai, state);
    for (let frame = 1; frame < reactionFrames + decisionInterval; frame++) {
      look(ai, state);
    }
    const late = look(ai, state);

    expect(early.down).toBe(false);
    expect(late.down).toBe(true);
  });

  it("decides once per punch whether to dodge it", () => {
    // 0.2 is under hard's dodge odds, and moves the aim less than its
    // deadzone; player two stands at its standoff, so only a dodge moves it.
    const stepsBack = (rng) => {
      const ai = createBoxingAI({ difficulty: "hard", rng });
      const state = inRing({
        b1x: 400,
        b1dir: 0,
        b1punchState: PUNCH_STATE.WINDUP,
        b1punchTimer: PUNCH_WINDUP,
        b2x: 400 + BOXING_AI_DIFFICULTIES.hard.standoffDistancePx,
        b2dir: 4,
        b2punchState: PUNCH_STATE.COOLDOWN,
      });
      return Array.from({ length: 20 }, () => {
        const inputs = look(ai, state);
        return inputs.right;
      }).some(Boolean);
    };
    expect(stepsBack(() => 0.2)).toBe(true);
    expect(stepsBack(scriptedRng([0.99], 0.2))).toBe(false);
  });

  it("rolls the punch odds once per opening and waits out the cooldown after passing", () => {
    const ai = createBoxingAI({ difficulty: "hard", rng: () => 0.5 });
    const state = inReach();
    const cooldown = BOXING_AI_DIFFICULTIES.hard.punchCooldownFrames;

    const punches = Array.from({ length: cooldown + 1 }, () => look(ai, state).punch);

    expect(punches[0]).toBe(true);
    expect(punches.slice(1, cooldown)).toEqual(Array(cooldown - 1).fill(false));
    expect(punches[cooldown]).toBe(true);
  });

  it("turns to face a rival in range before punching", () => {
    const state = inReach({ b2dir: 0 });

    expect(boxingFacingInputs(state, 2, BOXING_AI_DIFFICULTIES.hard)).toMatchObject({
      left: true,
      right: false,
    });
    state.b2dir = 4;
    expect(boxingFacingInputs(state, 2, BOXING_AI_DIFFICULTIES.hard)).toBeNull();
  });

  it("never punches faster than a punch's cycle or throws wider than a fist lands", () => {
    const configs = Object.values(BOXING_AI_DIFFICULTIES);
    for (const config of configs) {
      expect(config.punchCooldownFrames).toBeGreaterThanOrEqual(BOXING_PUNCH_CYCLE_FRAMES);
      expect(config.punchAlignmentPx).toBeLessThanOrEqual(11);
    }
    const { easy, normal, hard } = BOXING_AI_DIFFICULTIES;
    expect(normal.punchAlignmentPx).toBeLessThanOrEqual(easy.punchAlignmentPx);
    expect(hard.punchAlignmentPx).toBeLessThanOrEqual(normal.punchAlignmentPx);
  });

  it("sees a wind-up soon enough on hard to step out of a close punch, and rarely on easy", () => {
    // The rival winds up a punch from each close distance — one that would
    // land early in its flight. The AI always chooses to dodge, and moves
    // only to dodge, so only how quickly it sees the wind-up differs.
    const idle = { up: false, down: false, left: false, right: false, punch: false };
    const escapes = (difficulty) => {
      let escaped = 0;
      for (let distance = 20; distance <= 32; distance++) {
        const ai = createBoxingAI({ difficulty, rng: () => 0 });
        let state = inRing({ b1x: 400 - distance, b1dir: 0, b2x: 400, b2dir: 4 });
        let pressed = { 1: false, 2: false };
        let landed = false;
        for (let frame = 0; frame < PUNCH_WINDUP + PUNCH_DURATION && !landed; frame++) {
          const rival = { up: false, down: false, left: false, right: false, punch: frame === 0 };
          const inputs = look(ai, state);
          const own = ai._target?.kind === "dodge" ? { ...inputs, punch: false } : idle;
          const step = stepTick(state, { 1: rival, 2: own }, pressed);
          ({ state, pressed } = step);
          landed = step.events.hits.length > 0;
        }
        if (!landed) escaped++;
      }
      return escaped;
    };

    const [easy, normal, hard] = ["easy", "normal", "hard"].map(escapes);
    expect(hard).toBeGreaterThanOrEqual(10);
    expect(normal).toBeLessThanOrEqual(hard);
    expect(normal).toBeGreaterThanOrEqual(easy);
    expect(easy).toBeLessThanOrEqual(2);
  });
});

describe("BoxingAI between rounds", () => {
  it("forgets where the rival stood once a new round starts", () => {
    const watched = (forget) => {
      const ai = createBoxingAI({ difficulty: "normal", rng: () => 0.5 });
      const state = inRing({ b1x: 300, b2x: 400 });
      for (let frame = 0; frame < 12; frame++) look(ai, state);
      if (forget) ai.forget();
      return look(ai, { ...state, b1y: 340 }).down;
    };

    expect(watched(false)).toBe(false);
    expect(watched(true)).toBe(true);
  });
});

describeStrengthOrder("Hex Boxing", BOXING_AI_DIFFICULTIES, {
  reactionFrames: "down",
  punchReactionFrames: "down",
  decisionInterval: "down",
  targetErrorPx: "down",
  deadzonePx: "down",
  idealDistancePx: "down",
  standoffDistancePx: "down",
  retreatDistancePx: "down",
  punchDistancePx: "up",
  punchAlignmentPx: "down",
  punchChance: "up",
  punchCooldownFrames: "down",
  dodgeChance: "up",
});
