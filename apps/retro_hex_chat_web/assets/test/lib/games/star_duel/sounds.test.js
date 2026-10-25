import { describe, it } from "vitest";
import { SOUNDS, extend } from "../../../../js/lib/games/star_duel/sounds.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

describe("Star Duel's sounds", () => {
  it("make the voices its sound effects always made", () => {
    expectSoundsAsRecorded("star_duel", { sounds: SOUNDS, extend }, SOUND_SCRIPT);
  });
});
