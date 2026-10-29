import { describe, it, expect } from "vitest";
import {
  chooseInvaderTarget,
  createHexInvadersAI,
  incomingBombThreat,
  invadersAILevel,
  normalizeInvadersAIDifficulty,
} from "../../../../js/lib/games/hex_invaders/ai.js";
import { ALIEN_TYPE, GAME_MODE, PHASE } from "../../../../js/lib/games/hex_invaders/protocol.js";
import { createInitialState, createWave } from "../../../../js/lib/games/hex_invaders/physics.js";
import { itSetsDifficulty } from "../../../support/games/ai_tests.js";

/** A wave in play in `mode`, with `fields` over it. */
function playing(fields = {}, mode = GAME_MODE.INVASION_WAR) {
  return {
    ...createWave(createInitialState(mode, 12345), 1),
    phase: PHASE.PLAYING,
    ...fields,
  };
}

function alien(x, y, type = ALIEN_TYPE.BASE) {
  return { x, y, type, hp: 1 };
}

/** One bomb falling, as a state's fields. */
function bomb(fields) {
  return { bombs: [fields], bombCount: 1 };
}

/** Player two's cannon at `cannon2X` under one of its aliens, at `alienX`. */
function lane(cannon2X, alienX, fields = {}) {
  return playing({ cannon2X, aliens2: [alien(alienX, 330)], ...fields });
}

/** The AI's inputs for player two: which keys it holds. */
function inputs({ left = false, right = false, fire = false } = {}) {
  return { left, right, fire };
}

/** An AI whose every draw is `roll()`, and one turn of it on a state. */
function aiDrawing(difficulty, roll) {
  const ai = createHexInvadersAI({ difficulty, rng: roll });
  return (state) => ai.nextInputs({ state, player: 2 });
}

const hardAI = () => aiDrawing("hard", () => 0.5);

describe("HexInvadersAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeInvadersAIDifficulty("easy")).toBe("easy");
    expect(normalizeInvadersAIDifficulty("HARD")).toBe("hard");
    expect(normalizeInvadersAIDifficulty("legendary")).toBe("normal");
    expect(normalizeInvadersAIDifficulty(null)).toBe("normal");
  });

  itSetsDifficulty(createHexInvadersAI);

  it("returns neutral inputs outside active play", () => {
    const turn = aiDrawing("hard", Math.random);

    expect(turn(createInitialState(GAME_MODE.INVASION_WAR, 12345))).toEqual(inputs());
  });

  it.each([
    ["the player 2 alien lane in split-screen modes", GAME_MODE.INVASION_WAR, 400, 505],
    ["the shared alien grid in co-op mode", GAME_MODE.COOP, 100, 155],
  ])("targets %s", (_name, mode, cannon2X, x) => {
    const state = playing(
      {
        cannon2X,
        aliens1: [alien(mode === GAME_MODE.COOP ? 150 : 40, 330)],
        aliens2: [alien(500, 330)],
      },
      mode,
    );

    const target = chooseInvaderTarget(state, 2, undefined, () => 0.5);

    expect(target).toMatchObject({ kind: "alien", index: 0, x });
  });

  it("moves toward the selected target", () => {
    expect(hardAI()(lane(400, 500))).toEqual(inputs({ right: true }));
  });

  it("fires when aligned with a target and then respects cooldown", () => {
    const turn = hardAI();
    const state = lane(505, 500);

    expect(turn(state)).toEqual(inputs({ fire: true }));
    expect(turn(state)).toEqual(inputs());
  });

  it("does not fire while the player missile is already active", () => {
    expect(hardAI()(lane(505, 500, { m2Active: true }))).toEqual(inputs());
  });

  it("dodges incoming bombs before firing", () => {
    const state = lane(500, 495, bomb({ side: 2, x: 500, y: 390 }));

    expect(hardAI()(state)).toEqual(inputs({ right: true }));
  });

  it("ignores the other side's bombs in split-screen but not in co-op", () => {
    const fields = { cannon2X: 500, ...bomb({ side: 1, x: 500, y: 390 }) };

    expect(incomingBombThreat(playing(fields), 2)).toBeNull();
    expect(incomingBombThreat(playing(fields, GAME_MODE.COOP), 2)).toMatchObject({
      side: 1,
      x: 500,
      y: 390,
    });
  });

  it("decides once whether it noticed a bomb, and keeps to it while the bomb falls", () => {
    let roll = 0.9;
    const turn = aiDrawing("hard", () => roll);
    const state = lane(500, 495, bomb({ id: 1, side: 2, x: 500, y: 390 }));

    // Unnoticed, the bomb does not stop the cannon shooting.
    expect(turn(state)).toMatchObject({ right: false, fire: true });
    roll = 0;
    expect(turn(state)).toMatchObject({ left: false, right: false });

    expect(turn({ ...state, ...bomb({ id: 2, side: 2, x: 500, y: 390 }) })).toEqual(
      inputs({ right: true }),
    );
  });

  it("draws whether to shoot once per chance, not on every frame", () => {
    let roll = 0.9;
    const turn = aiDrawing("easy", () => roll);
    const state = lane(500, 495);

    expect(turn(state).fire).toBe(false);
    roll = 0;
    expect(turn(state).fire).toBe(false);
  });

  it("keeps a declined shot at the same alien declined when it takes a fresh look", () => {
    const draws = [0.5, 0.9]; // the aim's error (none), then the shot: declined
    const ai = createHexInvadersAI({ difficulty: "normal", rng: () => draws.shift() ?? 0.5 });
    const state = lane(500, 495);
    const fired = Array.from({ length: 20 }, () => ai.nextInputs({ state, player: 2 }).fire);

    // Normal looks again every 6 frames; every look finds the same alien.
    expect(fired.every((fire) => fire === false)).toBe(true);

    // A new wave: the chance is drawn again (0.5 < 0.7) and taken.
    ai.forget();
    expect(ai.nextInputs({ state, player: 2 }).fire).toBe(true);
  });

  it("forgets the bombs it noticed and the target it held when a wave ends", () => {
    let roll = 0;
    const turn = createHexInvadersAI({ difficulty: "hard", rng: () => roll });
    const state = lane(500, 495, bomb({ id: 1, side: 2, x: 500, y: 390 }));
    expect(turn.nextInputs({ state, player: 2 })).toMatchObject({ right: true });

    turn.forget();
    roll = 0.99;
    expect(turn.nextInputs({ state, player: 2 })).toMatchObject({ right: false });
  });

  it("plays co-op as the partner: the player's easy game gets the strongest partner", () => {
    expect(invadersAILevel("easy", GAME_MODE.COOP)).toBe("hard");
    expect(invadersAILevel("normal", GAME_MODE.COOP)).toBe("normal");
    expect(invadersAILevel("hard", GAME_MODE.COOP)).toBe("easy");
    expect(invadersAILevel("easy", GAME_MODE.INVASION_WAR)).toBe("easy");
    expect(invadersAILevel("hard", GAME_MODE.BLITZ)).toBe("hard");
  });

  it("goes for the UFO as a strong co-op partner and leaves it as a weak one", () => {
    const state = playing(
      { cannon2X: 300, ufoActive: true, ufoX: 488, aliens1: [alien(95, 330)] },
      GAME_MODE.COOP,
    );
    const partner = (difficulty) => aiDrawing(difficulty, () => 0.5)(state);

    expect(partner("easy")).toMatchObject({ left: false, right: true });
    expect(partner("hard")).toMatchObject({ left: true, right: false });
  });
});
