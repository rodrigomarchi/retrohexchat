import { describe, expect, it } from "vitest";
import {
  createOutlawAI,
  normalizeOutlawAIDifficulty,
  predictIncomingBulletY,
} from "../../../../js/lib/games/hex_outlaw/ai.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_outlaw/protocol.js";
import {
  BULLET_SPEED_X,
  createInitialState,
  NML_P2_MIN_X,
} from "../../../../js/lib/games/hex_outlaw/physics.js";

function playingState(mode = GAME_MODE.NO_MANS_LAND) {
  const state = createInitialState(mode);
  state.phase = PHASE.PLAYING;
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

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      up: false,
      down: false,
      left: false,
      right: false,
      fire: false,
    });
  });

  it("predicts an incoming straight bullet near the AI player", () => {
    const state = playingState();
    state.b1active = true;
    state.b1x = state.p2x - 80;
    state.b1y = state.p2y + 4;
    state.b1vx = BULLET_SPEED_X;
    state.b1vy = 0;

    expect(predictIncomingBulletY(state, 2)).toBeCloseTo(state.p2y + 4, 1);
  });

  it("dodges an incoming bullet on the current lane", () => {
    const ai = createOutlawAI({ difficulty: "hard" });
    const state = playingState();
    state.b1active = true;
    state.b1x = state.p2x - 60;
    state.b1y = state.p2y;
    state.b1vx = BULLET_SPEED_X;
    state.b1vy = 0;

    const inputs = ai.nextInputs({ state, player: 2 });

    expect(inputs.fire).toBe(false);
    expect(inputs.up || inputs.down).toBe(true);
    expect(inputs.up && inputs.down).toBe(false);
  });

  it("dodges downward instead of leaving the arena at the top", () => {
    const ai = createOutlawAI({ difficulty: "hard" });
    const state = playingState();
    state.p2y = 54;
    state.b1active = true;
    state.b1x = state.p2x - 40;
    state.b1y = state.p2y;
    state.b1vx = BULLET_SPEED_X;
    state.b1vy = 0;

    expect(ai.nextInputs({ state, player: 2 })).toMatchObject({ up: false, down: true });
  });

  it("fires a one-frame shot when aligned with a clear target", () => {
    const ai = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    const state = playingState();
    state.p1y = state.p2y;

    const first = ai.nextInputs({ state, player: 2 });
    const second = ai.nextInputs({ state, player: 2 });

    expect(first.fire).toBe(true);
    expect(second.fire).toBe(false);
  });

  it("does not fire a blocked quick-draw lane", () => {
    const ai = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    const state = playingState(GAME_MODE.QUICK_DRAW);
    state.p1y = state.p2y;

    expect(ai.nextInputs({ state, player: 2 }).fire).toBe(false);
  });

  it("uses horizontal movement only in No Man's Land", () => {
    const ai = createOutlawAI({ difficulty: "hard" });
    const nml = playingState(GAME_MODE.NO_MANS_LAND);
    nml.p2x = NML_P2_MIN_X + 80;
    const quickDraw = playingState(GAME_MODE.QUICK_DRAW);

    expect(ai.nextInputs({ state: nml, player: 2 }).left).toBe(true);
    expect(ai.nextInputs({ state: quickDraw, player: 2 }).left).toBe(false);
  });
});
