import { readFileSync } from "node:fs";
import { expect } from "vitest";
import { createGameAudio } from "../../../js/lib/games/core/synth.js";
import { hear } from "./hear.js";

/**
 * A game's sounds, now data, make the voices its old audio class made for
 * the same script — recorded in `sounds.fixture.json` before the class went.
 * @param {string} dir - the game's folder under test/lib/games
 * @param {object} spec - what the game hands createGameAudio
 * @param {Array} script - its sound script
 */
export function expectSoundsAsRecorded(dir, spec, script) {
  const recorded = JSON.parse(readFileSync(`test/lib/games/${dir}/sounds.fixture.json`, "utf8"));
  expect(hear(() => createGameAudio(spec), script)).toEqual(recorded);
}
