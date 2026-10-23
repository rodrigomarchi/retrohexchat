import { describe, it, expect } from "vitest";
import { clamp, normalizeDifficulty } from "../../../js/lib/games/ai_common.js";

describe("normalizeDifficulty", () => {
  it("keeps a known difficulty, in any case", () => {
    expect(normalizeDifficulty("HARD")).toBe("hard");
    expect(normalizeDifficulty("easy", { easy: {}, normal: {} })).toBe("easy");
  });

  it("falls back to normal for anything else", () => {
    expect(normalizeDifficulty("insane")).toBe("normal");
    expect(normalizeDifficulty(undefined)).toBe("normal");
    expect(normalizeDifficulty("hard", { easy: {}, normal: {} })).toBe("normal");
    expect(normalizeDifficulty("toString", {})).toBe("normal");
  });
});

describe("clamp", () => {
  it("keeps a value within its bounds", () => {
    expect(clamp(5, 0, 3)).toBe(3);
    expect(clamp(-1, 0, 3)).toBe(0);
    expect(clamp(2, 0, 3)).toBe(2);
  });
});
