import { afterEach, describe, expect, it } from "vitest";
import HexJungle from "../../../../js/lib/games/hex_jungle/index.js";
import { PHASE } from "../../../../js/lib/games/hex_jungle/protocol.js";
import { playMatch } from "../../../support/games/harness.js";

const play = (options) =>
  playMatch({ EngineClass: HexJungle, gameId: "hex_jungle", mode: "solo", ...options });
const hold = (key, at = 0) => [{ at, side: "host", key, down: true }];
const phases = (match) => match.record().phases.map((p) => p.phase);

/** A screen with fire at x 124 and firm ground to its left. */
const FIRE_SCREEN = 0b00000110;

/** Put the player beside the fire, with what else the test needs. */
function besideTheFire(match, rest = {}) {
  const { host } = match.engines;
  host.gameState = {
    ...host.gameState,
    screen: FIRE_SCREEN,
    logs: [],
    ...rest,
    player: { ...host.gameState.player, x: 110 },
  };
}

describe("Hex Jungle, played through the engine", () => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  it("dies, waits out the tune, drops back in and plays on", async () => {
    match = await play({ script: hold("ArrowRight", 100) });
    besideTheFire(match);
    match.advance(6000);

    const seen = phases(match);
    const died = seen.indexOf(PHASE.DYING);
    expect(died).toBeGreaterThan(0);
    expect(seen.slice(died)).toEqual(
      expect.arrayContaining([PHASE.DYING, PHASE.RESPAWN, PHASE.PLAYING]),
    );
    expect(seen.lastIndexOf(PHASE.PLAYING)).toBeGreaterThan(seen.indexOf(PHASE.RESPAWN));
    expect(match.engines.host.gameState.lives).toBe(2);
    expect(match.results.host).toEqual([]);
  });

  it("ends on the last life lost, and reports the points once", async () => {
    match = await play({ script: hold("ArrowRight", 100) });
    besideTheFire(match, { lives: 1, score: 4321 });
    match.advance(6000);

    expect(phases(match).at(-1)).toBe(PHASE.FINISHED);
    expect(match.results.host).toEqual([{ score: { p1: 4321, p2: 0 }, winner: 0 }]);
  });

  it("ended early, reports the points the player holds then", async () => {
    match = await play();
    match.advance(500);
    match.engines.host.gameState = { ...match.engines.host.gameState, score: 2500 };

    expect(match.engines.host.quit()).toBe(true);
    expect(match.results.host).toEqual([{ score: { p1: 2500, p2: 0 }, ended_early: true }]);
  });

  it("plays the same expedition twice from the same keys", async () => {
    const script = [
      ...hold("ArrowRight", 0),
      { at: 1500, side: "host", key: " ", down: true },
      { at: 1600, side: "host", key: " ", down: false },
      { at: 4000, side: "host", key: "ArrowDown", down: true },
    ];
    const run = async () => {
      const once = await play({ script });
      once.advance(12_000);
      const state = structuredClone(once.engines.host.gameState);
      once.stop();
      once.restore();
      return state;
    };
    const first = await run();
    expect(await run()).toEqual(first);
    expect(first.tick).toBeGreaterThan(600);
  });
});
