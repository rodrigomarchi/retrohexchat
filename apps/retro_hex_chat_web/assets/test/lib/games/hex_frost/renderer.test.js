import { describe, expect, it } from "vitest";
import { createInitialState } from "../../../../js/lib/games/hex_frost/physics.js";
import { GAME_MODE, PHASE } from "../../../../js/lib/games/hex_frost/protocol.js";
import { render } from "../../../../js/lib/games/hex_frost/renderer.js";
import { createMockCtx, drawnTexts } from "../../../support/games/renderer_tests.js";

const COLORS = new Proxy({}, { get: () => "#888888" });

// The title over the ice named the arcade game Hex Frost is inspired by.
describe("Hex Frost's title over the ice", () => {
  it("is the game's own name, in every mode", () => {
    for (const [mode, label] of [
      [GAME_MODE.ARCTIC_RACE, "HEX FROST  R1/5"],
      [GAME_MODE.BLIZZARD, "HEX FROST  BLIZZARD"],
      [GAME_MODE.PEACEFUL, "HEX FROST  PEACEFUL"],
    ]) {
      const ctx = createMockCtx();
      render(ctx, { ...createInitialState(mode, 7), phase: PHASE.BUILDING }, COLORS, 0, []);
      const texts = drawnTexts(ctx);
      expect(texts).toContain(label);
      expect(texts.join(" ")).not.toMatch(/FROSTBITE/i);
    }
  });
});
