import { describe, expect, it } from "vitest";
import {
  OUTLAW_AI_DIFFICULTIES,
  createOutlawAI,
  nearestBankShot,
  normalizeOutlawAIDifficulty,
  outlawAIConfig,
  predictIncomingBulletY,
} from "../../../../js/lib/games/hex_outlaw/ai.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_outlaw/protocol.js";
import {
  BULLET_SPEED_X,
  createInitialState,
  NML_P1_MAX_X,
  NML_P2_MIN_X,
  stepTick,
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

  // Stopping short of the line it fires on would leave two gunslingers a few
  // pixels apart for good, each waiting for the other.
  it.each(["easy", "normal", "hard"])(
    "comes to a stop on %s only once it can fire from there",
    (level) => {
      for (const mode of Object.values(GAME_MODE)) {
        const config = outlawAIConfig(level, mode);
        expect(config.targetDeadzonePx).toBeLessThan(config.fireWindowPx);
      }
    },
  );

  it("holds its spot in No Man's Land from either side of the street", () => {
    const state = playingState(GAME_MODE.NO_MANS_LAND);
    state.p1x = NML_P1_MAX_X - 80;
    state.p2x = NML_P2_MIN_X + 80;
    const one = createOutlawAI({ difficulty: "hard" }).nextInputs({ state, player: 1 });
    const two = createOutlawAI({ difficulty: "hard" }).nextInputs({ state, player: 2 });

    // Each steps up to a spot a little back from its own line.
    expect(one).toMatchObject({ right: true, left: false });
    expect(two).toMatchObject({ left: true, right: false });
  });

  it("steps back from a bullet in No Man's Land, whichever side it is on", () => {
    const state = bulletOnLane(playingState(GAME_MODE.NO_MANS_LAND));
    const two = afterReaction(createOutlawAI({ difficulty: "hard", rng: () => 0 }), state);
    expect(two).toMatchObject({ right: true, left: false });

    const mirrored = playingState(GAME_MODE.NO_MANS_LAND);
    mirrored.b2active = true;
    mirrored.b2x = mirrored.p1x + 60;
    mirrored.b2y = mirrored.p1y;
    mirrored.b2vx = -BULLET_SPEED_X;
    mirrored.b2vy = 0;
    const ai = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    let one;
    for (let frame = 0; frame <= OUTLAW_AI_DIFFICULTIES.hard.reactionFrames; frame++) {
      one = ai.nextInputs({ state: mirrored, player: 1 });
    }
    expect(one).toMatchObject({ left: true, right: false });
  });
});

describe("OutlawAI in Ricochet", () => {
  const ricochet = () => playingState(GAME_MODE.RICOCHET);

  it("finds a height a bank shot hits the rival from, and the aim it needs", () => {
    const state = ricochet();
    const shot = nearestBankShot(state, 2, state.p2y);

    expect(shot).not.toBeNull();
    const fired = stepTick(
      { ...state, p2y: shot.y },
      { 1: {}, 2: { fire: true } },
      { 1: false, 2: false },
      { 1: false, 2: shot.aimUp },
    );
    // The bullet, flown out, reaches the rival.
    let s = fired.state;
    let hit = false;
    for (let frame = 0; frame < 200 && s.b2active && !hit; frame++) {
      const step = stepTick(s, { 1: {}, 2: {} }, { 1: false, 2: false }, { 1: false, 2: false });
      hit = step.events.hit?.player === 1;
      s = step.state;
    }
    expect(hit).toBe(true);
  });

  // A press is a step and an aim at once: two gunslingers both chasing a
  // bank shot would otherwise trade places for good and never fire.
  it("lands bank shots on a rival that moves between them", () => {
    const shooter = createOutlawAI({ difficulty: "hard", rng: () => 0 });
    let state = ricochet();
    let pressed = { 1: false, 2: false };
    let aim = false;
    let hits = 0;
    for (let frame = 0; frame < 60 * 60 && hits === 0; frame++) {
      // The rival walks a stretch up or down the street, stands, walks
      // again — and never shoots.
      const beat = frame % 320;
      const rival = { up: beat < 40, down: beat >= 160 && beat < 200 };
      const own = shooter.nextInputs({ state, player: 2 });
      if (own.up) aim = true;
      if (own.down) aim = false;
      const step = stepTick(state, { 1: rival, 2: own }, pressed, { 1: false, 2: aim });
      ({ state, pressed } = step);
      if (step.events.hit?.player === 1) hits++;
    }
    expect(hits).toBe(1);
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
