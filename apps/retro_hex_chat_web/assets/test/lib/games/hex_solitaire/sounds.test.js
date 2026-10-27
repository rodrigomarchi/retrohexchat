import { describe, it } from "vitest";
import { MASTER_VOLUME, SOUNDS } from "../../../../js/lib/games/hex_solitaire/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Solitaire's sounds", () => {
  it("make the voices recorded for them", () => {
    expectSoundsAsRecorded(
      "hex_solitaire",
      { sounds: SOUNDS, masterVolume: MASTER_VOLUME },
      SOUND_SCRIPT,
    );
  });
});
