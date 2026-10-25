import { describe, it } from "vitest";
import { SOUNDS, extend } from "../../../../js/lib/games/hex_enduro/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Enduro's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("hex_enduro", { sounds: SOUNDS, extend }, SOUND_SCRIPT);
  });
});
