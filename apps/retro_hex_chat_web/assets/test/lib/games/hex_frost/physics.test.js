import { describe, it, expect } from "vitest";
import { checkRoundEnd, createInitialState } from "../../../../js/lib/games/hex_frost/physics.js";
import { PHASE } from "../../../../js/lib/games/hex_frost/protocol.js";

describe("the end of a round", () => {
  it.each([1, 2])("goes to player %i once they are in their igloo", (winner) => {
    const state = { ...createInitialState(0, 1), phase: PHASE.BUILDING, roundWinner: winner };
    const ended = checkRoundEnd(state);
    expect(ended.phase).toBe(PHASE.ROUND_END);
    const key = winner === 1 ? "p1" : "p2";
    expect(ended[key]).not.toBe(state[key]);
  });

  it("is not over while nobody is home", () => {
    const state = { ...createInitialState(0, 1), phase: PHASE.BUILDING, roundWinner: 0 };
    expect(checkRoundEnd(state).phase).toBe(PHASE.BUILDING);
  });
});
