import { describe, it } from "vitest";
import { SOUNDS } from "../../../../js/lib/games/hex_outlaw/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Outlaw's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("hex_outlaw", { sounds: SOUNDS }, SOUND_SCRIPT);
  });
});
