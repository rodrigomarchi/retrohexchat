import { afterEach, beforeEach, vi } from "vitest";
import { recordingAudio } from "./recording_audio.js";

/**
 * What the tests of a match's end share, for engines built by hand rather
 * than through the harness: a game's engine class and end schema from its
 * folder, the options of a solo host nobody plays against, and one engine a
 * test, heard by a recording audio and stopped after it.
 */

/** A game folder's engine class and its end schema. */
export async function loadGame(dir) {
  const [{ default: Game }, { GAME_END }] = await Promise.all([
    import(`../../../js/lib/games/${dir}/index.js`),
    import(`../../../js/lib/games/${dir}/protocol.js`),
  ]);
  return { Game, GAME_END };
}

/** A solo host whose opponent never presses anything. */
export const IDLE_SOLO = Object.freeze({
  mode: "solo",
  opponentController: { nextInputs: () => ({}), nextDirection: () => null },
});

/**
 * Every test of the file gets a recording audio, and the engine it keeps is
 * stopped after it, its spies restored: `const keep = engineEachTest()`, then
 * `const engine = keep(new Game(…))`.
 */
export function engineEachTest() {
  let engine = null;
  beforeEach(() => {
    recordingAudio();
  });
  afterEach(() => {
    engine?.stop();
    engine = null;
    vi.restoreAllMocks();
  });
  return (made) => (engine = made);
}
