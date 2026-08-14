import { describe, it, expect } from "vitest";
import {
  chooseInvaderTarget,
  createHexInvadersAI,
  incomingBombThreat,
  normalizeInvadersAIDifficulty,
} from "../../../../js/lib/games/hex_invaders/ai.js";
import { ALIEN_TYPE, GAME_MODE, PHASE } from "../../../../js/lib/games/hex_invaders/protocol.js";
import { createInitialState, createWave } from "../../../../js/lib/games/hex_invaders/physics.js";

function playingState(mode = GAME_MODE.INVASION_WAR) {
  return {
    ...createWave(createInitialState(mode, 12345), 1),
    phase: PHASE.PLAYING,
  };
}

function alien(x, y, type = ALIEN_TYPE.BASE) {
  return { x, y, type, hp: 1 };
}

describe("HexInvadersAI", () => {
  it("normalizes difficulty names", () => {
    expect(normalizeInvadersAIDifficulty("easy")).toBe("easy");
    expect(normalizeInvadersAIDifficulty("HARD")).toBe("hard");
    expect(normalizeInvadersAIDifficulty("legendary")).toBe("normal");
    expect(normalizeInvadersAIDifficulty(null)).toBe("normal");
  });

  it("updates difficulty through the public setter", () => {
    const ai = createHexInvadersAI({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });

  it("returns neutral inputs outside active play", () => {
    const ai = createHexInvadersAI({ difficulty: "hard" });

    expect(
      ai.nextInputs({
        state: createInitialState(GAME_MODE.INVASION_WAR, 12345),
        player: 2,
      }),
    ).toEqual({ left: false, right: false, fire: false });
  });

  it("targets the player 2 alien lane in split-screen modes", () => {
    const state = {
      ...playingState(),
      cannon2X: 400,
      aliens1: [alien(40, 330)],
      aliens2: [alien(500, 330)],
    };

    const target = chooseInvaderTarget(state, 2, undefined, () => 0.5);

    expect(target).toMatchObject({ kind: "alien", index: 0, x: 505 });
  });

  it("targets the shared alien grid in co-op mode", () => {
    const state = {
      ...playingState(GAME_MODE.COOP),
      cannon2X: 100,
      aliens1: [alien(150, 330)],
      aliens2: [alien(520, 330)],
    };

    const target = chooseInvaderTarget(state, 2, undefined, () => 0.5);

    expect(target).toMatchObject({ kind: "alien", index: 0, x: 155 });
  });

  it("moves toward the selected target", () => {
    const ai = createHexInvadersAI({ difficulty: "hard", rng: () => 0.5 });
    const state = {
      ...playingState(),
      cannon2X: 400,
      aliens2: [alien(500, 330)],
    };

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      left: false,
      right: true,
      fire: false,
    });
  });

  it("fires when aligned with a target and then respects cooldown", () => {
    const ai = createHexInvadersAI({ difficulty: "hard", rng: () => 0.5 });
    const state = {
      ...playingState(),
      cannon2X: 505,
      aliens2: [alien(500, 330)],
    };

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      left: false,
      right: false,
      fire: true,
    });
    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      left: false,
      right: false,
      fire: false,
    });
  });

  it("does not fire while the player missile is already active", () => {
    const ai = createHexInvadersAI({ difficulty: "hard", rng: () => 0.5 });
    const state = {
      ...playingState(),
      cannon2X: 505,
      m2Active: true,
      aliens2: [alien(500, 330)],
    };

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      left: false,
      right: false,
      fire: false,
    });
  });

  it("dodges incoming bombs before firing", () => {
    const ai = createHexInvadersAI({ difficulty: "hard", rng: () => 0.5 });
    const state = {
      ...playingState(),
      cannon2X: 500,
      aliens2: [alien(495, 330)],
      bombs: [{ side: 2, x: 500, y: 390 }],
      bombCount: 1,
    };

    expect(ai.nextInputs({ state, player: 2 })).toEqual({
      left: false,
      right: true,
      fire: false,
    });
  });

  it("ignores the other side's bombs in split-screen but not in co-op", () => {
    const split = {
      ...playingState(),
      cannon2X: 500,
      bombs: [{ side: 1, x: 500, y: 390 }],
      bombCount: 1,
    };
    const coop = {
      ...playingState(GAME_MODE.COOP),
      cannon2X: 500,
      bombs: [{ side: 1, x: 500, y: 390 }],
      bombCount: 1,
    };

    expect(incomingBombThreat(split, 2)).toBeNull();
    expect(incomingBombThreat(coop, 2)).toMatchObject({ side: 1, x: 500, y: 390 });
  });
});
