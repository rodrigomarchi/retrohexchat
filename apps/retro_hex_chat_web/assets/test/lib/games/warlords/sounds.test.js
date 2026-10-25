import { describe, it } from "vitest";
import { SOUNDS } from "../../../../js/lib/games/warlords/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Warlords's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("warlords", { sounds: SOUNDS }, SOUND_SCRIPT);
  });
});
