import { describe, it } from "vitest";
import { MASTER_VOLUME, SOUNDS, extend } from "../../../../js/lib/games/hex_hockey/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Hockey's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded(
      "hex_hockey",
      { sounds: SOUNDS, masterVolume: MASTER_VOLUME, extend },
      SOUND_SCRIPT,
    );
  });
});
