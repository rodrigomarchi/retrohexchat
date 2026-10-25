import { describe, it } from "vitest";
import { SOUNDS } from "../../../../js/lib/games/hex_raid/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Raid's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("hex_raid", { sounds: SOUNDS }, SOUND_SCRIPT);
  });
});
