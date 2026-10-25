import { describe, it } from "vitest";
import { SOUNDS } from "../../../../js/lib/games/hex_boxing/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Boxing's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("hex_boxing", { sounds: SOUNDS }, SOUND_SCRIPT);
  });
});
