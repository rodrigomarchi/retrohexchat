import { describe, it } from "vitest";
import { SOUNDS } from "../../../../js/lib/games/pixel_tanks/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Pixel Tanks's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("pixel_tanks", { sounds: SOUNDS }, SOUND_SCRIPT);
  });
});
