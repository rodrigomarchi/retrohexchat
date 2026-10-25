import { describe, it } from "vitest";
import { SOUNDS } from "../../../../js/lib/games/breakout/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Block Breakers's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("breakout", { sounds: SOUNDS }, SOUND_SCRIPT);
  });
});
