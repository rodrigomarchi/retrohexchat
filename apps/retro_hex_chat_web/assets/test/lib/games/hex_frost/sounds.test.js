import { describe, it } from "vitest";
import { MASTER_VOLUME, SOUNDS, extend } from "../../../../js/lib/games/hex_frost/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Frost's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded(
      "hex_frost",
      { sounds: SOUNDS, masterVolume: MASTER_VOLUME, extend },
      SOUND_SCRIPT,
    );
  });
});
