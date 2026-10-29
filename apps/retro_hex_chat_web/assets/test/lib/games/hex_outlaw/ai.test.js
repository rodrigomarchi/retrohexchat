import { describe, expect, it } from "vitest";
import {
  OUTLAW_AI_DIFFICULTIES,
  createOutlawAI,
  normalizeOutlawAIDifficulty,
  outlawAIConfig,
  predictIncomingBulletY,
} from "../../../../js/lib/games/hex_outlaw/ai.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_outlaw/protocol.js";
import {
  BULLET_SPEED_X,
  createInitialState,
  NML_P2_MIN_X,
} from "../../../../js/lib/games/hex_outlaw/physics.js";
import {
  expectOneFramePress,
  expectPassedOpeningWaits,
  scriptedRng,
} from "../../../support/games/ai_tests.js";
import { describeStrengthOrder } from "../../../support/games/strength_order.js";

function playingState(mode = GAME_MODE.NO_MANS_LAND) {
  const state = createInitialState(mode);
  state.phase = PHASE.PLAYING;
  return state;
}

/** Both gunslingers on the same line. */
function linedUp(mode) {
  const state = playingState(mode);
  return { ...state, p1y: state.p2y };
}

function look(ai, state) {
  return ai.nextInputs({ state, player: 2 });
}

/** The inputs once the AI has watched `state` for as long as it takes to react. */
function afterReaction(ai, state, difficulty = "hard") {
  for (let frame = 0; frame < OUTLAW_AI_DIFFICULTIES[difficulty].reactionFrames; frame++) {
    look(ai, state);
  }
  return look(ai, state);
}

function bulletOnLane(state, distance = 60) {
  state.b1active = true;
  state.b1x = state.p2x - distance;
  state.b1y = state.p2y;
  state.b1vx = BULLET_SPEED_X;
  state.b1vy = 0;
  return state;
}

describe("OutlawAI", () => {
  it("normalizes invalid difficulties to normal", () => {
    expect(normalizeOutlawAIDifficulty("easy")).toBe("easy");
    expect(normalizeOutlawAIDifficulty("HARD")).toBe("hard");
    expect(normalizeOutlawAIDifficulty("legendary")).toBe("normal");
    expect(normalizeOutlawAIDifficulty(null)).toBe("normal");
  });

  it("stays neutral outside the playing phase", () => {
    const ai = createOutlawAI({ difficulty: "hard" });
    const state = createInitialState(GAME_MODE.QUICK_DRAW);

    expect(look(ai, state)).toEqual({
      up: false,
      down: false,
      left: false,
      right: false,
      fire: false,
    });
  });

  it("predicts an incoming straight bullet near the AI player", () => {
    const state = bulletOnLane(playingState(), 80);
    state.b1y += 4;

    expect(predictIncomingBulletY(state, 2)).toBeCloseTo(state.p2y + 4, 1);
  });

  it("dodges an incoming bullet on the current lane", () => {
    const ai = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    const state = bulletOnLane(playingState());

    const inputs = afterReaction(ai, state);

    expect(inputs.fire).toBe(false);
    expect(inputs.up || inputs.down).toBe(true);
    expect(inputs.up && inputs.down).toBe(false);
  });

  it("dodges downward instead of leaving the arena at the top", () => {
    const ai = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    const state = playingState();
    state.p2y = 54;
    bulletOnLane(state, 40);

    expect(afterReaction(ai, state)).toMatchObject({ up: false, down: true });
  });

  it("does not see a bullet until it is reactionFrames old", () => {
    const watching = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    const unaware = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    const state = bulletOnLane(linedUp());

    const inputs = look(watching, state);

    expect(inputs).toEqual(look(unaware, { ...state, b1active: false }));
    expect(inputs.up || inputs.down).toBe(false);
  });

  // A bullet it chose not to dodge stays undodged until that bullet is gone,
  // or the street starts over and the engine has the AI forget it.
  it.each([
    ["once the bullet is gone", (ai, state) => look(ai, { ...state, b1active: false })],
    ["once the street starts over", (ai) => ai.forget()],
  ])("decides once per bullet whether to dodge it, afresh %s", (_when, startOver) => {
    const ai = createOutlawAI({ difficulty: "hard", rng: scriptedRng([0.99], 0) });
    const state = bulletOnLane(linedUp());

    expect(afterReaction(ai, state)).toMatchObject({ up: false, down: false });

    startOver(ai, state);
    const next = afterReaction(ai, state);
    expect(next.up || next.down).toBe(true);
  });

  it("rolls the fire odds once per opening and waits out the cooldown after passing", () => {
    const ai = createOutlawAI({ difficulty: "normal", rng: scriptedRng([0.99], 0) });
    const state = linedUp();

    expectPassedOpeningWaits(
      () => look(ai, state).fire,
      outlawAIConfig("normal", state.gameMode).fireCooldownFrames,
    );
  });

  it("takes a street's own settings over the difficulty's", () => {
    const stagecoach = outlawAIConfig("hard", GAME_MODE.STAGECOACH);

    expect(stagecoach.dodgeChance).not.toBe(OUTLAW_AI_DIFFICULTIES.hard.dodgeChance);
    expect(stagecoach.fireWindowPx).toBe(OUTLAW_AI_DIFFICULTIES.hard.fireWindowPx);
    expect(outlawAIConfig("hard", GAME_MODE.QUICK_DRAW)).toEqual(OUTLAW_AI_DIFFICULTIES.hard);
  });

  it("fires a one-frame shot when aligned with a clear target", () => {
    const ai = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    const state = linedUp();

    expectOneFramePress(() => look(ai, state).fire);
  });

  it("does not fire a blocked quick-draw lane", () => {
    const ai = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    expect(look(ai, linedUp(GAME_MODE.QUICK_DRAW)).fire).toBe(false);
  });

  it("uses horizontal movement only in No Man's Land", () => {
    const ai = createOutlawAI({ difficulty: "hard" });
    const nml = playingState(GAME_MODE.NO_MANS_LAND);
    nml.p2x = NML_P2_MIN_X + 80;
    const quickDraw = playingState(GAME_MODE.QUICK_DRAW);

    expect(look(ai, nml).left).toBe(true);
    expect(look(ai, quickDraw).left).toBe(false);
  });
});

const OUTLAW_STRONGER = {
  dodgeTriggerPx: "up",
  threatFrames: "up",
  dodgeChance: "up",
  reactionFrames: "down",
  fireWindowPx: "down",
  fireCooldownFrames: "down",
  fireChance: "up",
  targetDeadzonePx: "down",
  preferredNmlOffset: "down",
};

for (const [street, mode] of Object.entries(GAME_MODE)) {
  const table = Object.fromEntries(
    ["easy", "normal", "hard"].map((level) => [level, outlawAIConfig(level, mode)]),
  );
  describeStrengthOrder(`Hex Outlaw ${street}`, table, OUTLAW_STRONGER);
}
