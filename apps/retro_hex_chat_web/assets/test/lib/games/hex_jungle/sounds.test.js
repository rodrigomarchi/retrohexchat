import { describe, expect, it } from "vitest";
import { MASTER_VOLUME, SOUNDS, extend } from "../../../../js/lib/games/hex_jungle/sounds.js";
import { createGameAudio } from "../../../../js/lib/games/core/synth.js";
import { hear } from "../../../support/games/hear.js";
import { expectSoundsAsRecorded } from "../../../support/games/sound_fixture.js";
import { SOUND_SCRIPT } from "./sound_script.js";

const spec = { sounds: SOUNDS, masterVolume: MASTER_VOLUME, extend };

describe("Hex Jungle's sounds", () => {
  it("make the voices recorded for them", () => {
    expectSoundsAsRecorded("hex_jungle", spec, SOUND_SCRIPT);
  });

  it("hold one log buzz at a time, and let it go", () => {
    const held = hear(() => createGameAudio(spec), [["startLogBuzz"], ["startLogBuzz"]]);
    expect(held.filter((voice) => voice.source.type === "sawtooth")).toHaveLength(1);
  });

  it("time the death's tune to the wait before the next life", () => {
    const last = SOUNDS.death.at(-1);
    expect(last.delay + last.dur).toBeCloseTo(150 / 60, 1);
  });
});
