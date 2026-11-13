import { afterEach, describe, expect, it, vi } from "vitest";
import { AUTOPILOT_GLOBAL, AUTOPILOT_META } from "../../../../js/lib/games/core/autopilot.js";
import { matchPerTest } from "../../../support/games/harness.js";

vi.mock("../../../../js/lib/games/breakout/ai.js", async (original) => {
  const module = await original();
  return { ...module, createBreakoutAI: vi.fn(module.createBreakoutAI) };
});

const { createBreakoutAI } = await import("../../../../js/lib/games/breakout/ai.js");

afterEach(() => {
  document.head.querySelector(AUTOPILOT_META)?.remove();
  createBreakoutAI.mockClear();
});

describe("a Block Breakers seat on autopilot", () => {
  const play = matchPerTest({ gameId: "block_breakers" });

  it("plays at the difficulty the page asked for, not the partner the player's pick names", async () => {
    const meta = document.createElement("meta");
    meta.name = "rhc-autopilot";
    document.head.appendChild(meta);
    vi.stubGlobal(AUTOPILOT_GLOBAL, { difficulty: "hard" });

    await play({ mode: "solo", difficulty: "hard" });

    const asked = createBreakoutAI.mock.calls.map(([options]) => options.difficulty);
    // The partner for a hard game is the weakest; the seat itself plays hard.
    expect(asked).toEqual(["easy", "hard"]);
  });
});
