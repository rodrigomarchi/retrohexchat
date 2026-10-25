import { describe, it } from "vitest";
import { SOUNDS } from "../../../../js/lib/games/surround/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Light Trails's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("surround", { sounds: SOUNDS }, SOUND_SCRIPT);
  });
});
