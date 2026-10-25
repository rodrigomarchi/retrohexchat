import { describe, it } from "vitest";
import { SOUNDS, extend } from "../../../../js/lib/games/hex_skiing/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Hex Skiing's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("hex_skiing", { sounds: SOUNDS, extend }, SOUND_SCRIPT);
  });
});
